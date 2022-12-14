library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
	--use IEEE.math_real.all;
	
	
entity top_level is
generic(	

g_simulation	: boolean :=true;
max_val 		: integer := 50000;
val_bits 		: integer := 8
);


port(
	-- Inputs 
	clk_50					: in std_logic:='0'; -- 50MHz connected to PLL

	
	-- Outputs 
	ledr						: out std_logic_vector(9 downto 0);
	ledg 						: out std_logic_vector(7 downto 0);
	
	
		-- Signals to Key_control
	key_n 			: in std_logic_vector(3 downto 0):="0000";

	
	
	-- Signals for PWM controller
	pwm_pulse_top 				: out std_logic;



	-- Signals for Serial UART
	uart_rx					: in std_logic:='0';
	uart_tx					: out std_logic;
	
	
	
		-- Signals to 7seg Display
	seg_ready				: out std_logic:='0';
	hex0						: out std_logic_vector(6 downto 0);
	hex1						: out std_logic_vector(6 downto 0);
	hex2						: out std_logic_vector(6 downto 0)

	
);


end entity top_level;


architecture top_level_rtl of top_level is
	signal key_off_out 			:  std_logic;
	signal key_on_out 			:  std_logic;
	signal key_down_out 			:  std_logic;
	signal key_up_out 			:  std_logic;
	signal uart_received_data	:  std_logic_vector(7 downto 0):="00000000";
	signal uart_received_valid	:  std_logic;
	signal uart_transmit_data	:  std_logic_vector(7 downto 0):="00000000";
	signal uart_transmit_valid	:  std_logic;
   signal uart_transmit_ready :  std_logic;

	
			-- Singals for serial Controller
	signal serial_on_out   	: std_logic;
	signal serial_off_out  	:  std_logic;
	signal serial_up_out	 	:  std_logic;
	signal serial_down_out 	:  std_logic;
	
	-- Reset controll signal
	signal reset						:  std_logic:='0'; -- Active high reset
	signal reset_n 					:  std_logic:='1'; -- Active Low reset
	
	
		-- Signals for PLL component
	signal pll_clock_50	:  STD_LOGIC;
	signal pll_locked		:  STD_LOGIC; 
	
	signal pwm_duty_cycle_top		: std_logic_vector((val_bits-1) downto 0):="00000000";
	signal pwm_duty_update_top		: std_logic:='0';
	
begin
	-- generate pll

   ledr(9 downto 1)     <= (others => '0');
   ledg(7 downto 1)     <= (others => '0');
	
	-- Instance of PLL
   b_gen_pll : if (not g_simulation) generate
   
      i_altera_pll : entity work.altera_pll
      port map(
         areset		=> '0',        -- Reset towards PLL is inactive
         inclk0		=> clk_50,   -- 50 MHz input clock
         c0		      => open,       -- 25 MHz output clock unused
         c1		      => pll_clock_50,     -- 50 MHz output clock
         c2		      => open,       -- 100 MHz output clock unused
         locked		=> pll_locked );-- PLL Locked output signal

      i_reset_ctrl : entity work.reset_ctrl
      generic map(
         g_reset_hold_clk  => 127)
      port map(
         clk         => clk_50,
         reset_in    => '0',
         reset_in_n  => pll_locked, -- reset active if PLL is not locked

         reset_out   => reset,
         reset_out_n => open);
   end generate;

   b_sim_clock_gen : if g_simulation generate
      pll_clock_50   <= clk_50;
      p_internal_reset : process
      begin
         reset    <= '1';
         wait until clk_50 = '1';
         wait for 1 us;
         wait until clk_50 = '1';
         reset    <= '0';
         wait;
      end process p_internal_reset;
   end generate;

		--

-- Components	
	-- Key Controller
	
	i_key_controller 		:entity work.key_control
port map(
		--Inputs
	clk => pll_clock_50,
	key_pressed	=> key_n,
	
		-- Outputs
	key_signal_off => key_off_out,
	key_signal_on 	=> key_on_out,
	key_signal_down => key_down_out,
	key_signal_up 	=> key_up_out
	
);




	-- Serial Controller
i_serial_controller 	:entity work.serial_ctr
port map(
	serial_on_output  	=> serial_on_out,
	serial_off_output 	=> serial_off_out,
	serial_up_output	 	=> serial_up_out,
	serial_down_output	=> serial_down_out,
	clk					 	=> pll_clock_50,
	data 						=> uart_received_data,
	data_valid 				=> uart_received_valid
);
		--
		
		
 -- Serial UART
i_uart_controller  	: entity work.serial_uart
generic map (
	g_reset_active_state => '1',
	g_serial_speed_bps	=> 115200,
	g_clk_period_ns		=> 20,
	g_parity					=> 0
)

port map(
	clk 		=> clk_50,
	reset 	=> reset,
	rx 		=> uart_rx,
	tx 		=> uart_tx,

	received_data 	=> uart_received_data,
	received_valid	=> uart_received_valid,
	received_error => ledr(0),
	received_parity_error => open,
	
	transmit_ready => uart_transmit_ready,
   transmit_valid => uart_transmit_valid,
   transmit_data  => uart_transmit_data



);

		--
		
		
	--PWM Controller
i_pwm_control			: entity work.pwm_control
generic map ( 
	max_val	=> max_val,
	val_bits => val_bits
)
port map (
	clk => pll_clock_50,
	reset => reset,
	reset_n => reset_n,
	
	-- PWM Outputs
	pwm_pulse => pwm_pulse_top,
	pwm_duty_cycle_percent => pwm_duty_cycle_top,
	pwm_duty_update => pwm_duty_update_top,
	ledg => ledg(0),
	
	-- Serial inputs
	serial_on => serial_on_out,
	serial_off => serial_off_out,
	serial_up => serial_up_out,
	serial_down => serial_down_out,
	
	-- Key Inputs
	key_on => key_on_out,
	key_off => key_off_out,
	key_up => key_up_out,
	key_down => key_down_out
	

);
		--
		
		
	-- DC Display controller
i_dc_controll			:entity work.dc_disp_ctrl
generic map(
	bit_length	=> val_bits
	)
port map(
	dc_value 			=>  pwm_duty_cycle_top,
	duty_cycle_update => pwm_duty_update_top, 
	transmit_ready		=> uart_transmit_ready,
	transmit_data 		=> uart_transmit_data,
	transmit_valid 	=> uart_transmit_valid,
	clk 					=> pll_clock_50,
	reset 				=> reset,
	reset_n				=> reset_n,
	ready 				=> seg_ready,
	hex0 					=> hex0,
	hex1 					=> hex1,
	hex2 					=> hex2
	
);



end architecture top_level_rtl;