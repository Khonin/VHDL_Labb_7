library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
	--use IEEE.math_real.all;

	
entity pwm_control is
	generic(
		max_val 			: integer := 50000; -- with a 50MHz clock counting to 50 000 should take 1ms which should grant a 1 KHz update frequency
		val_bits			: integer := 8;
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
	key_on					: in std_logic;
	key_off					: in std_logic;
	key_up					: in std_logic;
	key_down				: in std_logic;
	
	-- Outputs
	pwm_pulse				: out std_logic; 
	pwm_duty_cycle_percent	: out std_logic_vector((val_bits-1) downto 0);
	pwm_duty_update			: out std_logic;
	ledg					: out std_logic
);

end entity pwm_control;


architecture pwm of pwm_control is
signal previous_duty_cycle_percent 	: integer range 0 to 100:=0;
signal counter 						: integer range 0 to max_val:=0;
signal duty_cycle_percent			: integer range 0 to 100:=0;
signal duty_changed					: boolean := true;
begin

input_handler : process(clk,reset,reset_n) 
begin
	-- Async Reset
	if (reset = '1' or reset_n ='0' ) then
		previous_duty_cycle_percent 		<=  100;
		duty_cycle_percent 					<= 0;
		pwm_duty_update 						<= '1';

	
	elsif (rising_edge(clk)) then
	pwm_duty_update 				<= '0';
		-- Key On
		if(key_on = '1') then
			
			if(duty_cycle_percent > 10) then -- If already on ignore key press
				duty_cycle_percent <= duty_cycle_percent;
			else
				duty_cycle_percent 				<= previous_duty_cycle_percent;
				duty_changed <= true;
			end if;
		
			-- Key Off
		elsif(key_off = '1') then
			
			if(duty_cycle_percent /= 0) then
				previous_duty_cycle_percent 	<= duty_cycle_percent;
				duty_changed <= true;
			end if;
			duty_cycle_percent 				<= 0;
			
			-- Key Up	
		elsif(key_up ='1') then
			
			if(duty_cycle_percent < 10) then -- Minimum 10%
				duty_cycle_percent 			<= 10;
				duty_changed <= true;
			elsif(duty_cycle_percent < 100) then -- Maximum 100%
				duty_cycle_percent 			<= duty_cycle_percent + 1; -- Increase by 1%
				duty_changed <= true;
			end if;
		
			-- Key Down
		elsif(key_down ='1') then
			
			if(duty_cycle_percent > 10) then -- Minimum 10% | if 0 disregard input
				duty_cycle_percent 			<= duty_cycle_percent -1; -- Decrease by 1%
				duty_changed <= true;
			end if;
			
			-- Serial On
		elsif(serial_on = '1') then 
			
			if(duty_cycle_percent > 10) then -- If already on ignore key press
				duty_cycle_percent <= duty_cycle_percent;
			else
				duty_cycle_percent 				<= previous_duty_cycle_percent;
				duty_changed <= true;
			end if;
				
			
			-- Serial Off
		elsif(serial_off = '1') then
			
			if(duty_cycle_percent /= 0) then
				previous_duty_cycle_percent 	<= duty_cycle_percent;
				duty_changed <= true;
			end if;
			duty_cycle_percent 				<= 0;
				
			-- Serial Up	
		elsif(serial_up ='1') then
			
			if(duty_cycle_percent < 10) then -- Minimum 10%
				duty_cycle_percent 			<= 10;
				duty_changed <= true;
			elsif(duty_cycle_percent < 100) then -- Maximum 100%
				duty_cycle_percent 			<= duty_cycle_percent + 1; -- Increase by 1%
				duty_changed <= true;
			end if;
			
			-- Signal Down
		elsif(serial_down ='1') then
			
			if(duty_cycle_percent > 10) then -- Minimum 10% | if 0 disregard input
				duty_cycle_percent 			<= duty_cycle_percent -1; -- Decrease by 1%
				duty_changed <= true;
			end if;			
		end if;
		
		-- Update PWM duty cycle
		if(duty_changed) then
			pwm_duty_cycle_percent 		<= std_logic_vector(to_unsigned(duty_cycle_percent,val_bits));
			pwm_duty_update 				<= '1';
		end if;
	end if;

end process input_handler;

pwm_pulse <= '1' when counter < duty_cycle_percent*one_perc_val else '0';
ledg <= '1' when counter < duty_cycle_percent*one_perc_val else '0';

counter_process : process(clk,reset,reset_n)
begin

	-- Async Reset
	if(reset = '1' or reset_n ='0') then
		counter 	<= 0;
	
	-- Counter
	-- Counts to max_val - 1 and then restarts.
	elsif(rising_edge(clk)) then
		if(counter < (max_val-1)) then
			counter <= counter + 1; 
		else
			counter <= 0;
		end if;
	end if;
end process counter_process;



end architecture pwm;

