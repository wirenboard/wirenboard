/*
 * Подмена readdir: записи каталога отдаются в том порядке, в каком их отдаёт
 * ext4 с индексом каталогов на старом сборочном ноуте, — по хешу имени
 * (half_md4 с зерном раздела, как в fs/ext4/hash.c), затем по младшему хешу.
 *
 * make 4.1 раскладывает $(wildcard ...) в порядке readdir, а от него зависит
 * порядок объектов при линковке и раскладка прошивки. Зерно — «Directory Hash
 * Seed» из dumpe2fs раздела ноута, передаётся в EXT4_DIR_HASH_SEED. Без него
 * подмена ничего не меняет. EXT4_DIR_BLOCK_SIZE (4096) и EXT4_DIR_CSUM (1, если
 * у раздела metadata_csum) — тоже из dumpe2fs: от них зависит, влезет ли
 * каталог в один блок.
 *
 * Сборка: gcc -O2 -shared -fPIC -o ext4_dir_order.so ext4_dir_order.c -ldl -lpthread
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ROL32(x, s) (((x) << (s)) | ((x) >> (32 - (s))))
#define F(x, y, z) ((z) ^ ((x) & ((y) ^ (z))))
#define G(x, y, z) (((x) & (y)) + (((x) ^ (y)) & (z)))
#define H(x, y, z) ((x) ^ (y) ^ (z))
#define ROUND(f, a, b, c, d, x, s) (a += f(b, c, d) + (x), a = ROL32(a, s))
#define K2 013240474631U
#define K3 015666365641U

static void half_md4_transform(uint32_t buf[4], const uint32_t in[8])
{
    uint32_t a = buf[0], b = buf[1], c = buf[2], d = buf[3];

    ROUND(F, a, b, c, d, in[0], 3);
    ROUND(F, d, a, b, c, in[1], 7);
    ROUND(F, c, d, a, b, in[2], 11);
    ROUND(F, b, c, d, a, in[3], 19);
    ROUND(F, a, b, c, d, in[4], 3);
    ROUND(F, d, a, b, c, in[5], 7);
    ROUND(F, c, d, a, b, in[6], 11);
    ROUND(F, b, c, d, a, in[7], 19);

    ROUND(G, a, b, c, d, in[1] + K2, 3);
    ROUND(G, d, a, b, c, in[3] + K2, 5);
    ROUND(G, c, d, a, b, in[5] + K2, 9);
    ROUND(G, b, c, d, a, in[7] + K2, 13);
    ROUND(G, a, b, c, d, in[0] + K2, 3);
    ROUND(G, d, a, b, c, in[2] + K2, 5);
    ROUND(G, c, d, a, b, in[4] + K2, 9);
    ROUND(G, b, c, d, a, in[6] + K2, 13);

    ROUND(H, a, b, c, d, in[3] + K3, 3);
    ROUND(H, d, a, b, c, in[7] + K3, 9);
    ROUND(H, c, d, a, b, in[2] + K3, 11);
    ROUND(H, b, c, d, a, in[6] + K3, 15);
    ROUND(H, a, b, c, d, in[1] + K3, 3);
    ROUND(H, d, a, b, c, in[5] + K3, 9);
    ROUND(H, c, d, a, b, in[0] + K3, 11);
    ROUND(H, b, c, d, a, in[4] + K3, 15);

    buf[0] += a;
    buf[1] += b;
    buf[2] += c;
    buf[3] += d;
}

/* str2hashbuf_signed: на x86 ext4 создаётся со знаковым хешем */
static void str2hashbuf(const char *msg, int len, uint32_t *buf, int num)
{
    const signed char *scp = (const signed char *)msg;
    uint32_t pad = (uint32_t)len | ((uint32_t)len << 8);
    uint32_t val;
    int i;

    pad |= pad << 16;
    val = pad;
    if (len > num * 4)
        len = num * 4;
    for (i = 0; i < len; i++) {
        val = (uint32_t)(int)scp[i] + (val << 8);
        if ((i % 4) == 3) {
            *buf++ = val;
            val = pad;
            num--;
        }
    }
    if (--num >= 0)
        *buf++ = val;
    while (--num >= 0)
        *buf++ = pad;
}

static int have_seed;
static uint32_t seed[4];
static unsigned block_size = 4096;
static int csum = 1;

static void dirhash(const char *name, uint32_t *major, uint32_t *minor)
{
    uint32_t buf[4] = {0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476};
    uint32_t in[8];
    int len = (int)strlen(name);
    const char *p = name;

    if (seed[0] || seed[1] || seed[2] || seed[3])
        memcpy(buf, seed, sizeof(buf));
    while (len > 0) {
        str2hashbuf(p, len, in, 8);
        half_md4_transform(buf, in);
        len -= 32;
        p += 32;
    }
    *major = buf[1] & ~1U;
    if (*major == (0x7fffffffU << 1))
        *major = (0x7fffffffU - 1) << 1;
    *minor = buf[2];
}

