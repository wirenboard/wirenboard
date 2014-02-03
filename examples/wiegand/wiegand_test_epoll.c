//https://gist.github.com/jadonk/2587524

//green/data0 is gpio 5 (R4 at WB3.3)
//white/data1 is gpio 6 (R3 at WB3.3)

#define GPIO_DATA0 5
#define GPIO_DATA1 6


#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/epoll.h>
#include <sys/types.h>

int init_gpio(int gpio) {
	// export gpio to userspace
	FILE * tmpf = fopen("/sys/class/gpio/export", "w");
	char path[42];
	fprintf(tmpf, "%d\n", gpio);
	fclose(tmpf);

	// set output direction
	sprintf(path, "/sys/class/gpio/gpio%d/direction", gpio);
	tmpf = fopen(path, "w");
	fprintf(tmpf, "%s\n", "in");
	fclose(tmpf);

	sprintf(path, "/sys/class/gpio/gpio%d/edge", gpio);
	tmpf = fopen(path, "w");
	fprintf(tmpf, "%s\n", "falling");
	fclose(tmpf);

	sprintf(path, "/sys/class/gpio/gpio%d/value", gpio);
	int fd = open(path, O_RDWR | O_NONBLOCK);
	fprintf(stderr, "open of gpio %d returned %d: %s\n", gpio, fd, strerror(errno));
	return fd;

}

int main(int argc, char** argv) {
	int n;
	int epfd = epoll_create(1);

	int fd_d0 = init_gpio(GPIO_DATA0);
	int fd_d1 = init_gpio(GPIO_DATA1);


	if( !(fd_d0 > 0) || !(fd_d1 > 0)) {
		fprintf(stderr, "error opening gpio sysfs entries\n");
		return 1;
	}

    char buf = 0;

    struct epoll_event ev_d0, ev_d1;
    struct epoll_event events[10];
    ev_d0.events = EPOLLET;
    ev_d1.events = EPOLLET;

    ev_d0.data.fd = fd_d0;
    ev_d1.data.fd = fd_d1;

    n = epoll_ctl(epfd, EPOLL_CTL_ADD, fd_d0, &ev_d0);
    if (n != 0) {
		printf("epoll_ctl returned %d: %s\n", n, strerror(errno));
		return 1;
	}

    n = epoll_ctl(epfd, EPOLL_CTL_ADD, fd_d1, &ev_d1);
    if (n != 0) {
		printf("epoll_ctl returned %d: %s\n", n, strerror(errno));
		return 1;
	}


	size_t i	;

	unsigned int value = 0;
	unsigned bit_counter = 0;

    while(1) {
		n = epoll_wait(epfd, events, 10, 15);

		for ( i = 0;  i < n; ++i) {
			value <<= 1;
			if (events[i].data.fd == ev_d1.data.fd) {
				value |= 0x01;
			}

			bit_counter += 1;
		}

		if (bit_counter && (n == 0)) {
			printf("got value %d = 0x%x (%d bits)\n", value, value, bit_counter);
			value = 0;
			bit_counter = 0;
		}
    }


  return(0);
}
