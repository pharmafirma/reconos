CFLAGS	=	-O2 -g -Wall -I../../../../linux/net/
CC	=	microblaze-unknown-linux-gnu-gcc
AR	=	microblaze-unknown-linux-gnu-ar
CFCARD	=	/media/CF2

all: echo webserver echo_send_and_receive

echo:

webserver:
	$(CC) $(CFLAGS) webserver.c -o webserver -DMY_COMPILE_TIME=$(shell date +%H%M)

echo_send_and_receive:


# compile everything and copy the executables to the CF card.
install: all
	find . -executable -exec cp {} $(CFCARD) \;; ls -l $(CFCARD)

clean:
	rm -f *.o echo webserver echo_send_and_receive





































































# some undocumented features
coffee: all

cake:
	@echo "The cake is a lie!"
