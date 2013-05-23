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

#define BUFFSIZE     	63
#define FILENAME_SIZE	63

// http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
#define HTTP_OK            	200 
#define HTTP_BAD_REQUEST   	400
#define HTTP_FORBIDDEN     	403 
#define HTTP_NOT_FOUND     	404
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
	// print in hex...
	for (i = 0; i < len; i++){
		fprintf(stderr, "%02x ", buff[i]);
		if ((i + 1) % 4 == 0){
			fprintf(stderr, "   ");
		}
		if ((i + 1) % 16 == 0){
			fprintf(stderr, " -\n");
		}
	}
	fprintf(stderr, "\n");

	// ... and in ASCII
	for (i = 0; i < len; i++){
		if (buff[i] > 0x19 && buff[i] < 0x7f) {
			fprintf(stderr, "%c", buff[i]);
		} else {
			fprintf(stderr, ".");
		}
		if ((i + 1) % 16 == 0) {
			fprintf(stderr, " -\n");
		}
	}
	fprintf(stderr, "\n");
}


// static void preparebuff(char buff[BUFFSIZE], int run)
// {
//	int i = BUFFSIZE, j = run % BUFFSIZE, l;
//	for (l = 0; i-- > 0; ++l) {
//		buff[l] = (uint8_t) j;
//		j = (j + 1) % BUFFSIZE;
//	}
// }

static int compile_regex (regex_t * regex, const char * needle)
{
    int ret = regcomp(regex, needle, REG_EXTENDED|REG_NEWLINE);
    if (ret != 0) {
	    //char err[MAX_ERROR_MSG];
	    //regerror (ret, regex, err, MAX_ERROR_MSG);
        printf("Error while compiling regex '%s'.\n", needle);
        printf("That probably means something is wrong with your sauce code.\n"); 
			// or, more probably, something's wrong with your spaghetti code.
        perror("Error compiling regex. This should not happen. Aborting program!\n");
        exit(1);
    }
    return 0;
}

int input_sanitizing(char * input){
    // this function calls all other functions needed to sanitize input.
    // returns 0 on success, 1 on error. 
    //int err = 0;
    regex_t regex;
    const char * needle;
    int ret;

    // TODO do input sanitizing here, e.g.
    // check for ../
    needle = "\\.\\./";
    compile_regex(&regex, needle);

    printf ("Trying to find '%s' in '%s': ", needle, input);
    ret = regexec(&regex, input, 0, NULL, 0);
    if(!ret){
        printf("Match, we found a possible directory traversal attack. \n");
        return 1;
    } else if (ret == REG_NOMATCH){
        printf("No match, everything OK. \n");
    } 


    //	Note that, in general, one should also check the input for non-ASCII	//
    //	characters and other nasty things here. This was deliberately left  	//
    //	out to make the program vulnerable for UTF-8 attacks.               	//

    //return err; 
    return 0; 
}


int check_get_request(char * haystack){
    // this function checks if the argument is a simple GET request, as defined in HTTP/1.0
    // returns 0 on success, 1 on error. 

    regex_t regex;
    const char * needle;
    int ret; 
    //const char * haystack;
    //needle = "GET .+ HTTP/1.0";
    needle = "GET .+\r\n";
    compile_regex(&regex, needle);

    printf ("Trying to find '%s' in '%s': ", needle, haystack);
    ret = regexec(&regex, haystack, 0, NULL, 0);
    if(!ret){
        printf("Match. \n");
        return 0;
    } else if (ret == REG_NOMATCH){
        printf("No match. \n");
        return 1;
    } else {
        //regerror(ret, &regex, msgbuf, sizeof(msgbuf));
        perror("Regex match error. \n");
        perror("This should not happen, aborting program! \n");
        exit(1);
    }

    regfree (&regex);

    return 0;
}



