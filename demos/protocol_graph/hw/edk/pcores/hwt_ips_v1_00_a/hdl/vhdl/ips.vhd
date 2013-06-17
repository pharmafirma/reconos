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
  		rst          	:	in 	std_logic;
  		clk          	:	in 	std_logic;
  		rx_ll_sof    	:	in 	std_logic;
  		rx_ll_eof    	:	in 	std_logic;
  		rx_ll_data   	:	in 	std_logic_vector(7 downto 0);
  		rx_ll_src_rdy	:	in 	std_logic;
  		rx_ll_dst_rdy	:	out	std_logic;	
  		tx_ll_sof    	:	out	std_logic;
  		tx_ll_eof    	:	out	std_logic;
  		tx_ll_data   	:	out	std_logic_vector(7 downto 0);
  		tx_ll_src_rdy	:	out	std_logic;
  		tx_ll_dst_rdy	:	in 	std_logic
  	);

end ips;

--------------------------------------------------------------

architecture implementation of ips is

--	signal  	test      	:	std_logic	:= '0'; 
  	signal  	fifo_full 	:	std_logic	:= '1';
  	signal  	fifo_empty	:	std_logic	:= '1';
  	signal  	data_valid	:	std_logic	:= '1'; -- FIXME: hardcoded for the moment
  	constant	RESET     	:	std_logic	:= '1';


	-- include components

	component fifo32 is
	generic (
		C_FIFO32_WORD_WIDTH       	:	integer	:= 8;
		C_FIFO32_DATA_SIGNAL_WIDTH	:	integer	:= 16;
		C_FIFO32_DEPTH            	:	integer := 16
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





begin
  	
--	test         	<=                                 	not rx_ll_src_rdy;
  	rx_ll_dst_rdy	<= '0' when rst = RESET else       	'1';
  	tx_ll_sof    	<= '0' when rst = RESET else       	rx_ll_sof;
  	tx_ll_eof    	<= '0' when rst = RESET else       	rx_ll_eof;
  	tx_ll_data   	<= "00000000" when rst = RESET else	rx_ll_data;
  	tx_ll_src_rdy	<= '0' when rst = RESET else       	'1';
--	rx_ll_dst_rdy	<= '0' when rst = '1' else         	'1';
--	tx_ll_sof    	<= '0' when rst = '1' else         	rx_ll_sof;
--	tx_ll_eof    	<= '0' when rst = '1' else         	rx_ll_eof;
--	tx_ll_data   	<= "00000000" when rst = '1' else  	rx_ll_data;
--	tx_ll_src_rdy	<= '0' when rst = '1' else         	'1';


	-- instatiate 1 fifo component
	fifo_inst : fifo32
	port map(
		Rst            	=> rst, 
		FIFO32_S_Clk   	=> clk,
		FIFO32_M_Clk   	=> clk,
		FIFO32_S_Data  	=> tx_ll_data,
		FIFO32_M_Data  	=> rx_ll_data,
		--FIFO32_S_Fill	=> ; -- unused, we need full and empty only.
		--FIFO32_M_Rem 	=> ; -- unused, we need full and empty only.
		FIFO32_S_Full  	=> fifo_full, 
		FIFO32_M_Empty 	=> fifo_empty, 
		FIFO32_S_Rd    	=> '1',
		FIFO32_M_Wr    	=> data_valid
	);


end architecture;
