--use std.textio.all;
library ieee;
--use ieee.std_logic_textio.all;  -- read and write overloaded for std_logic
use ieee.std_logic_1164.all;


entity ips_tb is
	-- a testbench does not connect to any higher-level hierarchy.
end entity ips_tb;


architecture RTL of ips_tb is
	
	--      	data & control signals:	
	signal  	rx_ll_sof              	: std_logic;
	signal  	rx_ll_eof              	: std_logic;
	signal  	rx_ll_data             	: std_logic_vector(7 downto 0);
	signal  	rx_ll_src_rdy          	: std_logic;
	signal  	rx_ll_dst_rdy          	: std_logic;
	signal  	tx_ll_sof              	: std_logic;
	signal  	tx_ll_eof              	: std_logic;
	signal  	tx_ll_data             	: std_logic_vector(7 downto 0);
	signal  	tx_ll_src_rdy          	: std_logic;
	signal  	tx_ll_dst_rdy          	: std_logic;
	--      	packets (stimuli):     	
	signal  	packet_len             	: integer	range 0 to 1500;
	signal  	cur_len                	: integer	range 0 to 1500;
	signal  	cur_len_next           	: integer	range 0 to 1500;
	type    	packet_state_t         	is( P_STATE_SEND, P_STATE_INIT );
	signal  	packet_state           	: packet_state_t;
	signal  	packet_state_next      	: packet_state_t;
	type    	packet_payload_type    	is array(0 to 1500)	of std_logic_vector(7 downto 0);
	signal  	packet_tx_payload      	: packet_payload_type;
	--      	clock and reset:       	
	signal  	clk                    	: std_logic;
	signal  	rst                    	: std_logic;
	constant	RESET                  	: std_logic := '1';

	
	-- the TB has only one component, which ist the entity to be tested (model under test, MUT):
	component ips is
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
	end component;
	

begin

	packet_len  <= 64; -- constant for the moment
	rx_ll_dst_rdy  <= '1';


	-- FSM which generates packets. 


	packet_tx_payload <= (	-- Payload    	SOF 	EOF
	                      	--("01100001",	"1",	"0")
	                      	x"FC", 
	                      	"00001101",
	                      	"00000101",
	                      	"00101101",
	                      	"00101101",
	                      	"00001101",
	                      	"11111111",
	                      	others => "00000000"
	);





	packets : process(packet_state, packet_len, cur_len, tx_ll_dst_rdy) is
	-- update packet contents
	begin
		tx_ll_sof        	<= '0'; 
		tx_ll_eof        	<= '0';
		tx_ll_src_rdy    	<= '1';
		tx_ll_data       	<= packet_tx_payload(cur_len);
		cur_len_next     	<= cur_len;
		packet_state_next	<= packet_state;
		case packet_state is
		when P_STATE_INIT  => 
			tx_ll_sof	<= '1';
			if tx_ll_dst_rdy = '1' then
				packet_state_next	<= P_STATE_SEND;
				cur_len_next     	<= 1;
			end if;
		when P_STATE_SEND  => 
			if cur_len = packet_len then
				tx_ll_eof        	<= '1';
				packet_state_next	<= P_STATE_INIT;
			end if;
			if tx_ll_dst_rdy = '1' then
				cur_len_next        	<= cur_len + 1;
				-- packet_state_next	<= P_STATE_SEND; -- implicitely given.
			end if;
		end case;
	end process;


	rst  <= '1', '0' after 1 ms;

	clk_process :process
	-- the Clock: 100kHz
	begin
		clk <= '1';	wait for 5 us;
		clk <= '0';	wait for 5 us;
	end process;

	memzing: process(clk, rst) is
	-- FSM state transition
	begin
	    if rst = RESET then
			cur_len     	<= 0;
			packet_state	<= P_STATE_INIT;
	    elsif rising_edge(clk) then
			cur_len     	<= cur_len_next;
			packet_state	<= packet_state_next;
	    end if;
	end process;

	-- instatiate 1 ips component
	ips_inst : ips 
	port map(
		rst                    	=>	rst,
		clk                    	=>	clk,
		-- what the TB sends...	is what the MUT reveives
		tx_ll_sof              	=>	rx_ll_sof,
		tx_ll_eof              	=>	rx_ll_eof,
		tx_ll_data             	=>	rx_ll_data,
		tx_ll_src_rdy          	=>	rx_ll_src_rdy,
		tx_ll_dst_rdy          	=>	rx_ll_dst_rdy,
		-- ...and vice-versa.  	
		rx_ll_sof              	=>	tx_ll_sof,
		rx_ll_eof              	=>	tx_ll_eof,
		rx_ll_data             	=>	tx_ll_data,
		rx_ll_src_rdy          	=>	tx_ll_src_rdy,
		rx_ll_dst_rdy          	=>	tx_ll_dst_rdy
	);

end architecture RTL;
