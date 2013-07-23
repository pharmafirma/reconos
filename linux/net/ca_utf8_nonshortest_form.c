
#ifndef CA_UTF8_NONSHORTEST_FORM
#define CA_UTF8_NONSHORTEST_FORM
#endif

#include "ca_utf8_nonshortest_form.h"



int ca_utf8_nonshortest_form(	void // TODO
                             	)
{

	//	 ____	                                      	_____
	//	/    	hard-coded for debugging. Remove this.	     \

	//                	   some ASCII    Some Valid Multibyte Chars (1)          ../    
	char * buffer_good	= "Bulubulu bla  \xc3\xa4 \xe6\xb8\xaf \xf0\x9f\x92\xa9  ..\x2f  ../  The End.";
	//                	   some ASCII    Some Valid Multibyte Chars (1)          ../    with a nsf
	char * buffer_evil	= "Bulubulu bla  \xc3\xa4 \xe6\xb8\xaf \xf0\x9f\x92\xa9  ..\x2f  ..\xc0\xaf  The End.";
	// (1)            	
	  // a Umlaut (2-byte)
	  // Han Symbol for "port", "bay" (3-byte)
	  // Pile of Poo (4-byte)

	// debug: uncomment one of the following lines.
	//char *	buffer_debug 	= " aAbB ..\xC0\xAF"; // evil 1
	//char *	buffer_debug 	= " aAbB .\xe0\x80\xAF"; // evil 1
	//char *	buffer_debug 	= " aAbB \x80\x80\xAF"; // evil 1
	//char *	buffer_debug 	= " aAbB \xc3\xa4.."; // regular 2-byte char
	//char *	buffer_debug 	= " aAbB \xe6\xb8\xaf."; // regular 3-byte char
	//char *	buffer_debug 	= " aAbB \xf0\x9f\x92\xa9"; // regular 4-byte char
	//char *	buffer_debug 	= " aAbB ...\xf0"; // 1st byte of regular 4-byte char at EOF
	// int  	packet_length	= 10;

	// all possible UTF-8 bit lengths. 
	// Please do not alter the content of these lines, just uncomment what you need.
	//char *	buffer_debug 	= "\x00\x01\x02\x04\x08\x10\x20\x40";
	//int   	packet_length	= 8;
	//char *	buffer_debug 	= "\xc0\x80\xc0\x81\xc0\x82\xc0\x84\xc0\x88\xc0\x90\xc0\xa0\xc1\x80\xc2\x80\xc4\x80\xc8\x80\xd0\x80";
	//int   	packet_length	= 12*2;
	//char *	buffer_debug 	= "\xe0\x80\x80\xe0\x80\x81\xe0\x80\x82\xe0\x80\x84\xe0\x80\x88\xe0\x80\x90\xe0\x80\xa0\xe0\x81\x80\xe0\x82\x80\xe0\x84\x80\xe0\x88\x80\xe0\x90\x80\xe0\xa0\x80\xe1\x80\x80\xe2\x80\x80\xe4\x80\x80\xe8\x80\x80";
	//int   	packet_length	= 17*3;
	//char *	buffer_debug 	= "\xf0\x80\x80\x80\xf0\x80\x80\x81\xf0\x80\x80\x82\xf0\x80\x80\x84\xf0\x80\x80\x88\xf0\x80\x80\x90\xf0\x80\x80\xa0\xf0\x80\x81\x80\xf0\x80\x82\x80\xf0\x80\x84\x80\xf0\x80\x88\x80\xf0\x80\x90\x80\xf0\x80\xa0\x80\xf0\x81\x80\x80\xf0\x82\x80\x80\xf0\x84\x80\x80\xf0\x88\x80\x80\xf0\x90\x80\x80\xf0\xa0\x80\x80\xf1\x80\x80\x80\xf2\x80\x80\x80\xf4\x80\x80\x80";
	//int   	packet_length	= 22*4;

	// copy. play around here.
	char *	buffer_debug 	= ".\xf0\x90\x80\x80\xf0\xa0\x80\x80\xf1\x80\x80\x80\xf2\x80\x80\x80\xf4\x80\x80\x80";
	int   	packet_length	= 22;


	//	\____	end hardcoded debug stuff.	_____/
	//
 


	//	 ____	                                                                   	_____
	//	/    	non-shortest form specific stuff. move to separate file / function.	     \


	// constants for the IPS
	int	GOOD_FORWARD	= 1;
	int	EVIL_DROP   	= 0;
	int	safe_state  	= EVIL_DROP; // adapt as needed or take from procfs
	int	i;

	// default
	int	result	= GOOD_FORWARD; 


	//   	for debugging only	
	//int	j;
	int  	z;
	int  	header_length	= 1;


	//	\____	non-shortest form specific stuff continues below.	_____/
	//	     	                                                 	





	//	 ____	                                                 	_____
	//	/    	continuation of non-shortest form specific stuff.	     \

	printk("The good Buffer is: %s\n", buffer_good);
	printk("The evil Buffer is: %s\n", buffer_evil);
	//printk("The debug Buffer is: %s\n", buffer_debug);


	// search for the non-shortest form

	printk("Packet Size: %d\n", packet_length);
	
	// int i; // already defined
	for (i = header_length; i < packet_length; ++i) // leDebug
	//for (i = header_length; i < packet_length; ++i) // for each byte in the packet
	{
		// search for multi-byte characters which could have been represented using a shorter form.
		// 
		// # bytes	max. #bits	binary representation
		// 1      	 7 bit    	0xxx xxxx
		//        	          	
		// 2      	11 bit    	110x xxxx   10xx xxxx
		//        	          	        ^ 7th x-bit
		// 3      	16 bit    	1110 xxxx   10xx xxxx   10xx xxxx
		//        	          	               ^ 11th x-bit
		// 4      	21 bit    	1111 0xxx   10xx xxxx   10xx xxxx   10xx xxxx
		//        	          	                 ^ 16th x-bit
		//
		// If there are only 0's in the x-bite before the bit marked with ^, the character could have been represented using a shorter representation. 
		// i.e. it is evil  }:-)
		// If not, it is good O:-)
		// 
		// as one can see, only the first 2 bytes are necessary to decide wether the packet is evil or not.

		char	cur	= buffer_debug[i];
		char	next;
		int 	eof	= (i == packet_length-1);
		int 	eof_next;
		if (!eof)
		{
			next    	= buffer_debug[i+1];
			eof_next	= (i == packet_length-2);
		}


		printk("i'th Element of the Buffer: %c ", cur);
		printk("(binary: ");



		for (z = 128; z > 0; z >>= 1)
		{
		    printk((cur & z) ? "1" : "0");
		}			

		// for (j = 7; j >= 0; --j)
		// //for (j = 0; j < 8; ++j)
		// {
		//	if ( ((cur >> j) %2) ==	1 ) {printf(	"1");}
		//	if ( ((cur >> j) %2) ==	0 ) {printf(	"0");}
		// }
		printk("). ");
		printk("EOF is %d. ", eof);


		// Bytes which contain 7-bit ASCII characters "0xxx xxxx" are valid O:-)
		// Latter bytes of a multibyte character "10xx xxxx" can be ignored too, since the first bytes have already been checked.
		if (
				!(cur & (1 << 7))
				||(
					(cur & (1 << 7)) 
					&& !(cur & (1 << 6)) 
				)
		    )
		{
			printk("Harmless. ");
			if (eof)
			{
				printk("\n========== Good Packet O:-) ==========\n");
			}
		} 

		// Look for the first byte of a 2-byte character: "110x xxxx"
		if (
				(cur & (1 << 7))
				&& (cur & (1 << 6))
				&& !(cur & (1 << 5))
			)
		{
			printk("1st byte of a 2-byte char.\n");
			if (
					!(cur & (1 << 4))
					&& !(cur & (1 << 3))
					&& !(cur & (1 << 2))
					&& !(cur & (1 << 1))
				)
			{
				// 7-bit character represented with 2 bytes instead of 1 }:-)
				printk("    7-bit character represented with 2 bytes instead of 1. ");

				printk("\n========== Evil Packet }:-) ==========\n");
				break; 
			} else {
				printk("    a regular 2-byte character. "); 
				if (eof)
				{
					printk("\n========== Good Packet O:-) ==========\n");
				}
			}
		}


		// Look for the first byte of a 3-byte character: "1110 xxxx"
		if (
				(cur & (1 << 7))
				&& (cur & (1 << 6))
				&& (cur & (1 << 5))
				&& !(cur & (1 << 4))
			)
		{
			printk("1st byte of a 3-byte char.\n");
			if (
					!(cur & (1 << 3))
					&& !(cur & (1 << 2))
					&& !(cur & (1 << 1))
					&& !(cur & (1 << 0))
				)
			{
				// character can be up to 12 bits long, need to check the second byte.
				printk("    character can be up to 12 bits long, checking the second byte... \n");

				if (eof)
				{
					if (safe_state == EVIL_DROP) 
					{
						printk("\n========== Evil Packet }:-) ==========\n");
					} else {
						printk("\n========== Good Packet O:-) ==========\n");
						break; 
					}
				} else {
					// examine the 2nd byte.
					if (
						(next & (1 << 7))
						&& !(next & (1 << 6))
						&& !(next & (1 << 5))
					)
					{
						// 11 bit character represented with 3 bytes instead of 2 }:-)
						printk("        11 (or less) bit character represented with 3 bytes instead of 2 (or less). ");
						printk("\n========== Evil Packet }:-) ==========\n");
						break; 
					} else {
						// regular 3-byte character
						printk("        a regular 3-byte character. ");
						if (eof_next)
						{
							printk("\n========== Good Packet O:-) ==========\n");
							break; 
						} // else: do nothing, the next byte will be ignored.
					}
				}

				//printk("\n========== Evil Packet }:-) ==========\n");
				//break; 
			} else {
				printk("    a regular 3-byte character. "); 
				if (eof)
				{
					printk("\n========== Good Packet O:-) ==========\n");
				}
			}
		}



		// Look for the first byte of a 4-byte character: "1110 xxxx"
		if (
				(cur & (1 << 7))
				&& (cur & (1 << 6))
				&& (cur & (1 << 5))
				&& (cur & (1 << 4))
				&& !(cur & (1 << 3))
			)
		{
			printk("1st byte of a 4-byte char.\n");
			if (
					!(cur & (1 << 2))
					&& !(cur & (1 << 1))
					&& !(cur & (1 << 0))
				)
			{
				// character can be up to 18 bits long, need to check the second byte.
				printk("    character can be up to 18 bits long, need to check the second byte. \n");

				if (eof)
				{
					// Safe state.
					if (safe_state == EVIL_DROP) 
					{
						printk("\n========== Evil Packet }:-) ==========\n");
					} else {
						printk("\n========== Good Packet O:-) ==========\n");
					}
				} else {
					// examine the 2nd byte.
					if (
						(next & (1 << 7))
						&& !(next & (1 << 6))
						&& !(next & (1 << 5))
						&& !(next & (1 << 4))
					)
					{
						// 11 bit character represented with 4 bytes instead of 3 }:-)
						printk("        16 bit character represented with 4 bytes instead of 3. ");
						printk("\n========== Evil Packet }:-) ==========\n");
						break; 
					} else {
						// regular 3-byte character
						printk("        a regular 4-byte character. ");
						if (eof_next)
						{
							printk("\n========== Good Packet O:-) ==========\n");
							break; 
						} // else: do nothing, the next byte will be ignored.
					}
				}


				//printk("\n========== Evil Packet }:-) ==========\n");
				//break; 
			} else {
				printk("    a regular 4-byte character. "); 
				if (eof)
				{
					printk("\n========== Good Packet O:-) ==========\n");
				}
			}
		}



		/* code */
		printk("\n");
	} // for each byte in the packet


	return result;


	//	\____	end non-shortest form specific stuff.	_____/
	//	     	                                     	
}