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









entity ca_utf8_nonshortest_form is
--	generic (
--		destination	: std_logic_vector(5 downto 0);
--		sender     		: std_logic
--	);
  	port (
  		rst                     	:	in 	std_logic;
  		clk                     	:	in 	std_logic;
  		rx_sof                  	:	in 	std_logic;
  		rx_eof                  	:	in 	std_logic;
  		rx_data                 	:	in 	std_logic_vector(7 downto 0);
  		rx_data_valid           	:	in 	std_logic;
  		rx_contentanalysis_ready	:	out	std_logic;
  		--result_good           	:	out	std_logic;
  		--result_evil           	:	out	std_logic;
  		tx_result               	:	out	std_logic;
  		tx_result_valid         	:	out	std_logic
  	);

end ca_utf8_nonshortest_form;

--------------------------------------------------------------

architecture implementation of ca_utf8_nonshortest_form is


	-- some constants
	constant	RESET       	:	std_logic	:= '1'; -- define if rst is active low or active high
	constant	GOOD_FORWARD	:	std_logic	:= '1'; -- used constants instead of a "type" to simplify queuing.
	constant	EVIL_DROP   	:	std_logic	:= '0';
























	--			 ######   ####   ######    ##    ##     ###     ## 
	--			##    ##   ##   ##    ##   ###   ##    ## ##    ##
	--			##         ##   ##         ####  ##   ##   ##   ## 
	--			 ######    ##   ##   ####  ## ## ##  ##     ##  ## 
	--			      ##   ##   ##    ##   ##  ####  #########  ## 
	--			##    ##   ##   ##    ##   ##   ###  ##     ##  ## 
	--			 ######   ####   ######    ##    ##  ##     ##  ######## 
	-- signal declarations




	-- This entity is the innermost, it has no components.




--				########   ########   ######    ####  ##    ## 
--				##     ##  ##        ##    ##    ##   ###   ## 
--				##     ##  ##        ##          ##   ####  ## 
--				########   ######    ##   ####   ##   ## ## ## 
--				##     ##  ##        ##    ##    ##   ##  #### 
--				##     ##  ##        ##    ##    ##   ##   ### 
--				########   ########   ######    ####  ##    ## 
begin



	-- TODO the FSM







	-- TODO all the h2s logging stuff.


end architecture;
