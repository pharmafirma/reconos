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
  		rst            	:	in 	std_logic;
  		clk            	:	in 	std_logic;
  		rx_sof         	:	in 	std_logic;
  		rx_eof         	:	in 	std_logic;
  		rx_data        	:	in 	std_logic_vector(7 downto 0);
  		rx_data_valid  	:	in 	std_logic;
  		rx_ca_ready    	:	out	std_logic;
  		--result_good  	:	out	std_logic;
  		--result_evil  	:	out	std_logic;
  		tx_result      	:	out	std_logic;
  		tx_result_valid	:	out	std_logic
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
	type    	detector_state	is(	-- TODO description of the states.
	        	              	   	unknown_idle, -- Note that we don't need an explicit id le state since it has the same meaning as the not yet known state.
	        	              	   	good,
	        	              	   	evil,
	        	              	   	evil_wait, -- evil bit was already sent, 
	        	              	   	examine_2nd_byte_3, -- for 3-byte chars.
	        	              	   	examine_2nd_byte_4) -- for 4-byte chars.
	signal  	state         	:  	detector_state; -- we only have one FSM in this entity, so this name is unambigous.
	signal  	next_state    	:  	detector_state;
	constant	SAFE_STATE    	:  	detector_state := evil; -- What to do when EOF arrives while analysing a multibyte character.



	-- This entity is the innermost, it has no components.




--				########   ########   ######    ####  ##    ## 
--				##     ##  ##        ##    ##    ##   ###   ## 
--				##     ##  ##        ##          ##   ####  ## 
--				########   ######    ##   ####   ##   ## ## ## 
--				##     ##  ##        ##    ##    ##   ##  #### 
--				##     ##  ##        ##    ##    ##   ##   ### 
--				########   ########   ######    ####  ##    ## 
begin



	memzing : process( clk, rst )
	begin
	    if rst = RESET then
			state	<=	unknown_idle;
	    elsif rising_edge(clk) then
			state	<=	next_state; 
	    end if;
	end process ; -- memzing


	memless : process( -- TODO )
	begin
		tx_result_valid <= '0';
		if rx_data_valid then
			case state is

			-- search for multi-byte characters which could have been represented using a shorter form.
			-- 
			-- # bytes	max. #bits	binary representation
			-- 1      	 7 bit    	0xxx xxxx
			--        	          	
			-- 2      	11 bit    	110x xxxx   10xx xxxx
			--        	          	        ^ 7th x-bit
			-- 3      	16 bit    	1110 xxxx   10xx xxxx   10xx xxxx
			--        	          	               ^ 11th x-bit
			-- 4      	21 bit    	1111 0xxx   10xx xxxx   10xx xxxx   10xx xxxx
			--        	          	                 ^ 16th x-bit
			--
			-- If there are only 0's in the x-bite before the bit marked with ^, the character could have been represented using a shorter representation. 
			-- i.e. it is evil  }:-)
			-- If not, it is good O:-)
			-- 
			-- as one can see, only the first 2 bytes are necessary to decide wether the packet is evil or not.
			
			
				when unknown_idle =>
					-- not known means "nothing evil found so far". 
					-- i.e. when EOF arrives: jump to "good"
					if rx_eof  then
						next_state	<=	good;
					end if ;

					-- Bytes which contain 7-bit ASCII characters "0xxx xxxx" are valid O:-)
					-- Latter bytes of a multibyte character "10xx xxxx" can be ignored since the first bytes have already been checked.
					if (rx_data(7) = '0' or rx_data(7 downto 6) = "10") then
						next_state	<=	unknown_idle; 
					end if ;

					-- Look for the first byte of a 2-byte character: "110x xxxx"
					if (rx_data(7 downto 5) = "110") then
						if (rx_data(4 downto 1) = "0000" )  then
							-- 7-bit character represented with 2 bytes instead of 1 }:-)
							next_state	<=	evil;
						else
							-- a regular 2-byte character O:-)
							next_state	<=	unknown_idle; 
						end if ;
					end if ;

					-- Look for the first byte of a 3-byte character: "1110 xxxx"
					if (rx_data(7 downto 4) = "1110") then
						if (rx_data(3 downto 0 = "0000")) then
							-- character can be up to 12 bits long, need to check the second byte.
							next_state	<=	examine_2nd_byte_3; 
						else
							-- 13 bit or longer, i.e. this is a regular 3-byte character O:-)
							next_state	<=	unknown_idle; 
						end if ;
								
					end if ;

					-- Look for the first byte of a 4-byte character: "1111 0xxx"
					if (rx_data(7 downto 3) = "11110") then
						if (rx_data(2 downto 0 = "000")) then
							-- character can be up to 18 bit long, need to check the second byte.
							next_state	<=	examine_2nd_byte_3; 
						else
							-- 19 bit or longer, i.e. this is a regular 4-byte character O:-)
							next_state	<=	unknown_idle; 
						end if ;
					end if ;
								

				when examine_2nd_byte_3 =>
					-- examine the 2nd byte of a 3-byte character
					if (rx_data(7 downto 5 = "100")) then
						-- 11 bit character represented with 3 bytes instead of 2 }:-)
						next_state	<=	evil;
					else
						-- regular 3-byte character
						next_state	<=	unknown_idle; 
					end if ;


				when examine_2nd_byte_4 =>
					-- examine the 2nd byte of a 3-byte character
					if (rx_data(7 downto 4 = "1000")) then
						-- 16 bit character represented with 4 bytes instead of 3 }:-)
						next_state	<=	evil;
					else
						-- regular 4-byte character
						next_state	<=	unknown_idle; 
					end if ;


				when evil_wait =>
					-- just wait for EOF.

					if rx_eof then
						next_state	<=	unknown_idle; 
					else
						next_state	<=	evil_wait; 
					end if ;
				
			end case; -- state
		else
			-- Do not change state as long as the data received are not valid.
			next_state	<=	state; 
		end if ; -- rx_data_valid

		-- The following two states are not part of the above if-statement because:
			-- They forward the result of the content analysis to the next upper entity.
			-- Only one result bit per packet is allowed in the result FIFOs. 
			-- So, they have to be left after exactly one clock cycle.
		case state is
			when good =>
				-- give out good signal
				result         	<=	GOOD_FORWARD;
				tx_result_valid	<=	'1';
				-- directly jump back to default state.
				-- EOF has already arrived i.e. we don't need any good_wait state.
				next_state	<=	unknown_idle; 


			when evil =>
				-- send evil signal. 
				result         	<=	EVIL_DROP;
				tx_result_valid	<=	'1';

				
				if rx_eof then
					next_state	<=	unknown_idle; 
				else
					-- wait if EOF has not arrived yet. 
					next_state	<=	evil_wait; 
				end if ;

		end case; -- state
	end process ; -- memless



	-- TODO all the h2s logging stuff.


end architecture;
