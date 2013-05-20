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
#include <regex.h>

#include "xt_vlink.h"
#include "xt_fblock.h"

#define BUFFSIZE	63

// http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
#define HTTP_OK	200 
#define HTTP_BAD_REQUEST	400 
#define HTTP_NOT_FOUND	404
#define HTTP_INTERNAL_ERROR	500

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

static int compile_regex (regex_t * regex, const char * needle)
{
    int ret = regcomp(regex, needle, REG_EXTENDED|REG_NEWLINE);
    if (ret != 0) {
	    //char err[MAX_ERROR_MSG];
	    //regerror (ret, regex, err, MAX_ERROR_MSG);
        printf("Error while compiling regex '%s'.\n", needle);
        printf("That probably means something is wrong with your sauce code.\n"); 
            // or, more probably, something's wrong with your spaghetti code.
        printf("This should not happen, aborting program!\n");
        exit(1);
    }
    return 0;
}

int input_sanitizing(char * input){
    // this function calls all other functions needed to sanitize input.
    // returns 0 on success, 1 on error. 
    int err = 0;

    // TODO do input sanitizing here, e.g.
    // check for ../
    // in general, one should also check the input for non-ASCII characters and other nasty things here. Note that this was deliberately left out to make the program vulnerable for UTF-8 attacks.

    return err; 
}


int check_get_request(char * haystack){
    // this function checks if the argument is a simple GET request, as defined in HTTP/1.0
    // returns 0 on success, 1 on error. 

    regex_t regex;
    const char * needle;
    int ret; 
    //const char * haystack;
    needle = "GET .+ HTTP/1.0";
    compile_regex(&regex, needle);

    printf ("Trying to find '%s' in '%s': ", needle, haystack);
    ret = regexec(&regex, haystack, 0, NULL, 0);
    if( !ret ){
        printf("Match.\n");
        return 0;
    } else if( ret == REG_NOMATCH ){
        printf("No match.\n");
        return 1;
    } else{
        //regerror(ret, &regex, msgbuf, sizeof(msgbuf));
        printf("Regex match error.\n");
        printf("This should not happen, aborting program!\n");
        exit(1);
    }

    regfree (& regex);

    return 0;
}



int main(int argc, char ** argv)
{
	int sock, ret, run = 0;
	char buff_sender[BUFFSIZE];
	char buff_receiver[BUFFSIZE];
	//struct sockaddr_nl src_addr;
	char filename[BUFFSIZE]; 
	struct sockaddr_nl;
	char name[FBNAMSIZ];
	int iterations = 10;
	int i = 0;
	struct timeval start_time, end_time;
	//char filename[BUFFSIZE]; 
	int http_status = HTTP_OK;


	// TODO: read www-directory from command line argument (-d).
	// if no argument is given, print a warning and use working directory.


	printf("instead of receiving something...\n");
	//char buff_receiver[BUFFSIZE] = "GET / HTTP/1.0"; // hard-coded for now.
	strncpy(buff_receiver, argv[1], sizeof(buff_receiver));
	// terminate string, just in case it isn't yet
	buff_receiver[BUFFSIZE] = '\0';
	//*buff_receiver = (char *) argv[1];
	printf("command line argument: %s\n", argv[1]);
	printf("...we use the value from command line for now: %s\n", buff_receiver);


	ret = input_sanitizing(buff_receiver);
    if (ret == 0)
    {
        printf("Input sanitizing successful.\n");
        // TODO continue here: 
        strncpy(filename, &buff_receiver[3], sizeof(buff_receiver)-4*sizeof(char));
        //filename = &buff_receiver + 4*sizeof(char); // sizeof("GET ") = 4.
        for (i = 0; i < BUFFSIZE; ++i)
        {
        	if (filename[i] == ' ')
        	{
        		filename[i] = '\0';
        	}
        }
        printf("File name found: %s \n", filename);
    } else {
        printf("Input sanitizing found something evil. Request will not be processed!\n");
        http_status = HTTP_INTERNAL_ERROR; 
        // maybe bad request would be more suitable, but it does not really matter...
    }



    ret = check_get_request(buff_receiver);
    //ret = check_get_request("asdf");
    if (ret == 0)
    {
        printf("Yay, it's a GET request.\n");
        // process request here
    } else {
        printf("No GET request found.\n");
        http_status = HTTP_BAD_REQUEST;
    }


    // some more debug output
    printf("input sanitizing done. \n");
    printf("File to be read: %s \n", filename);
    printf("HTTP status code: %d \n", http_status);


    // TODO: read the file from disk.
    // and send it to the socket. 


    // create socket, this part is copied from the echo program.

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

	// retry_receiving:
	// 	// int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
	// 	bind(sock, (struct sockaddr *) &src_addr, sizeof(src_addr));
	// 	// int listen(int sockfd, int backlog);

	//     // dieses TODO sollte jetzt rot werden. Blöder Editor... 
	// 	listen(sock, 5);
	// 	// ssize_t recv(int sockfd, void *buf, size_t len, int flags);
	// 	ret = recv(sock, buff_receiver, sizeof(buff_receiver), 0);
	// 	//ret = sendto(sock, buff_sender, sizeof(buff_sender), 0, NULL, 0);
	// 	if (ret == -1){
	// 		perror("listen");
	// 		fprintf(stderr, "iteration: %d\n", i);
	// 		sleep(5);
	// 		gettimeofday(&start_time, NULL); //first time we fail anyway since the protocol stack is not yet built...
	// 		goto retry_receiving;
	// 	}

		printbuff(buff_receiver, sizeof(buff_receiver));
	}

	gettimeofday(&end_time, NULL); //first time we fail anyway since the protocol stack is not yet built...
	int delta = (end_time.tv_sec - start_time.tv_sec)*1000000 + (end_time.tv_usec - start_time.tv_usec);
	printf("\ndone: start_time.tv_sec %d, tv_usec %d, end_time.tv_sec %d, tv_usec %d, delta in usec %d\n", (int)start_time.tv_sec, (int)start_time.tv_usec, (int)end_time.tv_sec, (int)end_time.tv_usec, (int)delta);
	fprintf(stderr, "\n done: start_time.tv_sec %d, tv_usec %d, end_time.tv_sec %d, tv_usec %d, delta in usec %d\n", (int)start_time.tv_sec, (int)start_time.tv_usec, (int)end_time.tv_sec, (int)end_time.tv_usec, (int)delta);
	close(sock);
	return 0;
}
