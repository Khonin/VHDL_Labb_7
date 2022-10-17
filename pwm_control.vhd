library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
	--use IEEE.math_real.all;

	
entity pwm_control is
	generic(
		max_val			: integer := 196; -- With a 50MHz clock and a bit length of 8. counter max length 196 gives approx. 1KHz update frequency
		val_bits			: integer := 8
	
	);
port(
	-- Inputs
	clk						: in std_logic:='0'; -- 50MHz connected to PLL
	reset_n					: in std_logic:='1'; -- Active low reset
	reset						: in std_logic:='0'; -- Active high reset
	
	-- Serial inpuyts
	serial_on				: in std_logic;
	serial_off				: in std_logic;
	serial_up				: in std_logic;
	serial_down				: in std_logic;
	
	-- Key Inputs
	key_on				: in std_logic;
	key_off				: in std_logic;
	key_up				: in std_logic;
	key_down				: in std_logic;
	
	-- Outputs
	pwm_pulse				: out std_logic; 
	pwm_duty_cycle			: out std_logic_vector((val_bits -1) downto 0);
	pwm_duty_update		: out std_logic
);

end entity pwm_control;


architecture pwm of pwm_control is
signal previous_duty_cycle : std_logic_vector((val_bits-1) downto 0):=std_logic_vector(to_unsigned(0,val_bits));
signal duty_cycle 			: std_logic_vector((val_bits-1) downto 0):=std_logic_vector(to_unsigned(0,val_bits));
signal counter 				: std_logic_vector((val_bits-1) downto 0):=std_logic_vector(to_unsigned(0,val_bits));
begin

input_handler : process(clk,reset,reset_n) 
begin
		-- Async Reset
	if (reset = '1' or reset_n ='0' ) then
		previous_duty_cycle <= std_logic_vector(to_unsigned(196,val_bits));
		duty_cycle <= (others => '0');

	elsif(rising_edge(clk)) then
		-- Key On
		if(key_on = '1') then
		pwm_duty_update <= '1';
			if(to_integer(unsigned(previous_duty_cycle)) < 20) then
				duty_cycle <= std_logic_vector(to_unsigned(20,val_bits));
			else
				duty_cycle <= previous_duty_cycle;
			end if;
			
		-- Key Off
		elsif(key_off = '1') then
			pwm_duty_update <= '1';
			previous_duty_cycle <= duty_cycle;
			duty_cycle <= (others=>'0');
			
		-- Key Up	
		elsif(key_up ='1') then
			pwm_duty_update <= '1';
			if(to_integer(unsigned(duty_cycle)) < 20) then 
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(20,val_bits)); -- Minimum 10%
			elsif(to_integer(unsigned(duty_cycle)) > 194) then
				duty_cycle <= std_logic_vector(to_unsigned(196,val_bits)); -- Maximum 100%
			else
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))+2,val_bits)); -- Increase by 1%
			end if;
		
		-- Key Down
		elsif(key_down ='1') then
			pwm_duty_update <= '1';
			if(to_integer(unsigned(duty_cycle)) < 21 and not (to_integer(unsigned(duty_cycle)) = 0)) then 
				duty_cycle <= std_logic_vector(to_unsigned(20,val_bits)); -- Minimum 10%
			else
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))-2,val_bits)); -- decrease by 1%
			end if;
			
		-- Serial On
		elsif(serial_on = '1') then 
			pwm_duty_update <= '1';
			if(to_integer(unsigned(previous_duty_cycle)) < 20) then
				duty_cycle <= std_logic_vector(to_unsigned(20,val_bits));
			else
				duty_cycle <= previous_duty_cycle;
			end if;
			
		-- Serial Off
		elsif(serial_off = '1') then
			pwm_duty_update <= '1';
			previous_duty_cycle <= duty_cycle;
			duty_cycle <= (others=>'0');
			
		-- Serial Up	
		elsif(serial_up ='1') then
			pwm_duty_update <= '1';
			if(to_integer(unsigned(duty_cycle)) < 20) then 
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(20,val_bits)); -- Minimum 10%
			elsif(to_integer(unsigned(duty_cycle)) > 194) then
				duty_cycle <= std_logic_vector(to_unsigned(196,val_bits)); -- Maximum 100%
			else
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))+2,val_bits)); -- Increase by 1%
			end if;
		
		-- Signal Down
		elsif(serial_down ='1') then
			pwm_duty_update <= '1';
			if(to_integer(unsigned(duty_cycle)) < 21 and not (to_integer(unsigned(duty_cycle)) = 0)) then 
				duty_cycle <= std_logic_vector(to_unsigned(20,val_bits)); -- Minimum 10%
			else
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))-2,val_bits)); -- decrease by 1%
			end if;
		
		-- No button Pressed
		else
			pwm_duty_update <= '0';
			
		end if;
	end if;

end process input_handler;



counter_process : process(clk,reset,reset_n)
begin

	-- Async Reset
	if(reset = '1' or reset_n ='0') then
		counter <= (others =>'0');
		
	
	
	-- Counter
	-- Counts to max_val - 1 and then restarts.
	elsif(rising_edge(clk)) then
		if(to_integer(unsigned(counter)) < (max_val-1)) then
			counter <= std_logic_vector(unsigned(counter) + to_unsigned(1,val_bits)); 
		else
			counter <= std_logic_vector(to_unsigned(0,val_bits));
		end if;
	end if;

end process counter_process;


pwm_control : process(clk,reset,reset_n)
begin	
	-- PWM Output
	-- While counter <= duty_cycle pwm outputs HIGH 
	if(rising_edge(clk)) then
		if(counter < duty_cycle) then
			pwm_pulse <= '1';
		else
			pwm_pulse <= '0';
		end if;
	end if;


end process pwm_control;


end architecture pwm;

