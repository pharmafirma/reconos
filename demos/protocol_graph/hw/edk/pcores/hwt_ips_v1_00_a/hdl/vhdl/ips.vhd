library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

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

	signal  	test	:	std_logic	:= '0'; 
	constant	RESET : std_logic := '1';

begin
  	
  	test         	<=                                 	not rx_ll_src_rdy;
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
  	
end architecture;
