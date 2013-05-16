CFLAGS	=	-O2 -g -Wall -I../../../../linux/net/
CC	=	microblaze-unknown-linux-gnu-gcc
AR	=	microblaze-unknown-linux-gnu-ar
CFCARD	=	/media/CF2_

all: echo webserver echo_send_and_receive

echo:

webserver:

echo_send_and_receive:

install: all
	find . -executable -exec cp {} $(CFCARD) \;

clean:
	rm -f *.o echo webserver echo_send_and_receive
