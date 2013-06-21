library ieee;
-- library fifo32_v1_00_a;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
 -- use fifo32_v1_00_a.all;

--library proc_common_v3_00_a;
--use proc_common_v3_00_a.proc_common_pkg.all;

--library reconos_v3_00_a;
--use reconos_v3_00_a.reconos_pkg.all;

--library ana_v1_00_a;
--use ana_v1_00_a.anaPkg.all;

--constant RESET : std_logic := '1';













entity ips is
--	generic (
--		destination	: std_logic_vector(5 downto 0);
--		sender     		: std_logic
--	);
  	port (
  		debug_fifo_read   	:	in 	std_logic;
  		debug_fifo_write  	:	in 	std_logic;
  		debug_severe_error	:	out	std_logic; 
  		--debug_result    	:	in 	result_type; 
  		rst               	:	in 	std_logic;
  		clk               	:	in 	std_logic;
  		rx_ll_sof         	:	in 	std_logic;
  		rx_ll_eof         	:	in 	std_logic;
  		rx_ll_data        	:	in 	std_logic_vector(7 downto 0);
  		rx_ll_src_rdy     	:	in 	std_logic;
  		rx_ll_dst_rdy     	:	out	std_logic;	
  		tx_ll_sof         	:	out	std_logic;
  		tx_ll_eof         	:	out	std_logic;
  		tx_ll_data        	:	out	std_logic_vector(7 downto 0);
  		tx_ll_src_rdy     	:	out	std_logic;
  		tx_ll_dst_rdy     	:	in 	std_logic
  	);

end ips;

--------------------------------------------------------------

architecture implementation of ips is
	-- some constants
	constant	RESET       	:	std_logic	:= '1';
	constant	PACKET_WIDTH	:	integer  	:= 10;	-- width of data + control bits (sof, eof, etc.)
	constant	RESULT_WIDTH	:	integer  	:= 2; 	-- width of the result (good, evil, unknown)


  	--			 ######  ####  ######   ##    ##    ###    ## 
  	--			##    ##  ##  ##    ##  ###   ##   ## ##   ##
  	--			##        ##  ##        ####  ##  ##   ##  ## 
  	--			 ######   ##  ##   #### ## ## ## ##     ## ## 
  	--			      ##  ##  ##    ##  ##  #### ######### ## 
  	--			##    ##  ##  ##    ##  ##   ### ##     ## ## 
  	--			 ######  ####  ######   ##    ## ##     ## ######## 
  	-- signal declarations
