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


-- This it the uppermost entity of the IPS. It:
   -- handles the receiving of incoming packets.
   -- forwards input data to the packet inspection entity.
   -- buffers the packets while they are checked for attacks.
   -- sends resp. drops packets, depending of the result of the packet inspection.

-- the packet inspection can be found in packet_inspection.vhd entity and the actual content analysis is performed by the .vhd entities in the content_analysers folder.


entity ips is
	-- copypasta from the adder.
	--	generic (
	--		destination		: std_logic_vector(5 downto 0);
	--		sender     		: std_logic
	--	);
	port (
		-- debug_fifo_read    	:	in 	std_logic;
		-- debug_fifo_write   	:	in 	std_logic;
		-- debug_severe_error 	:	out	std_logic; 
		-- debug_result_result	:	in 	std_logic; 
		-- debug_result_valid 	:	in 	std_logic; 
		rst                   	:	in 	std_logic;
		clk                   	:	in 	std_logic;
		rx_ll_sof             	:	in 	std_logic;
		rx_ll_eof             	:	in 	std_logic;
		rx_ll_data            	:	in 	std_logic_vector(7 downto 0);
		rx_ll_src_rdy         	:	in 	std_logic;
		rx_ll_dst_rdy         	:	out	std_logic;	
		tx_ll_sof             	:	out	std_logic;
		tx_ll_eof             	:	out	std_logic;
		tx_ll_data            	:	out	std_logic_vector(7 downto 0);
		tx_ll_src_rdy         	:	out	std_logic;
		tx_ll_dst_rdy         	:	in 	std_logic
	);
end ips;