/* «Directory Hash Seed» в виде UUID: 16 байт по порядку, слова — little-endian */
static void load_seed(void)
{
    const char *s = getenv("EXT4_DIR_HASH_SEED");
    unsigned char b[16];
    int n = 0, i;

    if (!s || !*s)
        return;
    for (; *s && n < 16; s++) {
        unsigned v;
        if (*s == '-')
            continue;
        if (sscanf(s, "%2x", &v) != 1)
            return;
        b[n++] = (unsigned char)v;
        s++;
    }
    if (n != 16)
        return;
    for (i = 0; i < 4; i++)
        seed[i] = b[4 * i] | b[4 * i + 1] << 8 | b[4 * i + 2] << 16 | (uint32_t)b[4 * i + 3] << 24;
    have_seed = 1;
    s = getenv("EXT4_DIR_BLOCK_SIZE");
    if (s && *s)
        block_size = (unsigned)atoi(s);
    s = getenv("EXT4_DIR_CSUM");
    if (s && *s)
        csum = atoi(s);
}

static pthread_once_t once = PTHREAD_ONCE_INIT;
static struct dirent *(*real_readdir)(DIR *);
static struct dirent64 *(*real_readdir64)(DIR *);
static int (*real_closedir)(DIR *);

static void init(void)
{
    real_readdir = (struct dirent *(*)(DIR *))dlsym(RTLD_NEXT, "readdir");
    real_readdir64 = (struct dirent64 *(*)(DIR *))dlsym(RTLD_NEXT, "readdir64");
    real_closedir = (int (*)(DIR *))dlsym(RTLD_NEXT, "closedir");
    load_seed();
}

/* Каталог читается целиком при первом вызове и отдаётся отсортированным */
struct entry {
    uint32_t major, minor;
    int dot;
    union {
        struct dirent d;
        struct dirent64 d64;
    } u;
};

struct listing {
    DIR *dir;
    int is64;
    size_t n, pos;
    struct entry *e;
    struct listing *next;
};

static struct listing *listings;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static int cmp_entry(const void *a, const void *b)
{
    const struct entry *x = a, *y = b;

    if (x->dot != y->dot)
        return x->dot > y->dot ? -1 : 1;
    if (x->major != y->major)
        return x->major < y->major ? -1 : 1;
    if (x->minor != y->minor)
        return x->minor < y->minor ? -1 : 1;
    return 0;
}

static struct listing *get_listing(DIR *dir, int is64)
{
    struct listing *l;

    for (l = listings; l; l = l->next)
        if (l->dir == dir)
            return l;
    l = calloc(1, sizeof(*l));
    if (!l)
        return NULL;
    l->dir = dir;
    l->is64 = is64;
    for (;;) {
        void *d = is64 ? (void *)real_readdir64(dir) : (void *)real_readdir(dir);
        struct entry *e;
        if (!d)
            break;
        e = realloc(l->e, (l->n + 1) * sizeof(*l->e));
        if (!e)
            break;
        l->e = e;
        l->e[l->n].dot = 0;
        if (is64)
            l->e[l->n].u.d64 = *(struct dirent64 *)d;
        else
            l->e[l->n].u.d = *(struct dirent *)d;
        dirhash(is64 ? l->e[l->n].u.d64.d_name : l->e[l->n].u.d.d_name,
                &l->e[l->n].major, &l->e[l->n].minor);
        l->n++;
    }
    {
        /* Каталог в один блок ext4 не индексирует и хеширует «.» и «..» как
         * обычные имена; в индексированном они идут первыми */
        size_t i, total = 0;
        for (i = 0; i < l->n; i++)
            total += (8 + strlen(is64 ? l->e[i].u.d64.d_name : l->e[i].u.d.d_name) + 3) & ~3U;
        if (total > block_size - (csum ? 12 : 0))
            for (i = 0; i < l->n; i++) {
                const char *nm = is64 ? l->e[i].u.d64.d_name : l->e[i].u.d.d_name;
                l->e[i].dot = !strcmp(nm, ".") ? 2 : !strcmp(nm, "..") ? 1 : 0;
            }
    }
    qsort(l->e, l->n, sizeof(*l->e), cmp_entry);
    l->next = listings;
    listings = l;
    return l;
}

static void *next_entry(DIR *dir, int is64)
{
    struct listing *l;
    void *r = NULL;

    pthread_mutex_lock(&lock);
    l = get_listing(dir, is64);
    if (l && l->pos < l->n) {
        r = is64 ? (void *)&l->e[l->pos].u.d64 : (void *)&l->e[l->pos].u.d;
        l->pos++;
    }
    pthread_mutex_unlock(&lock);
    return r;
}

struct dirent *readdir(DIR *dir)
{
    pthread_once(&once, init);
    if (!have_seed)
        return real_readdir(dir);
    return next_entry(dir, 0);
}

struct dirent64 *readdir64(DIR *dir)
{
    pthread_once(&once, init);
    if (!have_seed)
        return real_readdir64(dir);
    return next_entry(dir, 1);
}

int closedir(DIR *dir)
{
    struct listing **pl;

    pthread_once(&once, init);
    pthread_mutex_lock(&lock);
    for (pl = &listings; *pl; pl = &(*pl)->next) {
        if ((*pl)->dir == dir) {
            struct listing *l = *pl;
            *pl = l->next;
            free(l->e);
            free(l);
            break;
        }
    }
    pthread_mutex_unlock(&lock);
    return real_closedir(dir);
}
