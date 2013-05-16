#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <linux/netlink.h>
#include <linux/types.h>
#include <linux/if.h>

#include "xt_vlink.h"
#include "xt_fblock.h"

#define BUFFSIZE	63

static inline void die(void)
{
	exit(EXIT_FAILURE);
}

static inline void panic(char *msg, ...)
{
	va_list vl;

	va_start(vl, msg);
	vfprintf(stderr, msg, vl);
	va_end(vl);

	fflush(stderr);
	die();
}


static void printbuff(char buff[BUFFSIZE], int len)
{
	int i;
	for (i = 0; i < len; i++){
		fprintf(stderr, "%02x ", buff[i]);
		if ((i + 1) % 8 == 0){
			fprintf(stderr, "   ");
		}
		if ((i + 1) % 16 == 0){
			fprintf(stderr, "\n");
		}
	}
}


static void preparebuff(char buff[BUFFSIZE], int run)
{
	int i = BUFFSIZE, j = run % BUFFSIZE, l;
	for (l = 0; i-- > 0; ++l) {
		buff[l] = (uint8_t) j;
		j = (j + 1) % BUFFSIZE;
	}
}

int main(void)
{
	int sock, ret, run = 0;
	char buff_sender[BUFFSIZE];
	char buff_receiver[BUFFSIZE];
	char name[FBNAMSIZ];
	int iterations = 10;
	int i = 0;
	struct timeval start_time, end_time;

	// int socket(int domain, int type, int protocol);
	// domain 27 is: ?
	// protocol generally left 0.
	sock = socket(27, SOCK_RAW, 0);
	if (sock < 0)
		panic("Cannot create socket!\n");

	// int ioctl(int d, int request, ...);
	// request: device-dependent request code.
	ret = ioctl(sock, 35296, name);
	if (ret < 0)
		panic("Cannot do ioctl!\n");

	fprintf(stderr, "our instance: %s\n", name);
	printf("our instance: %s\n", name);
	printf("size: %lu\n", sizeof(buff_sender));	
	preparebuff(buff_sender, run++);
	
	for (i = 0; i < iterations; i++) {

		printbuff(buff_sender, sizeof(buff_sender));
	retry_sending:
		// ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen);
		ret = sendto(sock, buff_sender, sizeof(buff_sender), 0, NULL, 0);
		if (ret == -1){
			perror("sendto");
			fprintf(stderr, "iteration: %d\n", i);
			sleep(5);
			gettimeofday(&start_time, NULL); //first time we fail anyway since the protocol stack is not yet built...
			goto retry_sending;
		}

	retry_receiving:
		// int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
		bind(sock, buff_receiver, sizeof(buff_receiver));
		// int listen(int sockfd, int backlog);

	    // dieses TODO sollte jetzt rot werden. Blöder Editor... 
		listen(sock, 5);
		// ssize_t recv(int sockfd, void *buf, size_t len, int flags);
		ret = recv(sock, buff_receiver, sizeof(buff_receiver), 0);
		//ret = sendto(sock, buff_sender, sizeof(buff_sender), 0, NULL, 0);
		if (ret == -1){
			perror("listen");
			fprintf(stderr, "iteration: %d\n", i);
			sleep(5);
			gettimeofday(&start_time, NULL); //first time we fail anyway since the protocol stack is not yet built...
			goto retry_receiving;
		}

		printbuff(buff_receiver, sizeof(buff_receiver));
	}

	gettimeofday(&end_time, NULL); //first time we fail anyway since the protocol stack is not yet built...
	int delta = (end_time.tv_sec - start_time.tv_sec)*1000000 + (end_time.tv_usec - start_time.tv_usec);
	printf("\ndone: start_time.tv_sec %d, tv_usec %d, end_time.tv_sec %d, tv_usec %d, delta in usec %d\n", (int)start_time.tv_sec, (int)start_time.tv_usec, (int)end_time.tv_sec, (int)end_time.tv_usec, (int)delta);
	fprintf(stderr, "\n done: start_time.tv_sec %d, tv_usec %d, end_time.tv_sec %d, tv_usec %d, delta in usec %d\n", (int)start_time.tv_sec, (int)start_time.tv_usec, (int)end_time.tv_sec, (int)end_time.tv_usec, (int)delta);
	close(sock);
	return 0;
}