architecture implementation of ips is

	-- some constants
	constant	RESET       	:	std_logic	:= '1'; -- define if rst is active low or active high
	constant	GOOD_FORWARD	:	std_logic	:= '1';	-- used constants instead of a "type" to simplify feeding it into a FIFO of std_logic_vector's.
	constant	EVIL_DROP   	:	std_logic	:= '0';	
	constant	PACKET_WIDTH	:	integer  	:= 10; 	-- width of data + control bits (sof, eof, etc.)
	constant	RESULT_WIDTH	:	integer  	:= 1;  	-- width of the result (good or evil, note that all results in the FIFO have to be valid!)


	--			 ######   ####   ######    ##    ##     ###     ## 
	--			##    ##   ##   ##    ##   ###   ##    ## ##    ##
	--			##         ##   ##         ####  ##   ##   ##   ## 
	--			 ######    ##   ##   ####  ## ## ##  ##     ##  ## 
	--			      ##   ##   ##    ##   ##  ####  #########  ## 
	--			##    ##   ##   ##    ##   ##   ###  ##     ##  ## 
	--			 ######   ####   ######    ##    ##  ##     ##  ######## 
	-- signal declarations

	--signal	test                   	:	std_logic	:= '0'; 
	signal  	packet_fifo_full       	:	std_logic;
	signal  	packet_fifo_empty      	:	std_logic;
	signal  	packet_fifo_read       	:	std_logic;
	signal  	packet_fifo_write      	:	std_logic;
	signal  	packet_fifo_in_packet  	:	std_logic_vector(PACKET_WIDTH-1 downto 0); 
	signal  	packet_fifo_out_packet 	:	std_logic_vector(PACKET_WIDTH-1 downto 0); 
	signal  	out_packet_eof         	:	std_logic; -- intermediate signals, needed because we need to write and read to them. 
	--signal	result_fifo_full       	:	std_logic;
	signal  	result_fifo_empty      	:	std_logic;
	signal  	result_fifo_read       	:	std_logic;
	--signal	result_fifo_write      	:	std_logic;
	--signal	result_fifo_in_packet  	:	std_logic_vector(RESULT_WIDTH-1 downto 0); 
	signal  	result_fifo_out_packet 	:	std_logic_vector(RESULT_WIDTH-1 downto 0); 
	signal  	data_valid             	:	std_logic; -- internal input data valid signal. See receivercontrol for what it means.
	signal  	receiver_ready         	:	std_logic; -- intermediate signal for rx_ll_dst_rdy, needed because we need to write and read to them. 
	signal  	packet_inspection_ready	:	std_logic;




	-- sender control states
	type    	sendercontrol_type	is	( -- see sendercontrol process for an explanation of all states.
	        	                  	  	idle, 
	        	                  	  	drop, 
	        	                  	  	send_stalled, 
	        	                  	  	send_nextbyte); 
	signal  	sender_state      	: 	sendercontrol_type;
	signal  	sender_next_state 	: 	sendercontrol_type;
	--signal	sender_last_state 	: 	sendercontrol_type;
	--type  	result_type       	is	(            	
	--      	                  	  	good_forward,	
	--      	                  	  	evil_drop); 
	signal  	result            	: 	std_logic;	-- possible outcomes of the packet inspection are defined in the constants above. 
	signal  	result_valid      	: 	std_logic;	-- Note that the result is futile as long as the result_valid bit is not set.
	--signal	result_good       	: 	std_logic;	-- Output of the content analysers, i.e.
	--signal	result_evil       	: 	std_logic;	--    at the input of the result_fifo
	--signal	result_before_fifo	: 	std_logic;	-- The resp. values, but
	--signal	result_drop       	: 	std_logic;	--    at the output of the result_fifo


	-- TODO: declare log data signals (counters).


	-- some debug signals
	--signal	foo1	:	std_logic_vector(0 to PACKET_WIDTH-8-2-1);
	--signal	foo2	:	std_logic_vector(0 to PACKET_WIDTH-8-2-1);
	--signal	foo3	:	std_logic_vector(15 downto 0);
	--signal	foo4	:	std_logic_vector(15 downto 0);


	-- include components

	component fifo32 is 
	generic (
		C_FIFO32_WORD_WIDTH         	:	integer	:= PACKET_WIDTH;
		C_FIFO32_DEPTH              	:	integer := 4;
		C_FIFO32_CONTROLSIGNAL_WIDTH	:	integer	:= 16;
		CLOG2_FIFO32_DEPTH          	:	integer := 4;
		C_FIFO32_SAFE_READ_WRITE    	:	boolean	:= true
	);
		port (
		Rst           	:	in	std_logic;
		-- ..._M_...  	=	input of the FIFO.
		-- ..._S_...  	=	output of the FIFO.
		FIFO32_S_Clk  	:	in 	std_logic;                                                	-- clock and data signals
		FIFO32_M_Clk  	:	in 	std_logic;                                                	
		FIFO32_S_Data 	:	out	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);         	
		FIFO32_M_Data 	:	in 	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);         	
		FIFO32_S_Fill 	:	out	std_logic_vector(C_FIFO32_CONTROLSIGNAL_WIDTH-1 downto 0);	-- # elements in the FIFO. 0 means FIFO is empty.
		FIFO32_M_Rem  	:	out	std_logic_vector(C_FIFO32_CONTROLSIGNAL_WIDTH-1 downto 0);	-- remaining free space. 0 means FIFO is full.
		FIFO32_S_Full 	:	out	std_logic;                                                	-- FIFO full signal
		FIFO32_M_Empty	:	out	std_logic;                                                	-- FIFO empty signal
		FIFO32_S_Rd   	:	in 	std_logic;                                                	-- output data ready
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

	-- not needed anymore 
	-- component fifo32_results is
	-- generic (
	--	C_FIFO32_WORD_WIDTH         	:	integer	:= RESULT_WIDTH;
	--	C_FIFO32_CONTROLSIGNAL_WIDTH	:	integer	:= 16;
	--	C_FIFO32_DEPTH              	:	integer := 4
	-- );
	--	port (
	--	Rst           	:	in	std_logic;
	--	-- ..._M_...  	=	input of the FIFO.
	--	-- ..._S_...  	=	output of the FIFO.
	--	FIFO32_S_Clk  	:	in 	std_logic;                                                	-- clock and data signals
	--	FIFO32_M_Clk  	:	in 	std_logic;                                                	
	--	FIFO32_S_Data 	:	out	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);         	
	--	FIFO32_M_Data 	:	in 	std_logic_vector(C_FIFO32_WORD_WIDTH-1 downto 0);         	
	--	FIFO32_S_Fill 	:	out	std_logic_vector(C_FIFO32_CONTROLSIGNAL_WIDTH-1 downto 0);	-- # elements in the FIFO. 0 means FIFO is empty.
	--	FIFO32_M_Rem  	:	out	std_logic_vector(C_FIFO32_CONTROLSIGNAL_WIDTH-1 downto 0);	-- remaining free space. 0 means FIFO is full.
	--	FIFO32_S_Full 	:	out	std_logic;                                                	-- FIFO full signal
	--	FIFO32_M_Empty	:	out	std_logic;                                                	-- FIFO empty signal
	--	FIFO32_S_Rd   	:	in 	std_logic;                                                	-- output data ready
	--	FIFO32_M_Wr   	:	in 	std_logic
	--	);
	-- end component;

	component packet_inspection is
	port (
		rst                      	:	in 	std_logic;
		clk                      	:	in 	std_logic;
		rx_sof                   	:	in 	std_logic;
		rx_eof                   	:	in 	std_logic;
		rx_data                  	:	in 	std_logic_vector(7 downto 0);
		rx_data_valid            	:	in 	std_logic;
		rx_packetinspection_ready	:	out	std_logic;
		tx_result                	:	out	std_logic; -- from the outside this interface looks like a FIFO
		tx_fifo_empty            	:	out	std_logic;
		tx_fifo_read             	:	in 	std_logic
	);
	end component;