--	signal	test                  	:	std_logic	:= '0'; 
  	signal	packet_fifo_full      	:	std_logic;
  	signal	packet_fifo_empty     	:	std_logic;
  	signal	packet_fifo_read      	:	std_logic;
  	signal	packet_fifo_write     	:	std_logic;
  	signal	packet_fifo_in_packet 	:	std_logic_vector(PACKET_WIDTH-1 downto 0); 
  	signal	packet_fifo_out_packet	:	std_logic_vector(PACKET_WIDTH-1 downto 0); 
  	signal	out_packet_eof        	:	std_logic; 
  	signal	result_fifo_full      	:	std_logic;
  	signal	result_fifo_empty     	:	std_logic;
  	signal	result_fifo_read      	:	std_logic;
  	signal	result_fifo_write     	:	std_logic;
  	signal	result_fifo_in_packet 	:	std_logic_vector(RESULT_WIDTH-1 downto 0); 
  	signal	result_fifo_out_packet	:	std_logic_vector(RESULT_WIDTH-1 downto 0); 
  	signal	data_valid            	:	std_logic;

	-- sender control states
	type     	sendercontrol_type	is	( -- see sendercontrol process for an explanation of all states.
	         	                  	  	idle, 
	         	                  	  	drop, 
	         	                  	  	send_stalled, 
	         	                  	  	send_nextbyte); 
	signal   	sender_state      	: 	sendercontrol_type;
	signal   	sender_next_state 	: 	sendercontrol_type;
	signal   	sender_last_state 	: 	sendercontrol_type;
	-- type  	result_type       	is	( -- possible states of a packet.
	--       	                  	unknown,
	--       	                  	good, 
	--       	                  	evil); 
	-- signal	result            	:	result_type; -- result of the checks. 
	signal   	result_good       	:	std_logic; -- Output of the content analysers, i.e.
	signal   	result_evil       	:	std_logic; --    at the input of the result_fifo
	signal   	result_send       	:	std_logic; -- The resp. values, but
	signal   	result_drop       	:	std_logic; --    at the output of the result_fifo


	-- TODO: declare more signals, especially:
		-- packet_fifo_read
		-- result
		-- content analysers ready
		-- log data signals, probably some counters...


	-- TODO debug
	--signal	foo1	:	std_logic_vector(0 to PACKET_WIDTH-8-2-1);
	--signal	foo2	:	std_logic_vector(0 to PACKET_WIDTH-8-2-1);
	signal  	foo3	:	std_logic_vector(15 downto 0);
	signal  	foo4	:	std_logic_vector(15 downto 0);







	-- include components

	component fifo32_packets is
	generic (
		C_FIFO32_WORD_WIDTH       	:	integer	:= PACKET_WIDTH;
		C_FIFO32_DATA_SIGNAL_WIDTH	:	integer	:= 16;
		C_FIFO32_DEPTH            	:	integer := 4
	);
		port (
		Rst           	:	in	std_logic;
		-- ..._M_...  	=	input of the FIFO.
		-- ..._S_...  	=	output of the FIFO.
		FIFO32_S_Clk  	:	in 	std_logic;                                              	-- clock and data signals
		FIFO32_M_Clk  	:	in 	std_logic;                                              	
		FIFO32_S_Data 	:	out	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);       	
		FIFO32_M_Data 	:	in 	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);       	
		FIFO32_S_Fill 	:	out	std_logic_vector(C_FIFO32_DATA_SIGNAL_WIDTH-1 downto 0);	-- # elements in the FIFO. 0 means FIFO is empty.
		FIFO32_M_Rem  	:	out	std_logic_vector(C_FIFO32_DATA_SIGNAL_WIDTH-1 downto 0);	-- remaining free space. 0 means FIFO is full.
		FIFO32_S_Full 	:	out	std_logic;                                              	-- FIFO full signal
		FIFO32_M_Empty	:	out	std_logic;                                              	-- FIFO empty signal
		FIFO32_S_Rd   	:	in 	std_logic;                                              	-- output data ready
		FIFO32_M_Wr   	:	in 	std_logic   
		-- old and probably not working.
		-- rst          	: in 	std_logic;
		-- fifo_out_clk 	: in 	std_logic;
		-- fifo_in_clk  	: in 	std_logic;
		-- fifo_out_data	: out	std_logic_vector(31 downto 0);
		-- fifo_in_data 	: in 	std_logic_vector(31 downto 0);
		-- fifo_out_fill	: out	std_logic_vector(15 downto 0);
		-- fifo_in_rem  	: out	std_logic_vector(15 downto 0);
		-- fifo_out_rd  	: in 	std_logic;
		-- fifo_in_wr   	: in 	std_logic
		);
	end component;

		component fifo32_results is
	generic (
		C_FIFO32_WORD_WIDTH       	:	integer	:= RESULT_WIDTH;
		C_FIFO32_DATA_SIGNAL_WIDTH	:	integer	:= 16;
		C_FIFO32_DEPTH            	:	integer := 4
	);
		port (
		Rst           	:	in	std_logic;
		-- ..._M_...  	=	input of the FIFO.
		-- ..._S_...  	=	output of the FIFO.
		FIFO32_S_Clk  	:	in 	std_logic;                                              	-- clock and data signals
		FIFO32_M_Clk  	:	in 	std_logic;                                              	
		FIFO32_S_Data 	:	out	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);       	
		FIFO32_M_Data 	:	in 	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);       	
		FIFO32_S_Fill 	:	out	std_logic_vector(C_FIFO32_DATA_SIGNAL_WIDTH-1 downto 0);	-- # elements in the FIFO. 0 means FIFO is empty.
		FIFO32_M_Rem  	:	out	std_logic_vector(C_FIFO32_DATA_SIGNAL_WIDTH-1 downto 0);	-- remaining free space. 0 means FIFO is full.
		FIFO32_S_Full 	:	out	std_logic;                                              	-- FIFO full signal
		FIFO32_M_Empty	:	out	std_logic;                                              	-- FIFO empty signal
		FIFO32_S_Rd   	:	in 	std_logic;                                              	-- output data ready
		FIFO32_M_Wr   	:	in 	std_logic   

		);
	end component;

	-- component content_analysers is
	--		TODO
	-- end component


