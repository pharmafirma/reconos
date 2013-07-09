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









entity packet_inspection is
	port (
		rst                      	:	in 	std_logic;
		clk                      	:	in 	std_logic;
		rx_sof                   	:	in 	std_logic;
		rx_eof                   	:	in 	std_logic;
		rx_data                  	:	in 	std_logic_vector(7 downto 0);
		rx_data_valid            	:	in 	std_logic;
		rx_packetinspection_ready	:	out	std_logic;
		--result_good            	:	out	std_logic;
		--result_evil            	:	out	std_logic;
		tx_result                	:	out	std_logic; -- from the outside this interface looks like a FIFO
		tx_fifo_empty            	:	out	std_logic;
		tx_fifo_read             	:	in 	std_logic
	);
end packet_inspection;

--------------------------------------------------------------

architecture implementation of packet_inspection is


	-- some constants
	constant	RESET            	:	std_logic	:= '1'; -- define if rst is active low or active high
	constant	GOOD_FORWARD     	:	std_logic	:= '1'; -- used constants instead of a "type" to simplify queuing.
	constant	EVIL_DROP        	:	std_logic	:= '0';
	constant	RESULT_WIDTH     	:	integer  	:= 1; -- in bits (good / evil).
	constant	HEADER_MAX_LENGTH	:	integer  	:= 3; -- Maximum length of header data (in bytes).






	--			 ######  ####  ######   ##    ##    ###    ## 
	--			##    ##  ##  ##    ##  ###   ##   ## ##   ##
	--			##        ##  ##        ####  ##  ##   ##  ## 
	--			 ######   ##  ##   #### ## ## ## ##     ## ## 
	--			      ##  ##  ##    ##  ##  #### ######### ## 
	--			##    ##  ##  ##    ##  ##   ### ##     ## ## 
	--			 ######  ####  ######   ##    ## ##     ## ######## 
	-- signal declarations



	-- the header has not to be checked by the IPS. 
	signal	header_length        	:  	integer	range 0 to HEADER_MAX_LENGTH; -- in bytes
	signal	skipheader_count     	:  	integer	range 0 to HEADER_MAX_LENGTH; -- in bytes
	signal	skipheader_next_count	:  	integer	range 0 to HEADER_MAX_LENGTH; -- in bytes
	type  	skipheader_type      	is(	idle, 
	      	                     	   	next_header_byte, 
	      	                     	   	next_data_byte); 
	signal	skipheader_state     	:  	skipheader_type;	
	signal	skipheader_next_state	:  	skipheader_type; 
	signal	check_me             	:  	std_logic; -- "data_valid" signal for the content analyser blocks. Will be set to 1 when the header is over :).
	signal	fifo_read            	:  	std_logic; -- one fifo_read for all FIFOs is enough.
	signal	fifo_empty           	:  	std_logic; -- intermediate signal for tx_fifo_empty
	-- to be "generic'ised" one day...
	signal	ca_ready_1     	:	std_logic; -- n'th content analyser block ready
	signal	result_1       	:	std_logic; -- result output of the n'tn content analyser block, input of the n'th FIFO
	signal	result_valid_1 	:	std_logic; -- valid bit of result_n
	signal	queued_result_1	:	std_logic; -- queued version of result_1, output of the FIFO
	signal	fifo_full_1    	:	std_logic; -- read, write, full and empty signal for the n'th FIFO
	signal	fifo_empty_1   	:	std_logic; 
	signal	fifo_write_1   	:	std_logic; 
	-- create std_logic_vector's for the fifos.
	signal	fifo_in_1 	:	std_logic_vector(RESULT_WIDTH-1 downto 0);
	signal	fifo_out_1	:	std_logic_vector(RESULT_WIDTH-1 downto 0);


	-- include components


	-- include one component for each content analysis.
	-- TODO somehow generic'ise this
	component ca_utf8_nonshortest_form is
		port (
			rst            	:	in 	std_logic;
			clk            	:	in 	std_logic;
			rx_sof         	:	in 	std_logic;
			rx_eof         	:	in 	std_logic;
			rx_data        	:	in 	std_logic_vector(7 downto 0);
			rx_data_valid  	:	in 	std_logic;
			rx_ca_ready    	:	out	std_logic;
			tx_result      	:	out	std_logic;
			tx_result_valid	:	out	std_logic
		);
	end component;

	-- include FIFO component for the results
	component fifo32 is
	generic (
		C_FIFO32_WORD_WIDTH         	:	integer	:= RESULT_WIDTH;
		C_FIFO32_CONTROLSIGNAL_WIDTH	:	integer	:= 8; -- TODO
		C_FIFO32_DEPTH              	:	integer := 4; -- TODO
		CLOG2_FIFO32_DEPTH          	:	integer := 4; -- ceil(log2(depth))
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

	-- When the result is valid, write it to the FIFO.
	-- Note: This assumes that each CA block only set this bit to '1' for one clock cycle. 
	-- If this assumption is not valid anymore, one needs to adapt the following line s.t. only one result bit per packet is written to the FIFO.
	fifo_write_1  <=	result_valid_1;

	-- currently, the header length is assumed to be constant.
	header_length	<=	1;	-- in bytes

	-- the result is std_logic, but the FIFO expects a std_logic_vector.
	fifo_in_1(0)   	<=	result_1;
	queued_result_1	<=	fifo_out_1(0); 

	-- just read FIFOs when they are not empty.
	fifo_read    	<=	tx_fifo_read	and not fifo_empty; 
	tx_fifo_empty	<=	fifo_empty; 



	-- do not check the first n bytes, because they are in the header.
	skipheader_memless : process(	skipheader_state, 
	                             	rx_sof, 
	                             	rx_eof, 
	                             	skipheader_count,
	                             	header_length)
	begin
		case skipheader_state is
		
			when idle =>
				if rx_sof='1' then
					skipheader_next_state  <=	next_header_byte;
				end if ;
				skipheader_next_count	<=	header_length; -- start counter
				check_me             	<=	'0';
		
			when next_header_byte =>
				if (skipheader_count = 0) then -- stop criterion
					skipheader_next_state	<=	next_data_byte;
				elsif (rx_eof='1') then
					skipheader_next_state	<=	idle; 
				end if ;
				skipheader_next_count	<=	skipheader_count-1; -- iteration
				check_me             	<=	'0';

			when next_data_byte =>
				if (rx_eof='1') then
					skipheader_next_state	<=	idle; 
				end if ;
				skipheader_next_count	<=	skipheader_count; 
				check_me             	<=	'1';
		
		end case ;
	end process ; -- skipheader_memless


	skipheader_memzing : process( clk, rst )
	begin
	    if rst = RESET then
			skipheader_count	<= header_length;
			skipheader_state	<= idle;
	    elsif rising_edge(clk) then
			skipheader_count	<= skipheader_next_count;
			skipheader_state	<= skipheader_next_state;
	    end if;
	end process ; -- skipheader_memzing


	-- instantiate all content analysis components
	ca_utf8_nonshortest_form_inst : ca_utf8_nonshortest_form
	port map(
		-- The same signal for all content analysers.
		rst          	=>	rst,
		clk          	=>	clk,
		rx_sof       	=>	rx_sof,
		rx_eof       	=>	rx_eof,
		rx_data      	=>	rx_data,
		rx_data_valid	=>	check_me,
		-- TODO generic'ise me.
		-- Signals specific for each content analyser.
		rx_ca_ready    	=>	ca_ready_1,
		tx_result      	=>	result_1,
		tx_result_valid	=>	result_valid_1
	);




	-- instantiate all result FIFOs.
	result_fifo_1 : fifo32
	--generic map(
	  	-- already defined above, we need the same generics for all FIFOs.
	--	)
	port map(
		Rst         	=> rst, 
		FIFO32_S_Clk	=> clk,
		FIFO32_M_Clk	=> clk,
		-- TODO create generics for all ..._1's.
		FIFO32_S_Data  	=> fifo_out_1, 
		FIFO32_M_Data  	=> fifo_in_1, 
		--FIFO32_S_Fill	=> ,	-- unused, we need full and empty only.
		--FIFO32_M_Rem 	=> ,	-- unused, we need full and empty only.
		FIFO32_S_Full  	=> fifo_full_1, 
		FIFO32_M_Empty 	=> fifo_empty_1, 
		FIFO32_S_Rd    	=> fifo_read, 
		FIFO32_M_Wr    	=> fifo_write_1
	);








	-- aggregate all "Ready" signals. Note: if any of the fifos is full, we are not ready.
	-- TODO create generics for all ..._n's.
	aggregate_ready_signals : process(	--ca_ready_n,	fifo_full_n,
	                                  	ca_ready_1,  	fifo_full_1)
	begin
		rx_packetinspection_ready	<=   	ca_ready_1	and	not fifo_full_1;
		                         	--and	ca_ready_n	and	not fifo_full_n usw.
	end process;



	-- aggregate all FIFO outputs, i.e. fifo empty and good/evil signals
	-- TODO create generics for all ..._n's.
	aggregate_fifo_outputs : process(	--fifo_empty_n,	queued_result_n,
	                                 	fifo_empty_1,  	queued_result_1)
	begin
		-- if any of the FIFOs is empty, set empty signal to 1.
		tx_fifo_empty	<=   	fifo_empty_1;
		             	-- or	fifo_empty_n usw.
		if (EVIL_DROP = '1') then
			-- if any result is set to '1', the result is evil. --> OR.
			tx_result	<=  	result_1; 
			         	--or	result_n usw.
		else -- i.e. EVIL_DROP = '0'
			-- if any result is set to '0', the result is evil. --> AND.
			tx_result	<=   	result_1; 
			         	--and	result_n usw.
		end if; 
	end process;








	-- TODO all the h2s logging stuff.


end architecture;