--				########   ########   ######    ####  ##    ## 
--				##     ##  ##        ##    ##    ##   ###   ## 
--				##     ##  ##        ##          ##   ####  ## 
--				########   ######    ##   ####   ##   ## ## ## 
--				##     ##  ##        ##    ##    ##   ##  #### 
--				##     ##  ##        ##    ##    ##   ##   ### 
--				########   ########   ######    ####  ##    ## 
begin
	-- debug: some hardcoded assignments
	--foo1                   	<=                                 	(others => '0');
	--data_valid             	<=                                 	'1'; -- = packet_fifo_write.
	--packet_fifo_read       	<=                                 	debug_fifo_read; --'1'; 
	--test                   	<=                                 	not rx_ll_src_rdy;
	--tx_ll_dst_rdy          	<= '0' when rst = RESET else       	'1';
	--tx_ll_sof              	<= '0' when rst = RESET else       	rx_ll_sof;
	--tx_ll_eof              	<= '0' when rst = RESET else       	rx_ll_eof;
	--tx_ll_data             	<= "00000000" when rst = RESET else	rx_ll_data;
	--tx_ll_src_rdy          	<= '0' when rst = RESET else       	'1';
	--rx_ll_dst_rdy          	<= '0' when rst = '1' else         	'1';
	--tx_ll_sof              	<= '0' when rst = '1' else         	rx_ll_sof;
	--tx_ll_eof              	<= '0' when rst = '1' else         	rx_ll_eof;
	--tx_ll_data             	<= "00000000" when rst = '1' else  	rx_ll_data;
	--tx_ll_src_rdy          	<= '0' when rst = '1' else         	'1';
	--result_fifo_empty      	<= '0';                            	
	--result_fifo_write      	<= debug_result_valid; -- will come from content analysers
	--packet_inspection_ready	<= '1';
	--result_before_fifo     	<=	debug_result_result; 
	--result_evil            	<=	debug_result_valid; 

	-- define a "packet" as data, sof and eof signals.
	-- packets will not be sent directly, but be stored in a fifo buffer until all checks are done.
	packet_fifo_in_packet(7 downto 0)     	<=	rx_ll_data;
	packet_fifo_in_packet(8)              	<=	rx_ll_sof;
	packet_fifo_in_packet(9)              	<=	rx_ll_eof;
	--fifo_in_packet(10 to PACKET_WIDTH-1)	<=	foo1;
	tx_ll_data                            	<=	packet_fifo_out_packet(7 downto 0);
	tx_ll_sof                             	<=	packet_fifo_out_packet(8);
	out_packet_eof                        	<=	packet_fifo_out_packet(9); 
	tx_ll_eof                             	<=	out_packet_eof; 
	packet_fifo_write                     	<=	data_valid;

	-- the results need to be queued too, s.t. new results can be created while a FIFO'ed packet is being sent.
	--result_fifo_in_packet(0)	<=	result_before_fifo;       	-- packets marked as "good"...
	--result                  	<=	result_fifo_out_packet(0);	-- ...can be sent.
	--result_fifo_in_packet(1)	<=	result_evil;              	-- packets marked as "evil"...
	--result_drop             	<=	result_fifo_out_packet(1);	-- ...have to be dropped.


	-- component instantiations

	-- the main component: contains all content analysis entities.
	packet_inspection_inst : packet_inspection
	port map(
		rst                      	=>	rst,
		clk                      	=>	clk,
		rx_sof                   	=>	rx_ll_sof,
		rx_eof                   	=>	rx_ll_eof,
		rx_data                  	=>	rx_ll_data,
		rx_data_valid            	=>	data_valid,
		rx_packetinspection_ready	=>	packet_inspection_ready,
		tx_result                	=>	result,
		tx_fifo_empty            	=>	result_fifo_empty,
		tx_fifo_read             	=>	result_fifo_read
	);


	-- a FIFO which can hold at least one packet
	packet_fifo : fifo32
	generic map(
		C_FIFO32_WORD_WIDTH           	=> PACKET_WIDTH,
		C_FIFO32_DEPTH                	=> 2000,	-- TODO packet buffer size / min. packet size
		CLOG2_FIFO32_DEPTH            	=> 11,  	-- TODO check. probably ok like this.
		--C_FIFO32_CONTROLSIGNAL_WIDTH	=> ;    	-- unused, as we need the full and empty signals only.
		C_FIFO32_SAFE_READ_WRITE      	=> true
	)
	port map(
		Rst            	=> rst, 
		FIFO32_S_Clk   	=> clk,
		FIFO32_M_Clk   	=> clk,
		FIFO32_S_Data  	=> packet_fifo_out_packet,	-- packet vector, i.e. data / SOF / EOF
		FIFO32_M_Data  	=> packet_fifo_in_packet, 
		--FIFO32_S_Fill	=> ,	-- unused, we need full and empty only.
		--FIFO32_M_Rem 	=> ,	-- unused, we need full and empty only.
		--FIFO32_S_Fill	=> foo3,
		--FIFO32_M_Rem 	=> foo4,
		FIFO32_S_Full  	=> packet_fifo_full, 
		FIFO32_M_Empty 	=> packet_fifo_empty, 
		FIFO32_S_Rd    	=> packet_fifo_read, 
		FIFO32_M_Wr    	=> packet_fifo_write
	);


	-- instantiate a second FIFO for the results 
	--> not needed anymore as the packet inspection provides this interface.

	-- result_fifo : fifo32
	-- generic map(
	--	C_FIFO32_WORD_WIDTH           	=> RESULT_WIDTH,
	--	C_FIFO32_DEPTH                	=> 42,	-- TODO 
	--	CLOG2_FIFO32_DEPTH            	=> 11,	-- TODO 
	--	--C_FIFO32_CONTROLSIGNAL_WIDTH	=> ;  	-- unused, as we need the full and empty signals only.
	--	C_FIFO32_SAFE_READ_WRITE      	=> true
	-- ) 
	-- port map(
	--	Rst            	=> rst, 
	--	FIFO32_S_Clk   	=> clk,
	--	FIFO32_M_Clk   	=> clk,
	--	FIFO32_S_Data  	=> result_fifo_out_packet,
	--	FIFO32_M_Data  	=> result_fifo_in_packet, 
	--	--FIFO32_S_Fill	=> ,                 	-- unused, we need full and empty only.
	--	--FIFO32_M_Rem 	=> ,                 	-- unused, we need full and empty only.
	--	FIFO32_S_Full  	=> result_fifo_full, 	-- Note that the result FIFO can still be empty although there is a packet in the packet FIFO.
	--	FIFO32_M_Empty 	=> result_fifo_empty,	-- This happens if a content analysis takes longer than the packet, e.g. due to pipelining.
	--	FIFO32_S_Rd    	=> result_fifo_read, 
	--	FIFO32_M_Wr    	=> result_fifo_write
	-- );


	-- processes

	-- "sender control" state machine.
	-- Apart from the actual content analysis, this process is the most important of the IPS entity.
	-- It controls the entire data flow, i.e. it checks results and sends or drops packets.
	-- 
	-- overview of the states:
	--
	-- idle         	(initial state). 
	--              	The data FIFO or the result FIFO is empty.
	--              	Nothing to do so far. 
	-- drop         	Result is known to be evil. 
	--              	Read the next byte from the FIFO and drop it, until EOF.  
	-- send_nextbyte	packet is known to be good.
	--              	Read the next byte from the FIFO and send it, until EOF.  
	-- send_stalled 	We like to send, but the receiver is not ready. 
	--              	Wait until it becomes ready. 

	sendercontrol_memzing : process(clk, rst)
	begin
		-- register with asynchronous reset.
		if (rst = RESET) then
			sender_state	<= idle;
			-- don't be ready during reset:
			--tx_ll_src_rdy	<= '0'; -- automatically done while in "idle" state :-)
			--rx_ll_dst_rdy <= '0'; -- is done in the receivercontrol part
		elsif (rising_edge(clk)) then
			--sender_last_state <= sender_state;
			sender_state <= sender_next_state;
		end if;
	end process;

	sendercontrol_memless : process(	sender_state,     	-- the FSM must know the current state of course
	                                	result_fifo_empty,	-- it must get notified if fifos is empty or not, EOF or if the dest is not ready anymore.
	                                	packet_fifo_empty,	-- 
	                                	tx_ll_dst_rdy,    	-- 
	                                	out_packet_eof    	-- 
	                                	--result_send,    	-- maybe the result isn't really needed because it is already sensitive to the FIFO empty signal..
	                                	--result_drop     	-- 
	                                	)
	begin
		--default:
		result_fifo_read 	<= '0';
		packet_fifo_read 	<= '0'; 
		tx_ll_src_rdy    	<= '0'; 
		sender_next_state	<= sender_state; 
		
		case sender_state is

			when idle =>
				result_fifo_read	<= '0';
				packet_fifo_read	<= '0'; 
				tx_ll_src_rdy   	<= '0'; 

				-- check if data and result are ready
				if (result_fifo_empty = '0' and packet_fifo_empty = '0') then
					result_fifo_read <= '1'; -- read next result
					-- note that there are only valid results in the FIFO, there is no need to explicitely check result_valid.
					if (result = EVIL_DROP) then
						sender_next_state <= drop; 
					else -- i.e. (result = GOOD_FORWARD) then 
						-- check if the receiver is ready.
						if (tx_ll_dst_rdy = '0') then 
							sender_next_state <= send_stalled;
						else
							sender_next_state <= send_nextbyte;
						end if;
					--else
					  	-- result is "unknown". 
					  	-- This should not happen..... 
					--	debug_severe_error	<= '1'; 
					--	sender_next_state 	<= idle; 
					end if; 
				end if; 

			when send_nextbyte =>
				result_fifo_read	<= '0';
				packet_fifo_read	<= '1'; 
				tx_ll_src_rdy   	<= '1'; 

				-- TODO logging code goes here.

				if (out_packet_eof = '1') then 
					sender_next_state <= idle; -- TODO Possible optimisation, see below.
				elsif (tx_ll_dst_rdy = '1') then 
					sender_next_state <= send_nextbyte; 
					-- TODO Probably the next 4 lines are not needed because not the FIFO can not become empty after all... But not sure.
					if (packet_fifo_empty = '1') then 
						sender_next_state	<= send_stalled; 
						tx_ll_src_rdy    	<=	'0';
					end if; 
				end if; 

				-- TODO possible optimisation:
				   -- Jump directly to the next packet (i.e. send_nextbyte state) if the next packet is already waiting in the FIFO.

			when send_stalled =>
				-- While stalled, don't read the next byte fron the fifo. So, checking for EOF makes no sense.
				-- Apart from these two things, do the same as in send state.

				result_fifo_read	<= '0';
				packet_fifo_read	<= '0'; 
				tx_ll_src_rdy   	<= '1'; 

				if (tx_ll_dst_rdy = '1') then 
					sender_next_state <= send_nextbyte; 
					-- TODO Probably the next 4 lines are not needed because not the FIFO can not become empty after all... But not sure.
					if (packet_fifo_empty = '1') then 
						sender_next_state	<= send_stalled; 
						tx_ll_src_rdy    	<=	'0';
					end if; 
				end if; 

			when drop =>
				-- While dropping, it does not matter if the receiver is ready. 
				-- Neither is it important if the FIFO is empty or not, as it will not "underflow" when empty.
				result_fifo_read	<= '0';
				packet_fifo_read	<= '1'; 
				tx_ll_src_rdy   	<= '0'; 

				-- TODO logging code goes here.

				if (out_packet_eof = '1' ) then 
					sender_next_state <= idle; -- TODO Possible optimisation, see below.
				else
					sender_next_state <= drop;
				end if; 

		end case; -- sender_state
	end process; -- sendercontrol_memless

	-- Possible optimisation: 
	   -- Don't jump to idle state when the next packet and result are already "waiting" in the FIFO. 
	   -- Instead, directly jump to send_nextbyte send_stalled or drop states.


	receivercontrol : process(	-- purely combinatorial, i.e. sensitive to everything.
	                          	rst, 
	                          	packet_fifo_full, 
	                          	--result_fifo_full,
	                          	packet_inspection_ready,
	                          	rx_ll_src_rdy,
	                          	receiver_ready)
	begin
		receiver_ready   	<=	(not packet_fifo_full)	and packet_inspection_ready; --and (not result_fifo_full) 
		data_valid       	<=	rx_ll_src_rdy         	and receiver_ready;
		-- TODO:         	
		-- receiver_ready	<=	'0' when (rst = RESET)	else bla bla...;
		rx_ll_dst_rdy    	<=	receiver_ready;
	end process; 


	-- TODO all the h2s logging stuff (i.e. wiring the resp. signals to.


end architecture;