--				########  ########  ######   #### ##    ## 
--				##     ## ##       ##    ##   ##  ###   ## 
--				##     ## ##       ##         ##  ####  ## 
--				########  ######   ##   ####  ##  ## ## ## 
--				##     ## ##       ##    ##   ##  ##  #### 
--				##     ## ##       ##    ##   ##  ##   ### 
--				########  ########  ######   #### ##    ## 
begin

  	-- TODO remove these hardcoded debug assignments
  	--foo1          	<=                                 	(others => '0');
  	data_valid      	<=                                 	'1'; -- = packet_fifo_write.
  	packet_fifo_read	<=                                 	debug_fifo_read; --'1'; 
--	test            	<=                                 	not rx_ll_src_rdy;
  	rx_ll_dst_rdy   	<= '0' when rst = RESET else       	'1';
--	tx_ll_sof       	<= '0' when rst = RESET else       	rx_ll_sof;
--	tx_ll_eof       	<= '0' when rst = RESET else       	rx_ll_eof;
--	tx_ll_data      	<= "00000000" when rst = RESET else	rx_ll_data;
  	tx_ll_src_rdy   	<= '0' when rst = RESET else       	'1';
--	rx_ll_dst_rdy   	<= '0' when rst = '1' else         	'1';
--	tx_ll_sof       	<= '0' when rst = '1' else         	rx_ll_sof;
--	tx_ll_eof       	<= '0' when rst = '1' else         	rx_ll_eof;
--	tx_ll_data      	<= "00000000" when rst = '1' else  	rx_ll_data;
--	tx_ll_src_rdy   	<= '0' when rst = '1' else         	'1';




	-- define a "packet" as data, sof and eof signals.
	-- packets will not be sent directly, but be stored in a fifo buffer until all checks are done.
	packet_fifo_in_packet(7 downto 0)     	<=	rx_ll_data;
	packet_fifo_in_packet(8)              	<=	rx_ll_sof;
	packet_fifo_in_packet(9)              	<=	rx_ll_eof;
	--fifo_in_packet(10 to PACKET_WIDTH-1)	<=	foo1;
	tx_ll_data                            	<=	packet_fifo_out_packet(7 downto 0);
	tx_ll_sof                             	<=	packet_fifo_out_packet(8);
	out_packet_eof                        	<=	packet_fifo_out_packet(9); -- intermediate signal, needed to ckeck for EOF.
	tx_ll_eof                             	<=	out_packet_eof; 
	packet_fifo_write                     	<=	debug_fifo_write; -- data_valid;

	-- the results need to be queued too, s.t. new results can be created while a FIFO'ed packet is being sent.
	result_fifo_in_packet(0)	<=	result_good;              	-- packets marked as "good"...
	result_send             	<=	result_fifo_out_packet(0);	-- ...can be sent.
	result_fifo_in_packet(1)	<=	result_evil;              	-- packets marked as "evil"...
	result_drop             	<=	result_fifo_out_packet(1);	-- ...have to be dropped.


	-- TODO content analysers instance goes here


	-- instatiate first FIFO for the packets
	packet_fifo : fifo32_packets

	port map(
		Rst            	=> rst, 
		FIFO32_S_Clk   	=> clk,
		FIFO32_M_Clk   	=> clk,
		FIFO32_S_Data  	=> packet_fifo_out_packet, --tx_ll_data & tx_ll_sof & tx_ll_eof & foo1, -- packet vector
		FIFO32_M_Data  	=> packet_fifo_in_packet, --rx_ll_data & rx_ll_sof & rx_ll_eof & foo2, -- packet vector
		--FIFO32_S_Fill	=> , -- unused, we need full and empty only.
		--FIFO32_M_Rem 	=> , -- unused, we need full and empty only.
		FIFO32_S_Fill  	=> foo3, -- TODO leDebug
		FIFO32_M_Rem   	=> foo4, -- TODO leDebug
		FIFO32_S_Full  	=> packet_fifo_full, 
		FIFO32_M_Empty 	=> packet_fifo_empty, 
		FIFO32_S_Rd    	=> packet_fifo_read, 
		FIFO32_M_Wr    	=> packet_fifo_write
	);


	-- instantiate a second FIFO for the results 
	result_fifo : fifo32_results
	-- TODO fuuuuuuuuu I need the generics here... not in the declaration!
	port map(
		Rst            	=> rst, 
		FIFO32_S_Clk   	=> clk,
		FIFO32_M_Clk   	=> clk,
		FIFO32_S_Data  	=> result_fifo_out_packet,
		FIFO32_M_Data  	=> result_fifo_in_packet, 
		--FIFO32_S_Fill	=> , -- unused, we need full and empty only.
		--FIFO32_M_Rem 	=> , -- unused, we need full and empty only.
		FIFO32_S_Full  	=> result_fifo_full, -- TODO maybe these wouldn't be really necessary, as this FIFO can not get full resp. empty as long as the packet_fifo is not full resp. empty.
		FIFO32_M_Empty 	=> result_fifo_empty, -- TODO think about this
		FIFO32_S_Rd    	=> result_fifo_read, 
		FIFO32_M_Wr    	=> result_fifo_write
	);



	-- "sender control" state machine.
	-- Apart from the actual content analysis, this process is the most important of the IPS entity.
	-- It controls the entire data flow, i.e. it checks results and sends or drops packets.

	-- State hierarchy of sender control: TODO update me.
	-- idle          	(start here)
	--               	FIFO is empty, nothing to do.
	-- working_      	(superstate)
	--               	FIFO is not empty. There is something to do...
	--    checkresult	(start here within superstate, 1st time only)
	--               	Sender does not know analysis result yet. Wait...
	--    droppacket 	Result is known and stated that the packet is evil.
	--               	Read next byte from FIFO and drop it, until EOF.
	--    send_      	(superstate)
	--               	Result is known and stated that the packet is fine.
	--               	i.e. we need to send it, until EOF.
	--       stalled 	(start here within superstate)
	--               	Reveicer is not ready or unknown.
	--               	check if receiver is ready.
	--       nextbyte	Reveiver is ready.
	--               	Read next byte from FIFO and send it.

	sendercontrol_memzing : process(clk, rst)
	-- TODO auf 0 setzen während dem RESETisieren:
		-- rx...dst_rdy
		-- tx...src_rdy

	begin
		-- register with asynchronous reset.
		if (reset = RESET) then
			sender_state <= idle;
		elsif (rising_edge(clk)) then
			--sender_last_state <= sender_state;
			-- mach das nur, wenn es von einem Working State in den idle geht
			sender_state <= sender_next_state;
		end if;
	end process;

	sendercontrol_memless : process(sender_state) -- <-- TODO öpdeit sensitivity list / oder mal probieren das ganze einfach ohne Prozess zu machen.
	begin
		case sender_state is
			when idle =>
				-- update outputs
				-- check if next result is ready
				result_fifo_read	<= '0';
				packet_fifo_read	<= '0'; 
				tx_ll_src_rdy   	<= '0'; 
				-- TODO log.

				-- update next state
				if (result_fifo_empty = '0' and packet_fifo_empty = '0') then
					result_fifo_read <= '1';
					if (result_drop = '1') then
						sender_next_state <= drop; 
					elsif (result_send = '1') then 
						if (tx_ll_dst_rdy = '0') then 
							sender_next_state <= send_stalled;
						else
							sender_next_state <= send_nextbyte;
						end if;
					else
						-- result is "unknown". 
						-- This should not happen..... 
						debug_severe_error <= '1'; 
						sender_next_state <= idle; 
					end if; 
				end if; 

			when drop =>
				-- While dropping, it does not matter if the receiver is ready. 
				-- Neither is it important if the FIFO is empty or not, as it will not send any new data.
				result_fifo_read	<= '0';
				packet_fifo_read	<= '1'; 
				tx_ll_src_rdy   	<= '0'; 
				-- TODO log.

				if (out_packet_eof = '1' ) then 
					sender_next_state <= idle;
				else
					sender_next_state <= drop;
				end if; 

			when send_nextbyte =>
				result_fifo_read	<= '0';
				packet_fifo_read	<= '1'; 
				tx_ll_src_rdy   	<= '1'; 
				-- TODO log.

				if (out_packet_eof = '1') then 
					sender_next_state <= idle;
				elsif (tx_ll_dst_rdy = '1' and packet_fifo_empty = '0') then 
					sender_next_state <= send_nextbyte; 
				else
					sender_next_state <= send_stalled; 
				end if; 

			when send_stalled =>
				result_fifo_read	<= '0';
				packet_fifo_read	<= '0'; 
				tx_ll_src_rdy   	<= '1'; 
				-- TODO log.

				-- Checking for EOF makes no sense while we are stalled.
				-- Apart from this, do the same checks as when in send state.
				if (tx_ll_dst_rdy = '1' and packet_fifo_empty = '0') then 
					sender_next_state <= send_nextbyte; 
				else
					sender_next_state <= send_stalled; 
				end if; 

		end case;
	end process; -- end sendercontrol_memless




	-- TODO "receiver control" goes here
		-- process which receives data and generates data_valid signal


	-- TODO all the h2s logging stuff.


end architecture;