int main(int argc, char ** argv) {
	int     	sock;
	int     	ret;
	//int   	run = 0;
	char    	buff_sender[BUFFSIZE];
	char    	buff_receiver[BUFFSIZE];
	//struct	sockaddr_nl src_addr;
	char    	filename[FILENAME_SIZE]; 
	char    	www_rootdir[FILENAME_SIZE]; 
	char    	path[2*FILENAME_SIZE];
	//char  	buff_ifile[BUFFSIZE]
	struct  	sockaddr_nl;
	char    	name[FBNAMSIZ];
	int     	iterations = 10;
	int     	i = 0;
	struct  	timeval start_time, end_time;
	//char  	filename[FILENAME_SIZE]; 
	int     	http_status = HTTP_OK;



	// TODO: read www root directory from command line argument (-d).
	// if no argument is given, print a warning and use the default directory.
	strcpy(www_rootdir, "/var/www/");
	printf("Using www root directory: %s\n", www_rootdir);


	printf("instead of receiving something...\n");
	//char buff_receiver[BUFFSIZE] = "GET / HTTP/1.0"; // hard-coded for now.
	strncpy(buff_receiver, argv[1], sizeof(buff_receiver));
	// terminate string, just in case it isn't yet
	buff_receiver[FILENAME_SIZE] = '\0';
	//*buff_receiver = (char *) argv[1];
	//printf("command line argument: %s\n", argv[1]);
	printf("...we use the value from command line for now: %s\n", buff_receiver);


	ret = input_sanitizing(buff_receiver);
    if (ret == 0) {
        printf("Input sanitizing successful.\n");
    } else {
        printf("Input sanitizing found something evil. Request will not be processed!\n");
        http_status = HTTP_INTERNAL_ERROR; 
        // maybe bad request would be more suitable, but it does not really matter...
    }


    // TODO weitere Tests, was es mit falschen Inputs macht.
    // GOT... statt GET...

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


    if (http_status == HTTP_OK) {
		printf("Everything seems OK so far. Extracting file name from request.\n");

		// A simple Request, as defined in RFC 1945, looks like:
		//	"GET" SP Request-URI CR LF
		// where
		//	SP	= Space ' '
		//	CR	= ASCII carriage return '\r'
		//	LF	= linefeed '\n'

		// As input sanitizing is already done, we can just leave out the "GET" and SP (i.e. skip the first 4 characters)...
        strncpy(filename, buff_receiver+4, sizeof(buff_receiver) - 4*sizeof(char));
		// ...then search for the end of the request, which will be, at the same time, the end of the file name.
		for (i = 0; i < FILENAME_SIZE; i++){
			if (filename[i] == '\r') {
			    filename[i] = '\0';
			}
		}
        printf("File name found: %s \n", filename);

	    // some more debug output
	    printf("-------------- SOME DEBUG OUTPUT -------------\n");
	    printf("input sanitizing done and file name extracted. \n");
	    printf("Name of file to be read: %s \n",filename);
	    printf("HTTP status code (%d = OK): %d \n", HTTP_OK, http_status);
	    printf("Contents of the sender buffer (before reading file): \n");
		printbuff(buff_sender, sizeof(buff_sender));
	    printf("----------------------------------------------\n");



	    // path = www_rootdir + "/" + filename
	    strncpy(path, www_rootdir, FILENAME_SIZE);
	    strcat(path, "/");
	    strncat(path, filename, FILENAME_SIZE);

	    // FIXME: Append index.htm(l) if necessary.

	    // read the file from disk.
	    // and send it to the socket. 
	    //int i;
	    printf("Trying to open file: %s \n", path);
	    FILE * fp = fopen(path, "r");
	 
	    if (fp == NULL) {
	        printf("Failed to open file: %s \n", path);
	        http_status = HTTP_NOT_FOUND; 
	        // FIXME:	implement different error messages according to what exactly happened:
	        //       	- File not found -> HTTP_NOT_FOUND
	        //       	- Permission denied -> HTTP_FORBIDDEN
	        //       	- other (internal) error -> HTTP_INTERNAL_ERROR
	    } else {
			printf("successfully opened file: %s \n", path);

			printf("Copying file contents to sender buffer... \n");
			for (i = 0; i < BUFFSIZE; i++) {
				ret = getc(fp);
				buff_sender[i] = ret;
				if (ret == EOF) {
					fputs("File is shorter than the sender buffer.\n", stderr);
					buff_sender[i] = '\0'; 
					continue; 
				} 
			}
			buff_sender[i] = ret; 
			// TODO: implement what to do if the file is longer than the buffer.
			printf("File is longer than the sender buffer. Only the first %d bytes were copied.\n", i);
			buff_sender[i] = '\0'; 
	    }

		
	    if(fp) {
			printf("Closing file. \n");
			fclose(fp);
		}
	 

	    printf("Contents of the sender buffer (after reading file): \n");
	    printbuff(buff_sender, BUFFSIZE);
	 
	 
	} // end if (http_status == HTTP_OK)
	else { 
	  
	  
	  // bla bla bla
	}
	   

	 
	 
	 





	    // create socket, this part was copied from the echo program.

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
		//preparebuff(buff_sender, run++);
		
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
		}


	// retry_receiving:
	//	// int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
	//	bind(sock, (struct sockaddr *) &src_addr, sizeof(src_addr));
	//	// int listen(int sockfd, int backlog);

	//	listen(sock, 5);
	//	// ssize_t recv(int sockfd, void *buf, size_t len, int flags);
	//	ret = recv(sock, buff_receiver, sizeof(buff_receiver), 0);
	//	//ret = sendto(sock, buff_sender, sizeof(buff_sender), 0, NULL, 0);
	//	if (ret == -1){
	//		perror("listen");
	//		fprintf(stderr, "iteration: %d\n", i);
	//		sleep(5);
	//		gettimeofday(&start_time, NULL); //first time we fail anyway since the protocol stack is not yet built...
	//		goto retry_receiving;
	//	}
	
	printbuff(buff_receiver, sizeof(buff_receiver));



	gettimeofday(&end_time, NULL); //first time we fail anyway since the protocol stack is not yet built...
	int delta = (end_time.tv_sec - start_time.tv_sec)*1000000 + (end_time.tv_usec - start_time.tv_usec);
	printf("\ndone: start_time.tv_sec %d, tv_usec %d, end_time.tv_sec %d, tv_usec %d, delta in usec %d\n", (int)start_time.tv_sec, (int)start_time.tv_usec, (int)end_time.tv_sec, (int)end_time.tv_usec, (int)delta);
	fprintf(stderr, "\n done: start_time.tv_sec %d, tv_usec %d, end_time.tv_sec %d, tv_usec %d, delta in usec %d\n", (int)start_time.tv_sec, (int)start_time.tv_usec, (int)end_time.tv_sec, (int)end_time.tv_usec, (int)delta);
	close(sock);
	return 0;
}
