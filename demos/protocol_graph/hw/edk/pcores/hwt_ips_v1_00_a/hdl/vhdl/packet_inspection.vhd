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
		tx_fifo_empty            	:	out	std_logic
	);
end packet_inspection;

--------------------------------------------------------------

architecture implementation of packet_inspection is


	-- some constants
	constant	RESET       	:	std_logic	:= '1'; -- define if rst is active low or active high
	constant	GOOD_FORWARD	:	std_logic	:= '1'; -- used constants instead of a "type" to simplify queuing.
	constant	EVIL_DROP   	:	std_logic	:= '0';
	constant	RESULT_WIDTH	:	integer  	:= 1; -- in bits (good / evil).





	--			 ######  ####  ######   ##    ##    ###    ## 
	--			##    ##  ##  ##    ##  ###   ##   ## ##   ##
	--			##        ##  ##        ####  ##  ##   ##  ## 
	--			 ######   ##  ##   #### ## ## ## ##     ## ## 
	--			      ##  ##  ##    ##  ##  #### ######### ## 
	--			##    ##  ##  ##    ##  ##   ### ##     ## ## 
	--			 ######  ####  ######   ##    ## ##     ## ######## 
	-- signal declarations



	-- currently, the header length is assumed to be constant. 
	signal	header_length	:	integer	:= '1'; -- in bytes
	signal	check_me     	:	std_logic; -- "data_valid" signal for the content analyser blocks
	-- to be "generic'ised" one day...
	signal	ca_ready_1            	:	std_logic; 
	signal	result_to_fifo_1      	:	std_logic; 
	signal	result_to_fifo_valid_1	:	std_logic; 
	signal	fifo_to_output_1      	:	std_logic; 
	signal	fifo_to_output_empty_1	:	std_logic;
	signal	fifo_to_output_read_1 	:	std_logic;
	signal	fifo_full_1           	:	std_logic;





	-- include components


	-- TODO include one component for each content analysis.




	-- include FIFO component for the results
	component fifo32 is
	generic (
		C_FIFO32_WORD_WIDTH     	:	integer	:= RESULT_WIDTH;
		C_FIFO32_DEPTH          	:	integer := 4; -- TODO
		CLOG2_FIFO32_DEPTH      	:	integer := 4; -- ceil(log2(depth))
		C_FIFO32_SAFE_READ_WRITE	:	boolean	:= true
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


	-- TODO: Ignore header (counter).








	-- TODO instantiate all content analysis components






	-- instantiate all result FIFOs.
	-- TODO create generics for all ..._1's.
	result_fifo_1 : fifo32
	--generic map(
	  	-- already defined above, we need the same generics for all FIFOs.
	--	)
	port map(
		Rst            	=> rst, 
		FIFO32_S_Clk   	=> clk,
		FIFO32_M_Clk   	=> clk,
		FIFO32_S_Data  	=> fifo_to_output_1,	-- packet vector, i.e. data / SOF / EOF
		FIFO32_M_Data  	=> result_to_fifo_1, 
		--FIFO32_S_Fill	=> ,	-- unused, we need full and empty only.
		--FIFO32_M_Rem 	=> ,	-- unused, we need full and empty only.
		FIFO32_S_Full  	=> fifo_full_1, 
		FIFO32_M_Empty 	=> fifo_to_output_empty_1, 
		FIFO32_S_Rd    	=> fifo_to_output_read_1, 
		FIFO32_M_Wr    	=> result_to_fifo_valid_1
	);








	-- TODO: aggregate all "Ready" signals
		-- TODO note: if any of the fifos is full, we are not ready.


	-- TODO: aggregate all FIFO outputs, i.e.
		-- fifo empty
		-- good/evil






	-- TODO all the h2s logging stuff.


end architecture;
