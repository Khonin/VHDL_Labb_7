library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
	--use IEEE.math_real.all;

	
entity pwm_control is
	generic(
		max_val 			: integer := 50000; -- with a 50MHz clock counting to 50 000 should take 1ms which should grant a 1 KHz update frequency
		val_bits			: integer := 16;
		ten_perc_val 	: integer := 5000;
		one_perc_val	: integer := 500
	
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
	pwm_duty_cycle			: out std_logic_vector(7 downto 0);
	pwm_duty_update		: out std_logic;
	ledg						: out std_logic
);

end entity pwm_control;


architecture pwm of pwm_control is
signal previous_duty_cycle : std_logic_vector((val_bits-1) downto 0):=std_logic_vector(to_unsigned(0,val_bits));
signal duty_cycle 			: std_logic_vector((val_bits-1) downto 0):=std_logic_vector(to_unsigned(0,val_bits));
signal counter 				: std_logic_vector((val_bits-1) downto 0):=std_logic_vector(to_unsigned(0,val_bits));
signal duty_cycle_percent	: integer range 0 to 100:=0;
begin

input_handler : process(clk,reset,reset_n) 
begin
		-- Async Reset
	if (reset = '1' or reset_n ='0' ) then
		previous_duty_cycle <= std_logic_vector(to_unsigned(max_val,val_bits));
		duty_cycle <= (others => '0');
		duty_cycle_percent <= 0;

	elsif(rising_edge(clk)) then
		-- Key On
		if(key_on = '1') then
			pwm_duty_update <= '1';
			if(to_integer(unsigned(previous_duty_cycle)) < ten_perc_val) then
				duty_cycle <= std_logic_vector(to_unsigned(ten_perc_val,val_bits));
				duty_cycle_percent <= 10;
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
			if(to_integer(unsigned(duty_cycle)) < ten_perc_val) then 
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(ten_perc_val,val_bits)); -- Minimum 10%
			elsif(to_integer(unsigned(duty_cycle)) > max_val-1) then
				duty_cycle <= std_logic_vector(to_unsigned(max_val,val_bits)); -- Maximum 100%
			else
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))+one_perc_val,val_bits)); -- Increase by 1%
			end if;
		
		-- Key Down
		elsif(key_down ='1') then
			pwm_duty_update <= '1';
			if(to_integer(unsigned(duty_cycle)) < ten_perc_val+1 and not (to_integer(unsigned(duty_cycle)) = 0)) then 
				duty_cycle <= std_logic_vector(to_unsigned(ten_perc_val,val_bits)); -- Minimum 10%
			else
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))-one_perc_val,val_bits)); -- decrease by 1%
			end if;
			
		-- Serial On
		elsif(serial_on = '1') then 
			pwm_duty_update <= '1';
			if(to_integer(unsigned(previous_duty_cycle)) < ten_perc_val) then
				duty_cycle <= std_logic_vector(to_unsigned(ten_perc_val,val_bits));
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
			if(to_integer(unsigned(duty_cycle)) < ten_perc_val) then -- Minimum 10% if below set to 10%
				pwm_duty_update <= '1';
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(ten_perc_val,val_bits)); 
			elsif(to_integer(unsigned(duty_cycle)) < max_val) then -- if less than max, increase by 1%
				pwm_duty_update <= '1';
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))+one_perc_val,val_bits)); -- Increase by 1%
			end if;
		
		-- Signal Down
		elsif(serial_down ='1') then
			if(to_integer(unsigned(duty_cycle)) > ten_perc_val AND (to_integer(unsigned(duty_cycle)) /= 0)) then -- Minimum 10% if at 0 down has no effect
				pwm_duty_update <= '1';
				previous_duty_cycle <= duty_cycle;
				duty_cycle <= std_logic_vector(to_unsigned(to_integer(unsigned(duty_cycle))-one_perc_val,val_bits)); -- decrease by 1%
			end if;
		
		-- No button Pressed
		else
			pwm_duty_update <= '0';
		end if;
		-- Update PWM output signal
		if(to_integer(unsigned(duty_cycle))>ten_perc_val-1) then 
			pwm_duty_cycle <= std_logic_vector(to_unsigned((to_integer(unsigned(duty_cycle))one_perc_val),8)); -- Divide duty cycle by 1% number to get perc
		else
			pwm_duty_cycle <= std_logic_vector(to_unsigned(0,8));
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
		if(counter > duty_cycle) then
			pwm_pulse <= '0';
			ledg <= '0';
		else
			pwm_pulse <= '1';
			ledg <= '1';
		end if;
	end if;


end process pwm_control;


end architecture pwm;

