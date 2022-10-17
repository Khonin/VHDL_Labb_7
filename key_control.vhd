library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
	--use IEEE.math_real.all;

entity key_control is
	port(
	--Input
	clk				: in std_logic:='0';
	key_pressed		: in std_logic_vector(3 downto 0):="1111"; -- Active low push buttons
	-- Output
	key_signal_on		: out std_logic;
	key_signal_off		: out std_logic;
	key_signal_up		: out std_logic;
	key_signal_down	: out std_logic
	
	);

end entity;

architecture key_controller of key_control is
signal key_pressed_r : std_logic_vector(3 downto 0);
signal key_pressed_2r : std_logic_vector(3 downto 0);
signal time_counter : integer range 1 to 500000:=500000;
begin
	double_sync:process(clk)
	begin
	if(rising_edge(clk)) then
		key_pressed_r <= key_pressed;
		key_pressed_2r <= key_pressed_r;
	end if;
	end process;
	
	process(clk)
	begin
		if(rising_edge(clk)) then
		-- count up to 500000 clock pulses = 10ms after each button press
		if( time_counter = 500000) then
			case key_pressed_2r is
				when "0111" =>
					time_counter <= 1;
					key_signal_off <= '1';
					key_signal_up <= '0';
					key_signal_down <= '0';
					key_signal_on <= '0';
				when "1011" =>
					time_counter <= 1;
					key_signal_on <= '1';
					key_signal_up <= '0';
					key_signal_down <= '0';
					key_signal_off <= '0';
				when "1101" =>
					time_counter <= 1;
					key_signal_down <= '1';
					key_signal_up <= '0';
					key_signal_on <= '0';
					key_signal_off <= '0';
				when "1110" =>
					time_counter <= 1;
					key_signal_up <= '1';
					key_signal_down <= '0';
					key_signal_on <= '0';
					key_signal_off <= '0';
				when others =>
					key_signal_up <= '0';
					key_signal_down <= '0';
					key_signal_on <= '0';
					key_signal_off <= '0';
			end case;
			else 
					key_signal_up <= '0';
					key_signal_down <= '0';
					key_signal_on <= '0';
					key_signal_off <= '0';
					time_counter <= time_counter + 1;
			end if;
		end if;
	end process;
end architecture;