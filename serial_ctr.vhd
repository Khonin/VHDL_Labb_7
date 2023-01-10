library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

-- Shall receive data from the Serial UART component
-- Data received is expected to be ASCII characters
-- 'U' or 'u' -> One clock cycle long pulse shall be generated on the serial_up output	
-- 'D' or 'd' ->  One clock cycle long pulse shall be generated on the serial_down output		
-- '0' -> The serial_off signal shall be pulsed high
-- '1' -> The serial_on signal shall be pulsed high
-- Others -> Shall be ignored

entity serial_ctr is
port(
		serial_on_output   : out std_logic;
		serial_off_output  : out std_logic;
		serial_up_output	 : out std_logic;
		serial_down_output : out std_logic;
		clk					 : in std_logic;
		data					 : in std_logic_vector(7 downto 0);
		data_valid			 : in std_logic:='0'
		);

end entity serial_ctr;

architecture arch of serial_ctr is
	
	signal serial_on   : std_logic;
	signal serial_off  : std_logic;
	signal serial_up	 : std_logic;
	signal serial_down : std_logic;
	--signal clk			 : std_logic;
	signal received_data : natural range 0 to 127;
begin
control: process(clk)
begin
	if rising_edge(clk) then
		if(data_valid = '1') then
			received_data <= to_integer(unsigned(data));		
			case received_data is
				when 68 => --D
					time_counter <= 1;
					serial_down <= '1';
				when 100 => --d
					time_counter <= 1;
					serial_down <= '1';
				when 85 => --U
					time_counter <= 1;
					serial_up <= '1';
				when 117 => --u
					time_counter <= 1;
					serial_up <= '1';
				when 48 => --0
					time_counter <= 1;
					serial_off <= '1';
				when 49 => --1
					time_counter <= 1;
					serial_on <= '1';
				when others =>
					serial_down <= '0';
					serial_up <= '0';
					serial_off <= '0';
					serial_on <= '0';
			end case;
		end if;
		serial_on_output <= serial_on;
		serial_off_output <= serial_off;
		serial_up_output <= serial_up;
		serial_down_output <= serial_down;
	end if;
	
end process;

end architecture arch;