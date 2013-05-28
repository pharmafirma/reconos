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
    needle = "GET .+ HTTP/1.0";	// for debugging only.
    //needle = "GET .+\r\n";   	// TODO: use this as soon as receiving works.
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


static int get_argument(char needle, char ** result, int argc, char ** argv){
    // This function gets an argument from the command line.
    // e.g. for the command: ./myprogram -a foo
    // foo yould be the result for needle 'a'.
    // 
    // arguments:   	needle: Character for the argument (-a)
    //              	result: String with the resulting arguent (foo)
    //              	argc and argv: the list and count of arguments, as you would probably expect :-).
    // return value:	Status code
    //     0:       	No error, exactly one argument found.
    //    -1:       	No argument found.            
    //     1:       	More than one argument found


    // known bugs:	Note That the function is not intended to interpret flag-like arguments, such as -abc.
    //            	If you enter something like ./myprogram -a -b -c, it will interpret
    //            		both: -b as the result of -a 
    //            		and -c as the result of -b.


	int   	i = 0;
	//char	c;
	int   	ret = -1; // the default for this value must be "nothing found", as the for loop will not execute if there are no arguements at all.

	for (i = 1; i < argc; ++i){
		// check if we have an value in the form "one dash, one character" (-a)
		if (argv[i][0] == '-' && argv[i][2] == '\0'){
			// if yes, check if it is the argument we are looking for
			if (argv[i][1] == needle){
				// check if a next value exists
				if(i+1 < argc){
					*result = argv[i+1];
					ret++;
				}
			} 
		}
		if (ret > 1){ // if more than two arguments have been found so far...
			ret = 1;
		}

	}
    return ret;
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
	char *  	tmp; // just a pointer, no space reserved!



	// read www root directory from command line argument (-d).
	// if no argument is given, print a warning and use the default directory.

	ret = get_argument('d', &tmp, argc, argv);
    if (ret == 0){
        printf("Yay, we found a command line argument: ");
        printf("-%c is: %s\n", 'd', tmp);
        strncpy(www_rootdir, tmp, BUFFSIZE);
        // process argument here
    } else {
		strcpy(www_rootdir, "/var/www/");
		printf("The option -d was not specified. Using default www root directory: %s\n", www_rootdir);
	}




	//		########  ######## ########  ##     ##  ######   
	//		##     ## ##       ##     ## ##     ## ##    ##  
	//		##     ## ##       ##     ## ##     ## ##        
	//		##     ## ######   ########  ##     ## ##   #### 
	//		##     ## ##       ##     ## ##     ## ##    ##  
	//		##     ## ##       ##     ## ##     ## ##    ##  
	//		########  ######## ########   #######   ######  
	//		                        Le     Debug     Code   
	                                       


	char *	pre_recorded_input_message[] = {            	// -t	UTF-8	directory
	      	"GET index.html HTTP/1.1",                  	// 0 	no   	/var/www
	      	"GET ../index.html HTTP/1.1",               	// 1 	no   	/var
	      	"GET ../../index.html HTTP/1.1",            	// 2 	no   	/
	      	"GET \x2e\x2e\x2index.html HTTP/1.1",       	// 3 	no   	/var
	      	"GET \x2e./index.html HTTP/1.1",            	// 4 	no   	/var
	      	"GET \xc0\xae./index.html HTTP/1.1",        	// 5 	yes  	/var
	      	"GET \xe0\x80\xae./index.html HTTP/1.1",    	// 6 	yes  	/var
	      	"GET \xf0\x80\x80\xae./index.html HTTP/1.1",	// 7 	yes  	/var

		// Legend
		//	-t:       	test number (can be chosen via command line argument -t)
		//	UTF-8:    	yes means the webserver should let it pass unnoticed.
		//	directory:	refers to the default directory /var/www
	};

	// which test to perform?
	ret = get_argument('t', &tmp, argc, argv);
    if (ret == 0){
        printf("Yay, we found a command line argument: ");
        printf("-%c is: %s \n", 't', tmp);
        // process argument here
    } else { 
		strcpy(tmp, "0");
	}

	printf("instead of receiving something...\n");
	//char buff_receiver[BUFFSIZE] = "GET / HTTP/1.0"; // hard-coded for now.

	//strncpy(buff_receiver, argv[1], sizeof(buff_receiver));
	//printf("...we use the value from command line for now: %s\n", buff_receiver);

	strncpy(buff_receiver, pre_recorded_input_message[atoi(tmp)], sizeof(buff_receiver));
	printf("...we use this pre-recorded input message for now: %s\n", buff_receiver);
	printf("So that science can still be done :-).\n");

	// terminate string, just in case it isn't yet
	buff_receiver[FILENAME_SIZE] = '\0';
	//*buff_receiver = (char *) argv[1];
	//printf("command line argument: %s\n", argv[1]);

	// fin du Debug Code





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


    if (http_status != HTTP_OK)  { 
	  printf("Something went wrong with this request.\n");
	  printf("Copying error message to sender buffer... \n");
	  sprintf (buff_sender, "HTTP error %d.", http_status);
	  
	  // bla bla bla
	}
    else { // i.e. http_status == HTTP_OK
		printf("Everything seems OK so far. \n");
		printf("Will now extract file name from request and try to read file.\n");

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
	 

	 
	 
	} // end if (http_status == HTTP_OK)
	   

	 
	 
	    printf("Contents of the sender buffer (before creating socket): \n");
	    printbuff(buff_sender, BUFFSIZE);
	 





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
