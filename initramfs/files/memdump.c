#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

unsigned long parse_int (char *str);

int main (int argc, char *argv[]) {
	unsigned long addr, length;

	int devmem;
	void *mapping;

	long page_size;
	off_t map_base, extra_bytes;

	char *buf;
	ssize_t ret;

	if (argc != 3) {
		fprintf(stderr, "Usage: %s ADDR LENGTH\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	addr = parse_int(argv[1]);
	length = parse_int(argv[2]);

	devmem = open("/dev/mem", O_RDONLY);
	if (devmem == -1) {
		perror("Could not open /dev/mem");
		goto open_fail;
	}

	page_size = sysconf(_SC_PAGE_SIZE);
	map_base = addr & ~(page_size - 1);
	extra_bytes = addr - map_base;

	mapping = mmap(NULL, length + extra_bytes, PROT_READ, MAP_SHARED,
	               devmem, map_base);
	if (mapping == MAP_FAILED) {
		perror("Could not map memory");
		goto map_fail;
	}

	buf = (char *) malloc(length);
	if (buf == NULL) {
		fprintf(stderr, "Failed to allocate memory\n");
		goto alloc_fail;
	}

	/*
	 * Using a separate buffer for write stops the kernel from
	 * complaining quite as much as if we passed the mmap()ed
	 * buffer directly to write().
	 */
	memcpy(buf, (char *)mapping + extra_bytes, length);

	ret = write(STDOUT_FILENO, buf, length);
	if (ret == -1) {
		perror("Could not write data");
	} else if (ret != (ssize_t)length) {
		fprintf(stderr, "Only wrote %d bytes\n", ret);
	}

	free(buf);

alloc_fail:
	munmap(mapping, length + extra_bytes);

map_fail:
	close(devmem);

open_fail:
	return EXIT_SUCCESS;
}

unsigned long parse_int (char *str) {
	long long result;
	char *endptr;

	result = strtoll(str, &endptr, 0);
	if (*str == '\0' || *endptr != '\0') {
		fprintf(stderr, "\"%s\" is not a valid number\n", str);
		exit(EXIT_FAILURE);
	}

	return (unsigned long)result;
}
