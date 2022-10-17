--=================================================================
--
-- Testbench Top
--
-- Testbench for the PWM module component
--
--    2019-02-14  Kent Abrahamsson
--                   First revision.
--
----=================================================================
library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
   use work.testbench_pkg.all;
library std;
   use std.textio.all;

entity testbench_top is

end entity testbench_top;

architecture bhv of testbench_top is

   -- Clock and reset generation
   signal clock_50         : std_logic := '0';
   signal reset_n          : std_logic := '0';
   signal kill_clock       : std_logic := '0';

   -- Signals for Serial UART in testbench
   signal serial_received_data         : std_logic_vector(7 downto 0); 
   signal serial_received_valid        : std_logic;  
   signal serial_received_error        : std_logic;  
   signal serial_received_parity_error : std_logic;  
   signal serial_transmit_ready        : std_logic;
   signal serial_transmit_valid        : std_logic;
   signal serial_transmit_data         : std_logic_vector(7 downto 0);

   -- Application signals for DUT
   signal key_n                  : std_logic_vector(3 downto 0);
   signal sw                     : std_logic_vector(9 downto 0);
   signal fpga_in_rx             : std_logic;
   signal fpga_out_tx            : std_logic;
   signal ledr                   : std_logic_vector(9 downto 0);
   signal ledg                   : std_logic_vector(7 downto 0);
   signal hex0                   : std_logic_vector(6 downto 0);
   signal hex1                   : std_logic_vector(6 downto 0);
   signal hex2                   : std_logic_vector(6 downto 0);
   signal hex3                   : std_logic_vector(6 downto 0);

   -- Signals for the PWM check process
   signal dut_pwm                : std_logic;
   signal detected_dc            : natural;
   signal detected_freq          : natural;

   -- Signals for the 7 Segment display check process
   signal hex_dc_valid           : std_logic       := '0';
   signal hex_dc_detected        : integer range 0 to 100 := 0;
   
   -- Signals for the UART Recv process
   type t_uart_recv_state is (   s_idle,
                                 s_get_tens,
                                 s_get_ones,
                                 s_get_percent,
                                 s_get_cr);
   signal uart_recv_state        : t_uart_recv_state;
   signal dc_save                : natural range 0 to 100;
   signal serial_detected_dc     : natural range 0 to 100;
   signal serial_dc_valid        : std_logic;
   signal serial_dc_update       : std_logic;
   signal serial_dc_error        : std_logic;

   -- Other testbench signals
   signal current_test_case_no   : natural range 0 to 20;
   signal key_on_n               : std_logic;
   signal key_off_n              : std_logic;
   signal key_up_n               : std_logic;
   signal key_down_n             : std_logic;
   signal saved_detected_dc      : natural range 0 to 100;

   procedure pr_write(v_input_str : in string) is
      variable v_line : line;
   begin
      write(v_line,v_input_str);
      writeline(OUTPUT, v_line);
   end procedure pr_write;

   procedure pr_write_test_pass_fail(
            test_no     : in natural;
            test_pass   : in boolean) is
   begin
         if test_pass then 
            pr_write("   Test case #" & fn_str(test_no,10) & " - PASS.");
         else
            pr_write("   Test case #" & fn_str(test_no,10) & " - FAIL.");
         end if;
   end procedure pr_write_test_pass_fail;

   impure function fn_write_dc_status (
      hex_dc : integer;
      meas_dc : integer;
      serial_dc : integer;
      expected_dc : integer;
      dc_tolerance_meas : integer;
      dc_tolerance_disp : integer)
      return boolean is
         variable v_return_val : boolean;
   begin
      
      v_return_val      := true;

      if serial_dc_valid = '1' and serial_dc_error = '0' then
         if serial_dc <= expected_dc + dc_tolerance_disp and serial_dc >= expected_dc - dc_tolerance_disp then
            pr_write("      Serial interface reports duty cycle : " & fn_str(serial_dc,10) & "% - OK");
         else
            pr_write("      Serial interface reports duty cycle : " & fn_str(serial_dc,10) & "% - Outside tolerance!");
            v_return_val      := false;
         end if;
      else
         pr_write("      Serial interface DC readout fails.");
         v_return_val      := false;
      end if;
      
      -- Measured duty cycle
      -- Allow one extra tolerance % for measured duty cycle
      if meas_dc <= expected_dc + dc_tolerance_meas and meas_dc >= expected_dc - dc_tolerance_meas then   
         pr_write("      Detected PWM output duty cycle : " & fn_str(meas_dc,10) & "% - OK!");
      else
         pr_write("      Detected PWM output duty cycle : " & fn_str(meas_dc,10) & "% - Outside tolerance!");
         v_return_val      := false;
      end if;
      
      -- 7 segment displayed duty cycle
      if hex_dc_valid = '1' then
         if hex_dc <= expected_dc + dc_tolerance_disp and hex_dc >= expected_dc - dc_tolerance_disp then
            pr_write("      Detected 7 segment output duty cycle : " & fn_str(hex_dc,10) & "% - OK!");
         else
            pr_write("      Detected 7 segment output duty cycle : " & fn_str(hex_dc,10) & "% - Outside tolerance!");
            v_return_val      := false;
         end if;
      else 
         pr_write("      7 segment output duty cycle invalid data.");
         v_return_val      := false;
      end if;

      return v_return_val;

   end function fn_write_dc_status;

begin -- architecture


   assert not (ledr(0) = '1')
      report "RED LED indicating receive error is set high!"
      severity warning;

   p_clk_gen : process
   begin
      -- Set reset active
      reset_n     <= '0';
      clock_50 <= '0';
      wait for 100 ns;
      clock_50 <= '1';
      wait for 5 ns;
      clock_50 <= '0';
      wait for 30 ns;
      clock_50 <= '1';
      wait for 20 ns;
      clock_50 <= '0';
      wait for 6 ns;
      clock_50 <= '1';
      wait for 14 ns;
      -- Set reset inactive
      reset_n     <= '1';
      while ( kill_clock = '0' ) loop
         clock_50 <= not clock_50;
         wait for 10 ns;
      end loop;
      -- wait forever;
      wait;
   end process p_clk_gen;

   p_test_main : process
      variable v_cnt : natural;
      variable v_test_fail : boolean := false;
      variable v_dc_check_ok : boolean := false;
   begin
      -- Set startup values
      kill_clock              <= '0';
      current_test_case_no    <= 0;
      key_on_n                <= '1';
      key_off_n               <= '1';
      key_up_n                <= '1';
      key_down_n              <= '1';
      serial_transmit_valid   <= '0';
      serial_transmit_data    <= (others => '0');
      saved_detected_dc       <= 0;
      pr_write("Simulation starts");
      -- wait until reset is released
      wait until reset_n = '1';
      -- Wait for another us
      wait for 1 us;
      current_test_case_no    <= 0;
      v_test_fail             := false;
      wait for 1 ps;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Check startup values - expect 0 %");
         wait for 1 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                0,
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status

      current_test_case_no    <= 1;
      v_test_fail             := false;
      wait for 1 ps;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Key control - ON - expect 100 %");
         -- Push ON key
         key_on_n                <= '0';
         wait for 1 ms;
         -- Release ON key
         key_on_n                <= '1';
         -- Wait for 3 ms to ensure PWM Check process to get 100 % duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                100,
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status

      current_test_case_no    <= 2;
      v_test_fail             := false;
      wait for 1 ps;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Key control - OFF - expect 0%");
         -- Push OFF key
         key_off_n               <= '0';
         wait for 1 ms;
         -- Release OFF key
         key_off_n               <= '1';
         -- Wait for 3 ms to ensure PWM Check process to get 0 % duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                0, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status

      current_test_case_no    <= 3;
      v_test_fail             := false;
      wait for 1 ps;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Key control - UP - should set Duty Cycle to 10%");
         -- Push UP key
         key_up_n                <= '0';
         wait for 5 ms;
         -- Release UP key
         key_up_n                <= '1';
         -- Wait for 3 ms to ensure PWM Check process to get 10 % duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                10, -- Expected DC
                                                1, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status

      current_test_case_no    <= 4;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Check 1kHz PWM frequency (+/- 1 Hz)");
         wait for 1 ms;
         pr_write("      Detected PWM frequency : " & fn_str(detected_freq,10) & " Hz");
         if detected_freq >= 999 and detected_freq <= 1001  then
            pr_write("   Test case #" & fn_str(current_test_case_no,10) & " - PASS.");
         else
            pr_write("   Test case #" & fn_str(current_test_case_no,10) & " - FAIL.");
         end if;

      current_test_case_no    <= 5;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Key hold control - UP 50 ms to ~15 % Duty cycle");
         -- Push UP key
         key_up_n                <= '0';
         wait for 50 ms;
         -- Release UP key
         key_up_n                <= '1';
         -- Wait for 5 ms to ensure PWM Check process to get updated duty cycle.
         wait for 5 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                15, -- Expected DC
                                                1, -- DC tolerance measured
                                                1); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
      
      current_test_case_no    <= 6;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Key control - DOWN 5 ms to decrease Duty cycle with 1 %");
         saved_detected_dc       <= detected_dc;
         -- Push DOWN key
         key_down_n              <= '0';
         wait for 5 ms;
         -- Release DOWN key
         key_down_n              <= '1';
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                (saved_detected_dc - 1), -- Expected DC
                                                1, -- DC tolerance measured
                                                1); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 7;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Key hold control - DOWN 70 ms to decrease Duty cycle to minimum (10 %)");
         saved_detected_dc       <= detected_dc;
         -- Push DOWN key
         key_down_n              <= '0';
         wait for 70 ms;
         -- Release DOWN key
         key_down_n              <= '1';
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                10, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 8;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Serial control - Up by sending U in ASCII, expecting 11 %");
         serial_transmit_data    <= c_ascii_u_uc;
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                11, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 9;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Serial control - Up by sending u in ASCII, expecting 12 %");
         serial_transmit_data    <= c_ascii_u_lc;
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                12, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 10;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Serial control - Off by sending 0 in ASCII, expecting 0 %");
         serial_transmit_data    <= c_ascii_0;
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                0, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 11;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Serial control - ON by sending 1 in ASCII, expecting 12 % (remembered)");
         serial_transmit_data    <= c_ascii_1;
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                12, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 12;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Serial control - DOWN by sending d in ASCII, expecting 11 %");
         serial_transmit_data    <= c_ascii_d_lc;
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                11, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 13;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Serial control - DOWN by sending D in ASCII, expecting 10 %");
         serial_transmit_data    <= c_ascii_d_uc;
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                10, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      current_test_case_no    <= 14;
      wait for 1 ps;
      v_test_fail             := false;
      pr_write("Test case #" & fn_str(current_test_case_no,10) & " - Serial control - DOWN by sending D in ASCII, expecting 10 %");
         serial_transmit_data    <= c_ascii_d_uc;
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         serial_transmit_valid   <= '1';
         wait until serial_transmit_ready = '0';
         serial_transmit_valid   <= '0';
         wait until serial_transmit_ready = '1';   -- byte sent
         
         -- Wait for 3 ms to ensure PWM Check process to get updated duty cycle.
         wait for 3 ms;
         v_dc_check_ok := fn_write_dc_status (  hex_dc_detected,
                                                detected_dc,
                                                serial_detected_dc,
                                                10, -- Expected DC
                                                0, -- DC tolerance measured
                                                0); -- DC tolerance displayed
   
         pr_write_test_pass_fail(current_test_case_no,v_dc_check_ok);   -- Write test status
         
      wait for 1 ms;

      pr_write("Simulation ends");

      -- Kill clock and wait forever.
      kill_clock           <= '1';
      wait;
   end process p_test_main;

   key_n <= key_up_n & key_down_n & key_on_n & key_off_n;

   i_pwm_module : entity work.top_level
   generic map(
      g_simulation            => true)
   port map(
      clk_50                => clock_50,

      -- Serial interface
      uart_rx          	  => fpga_in_rx,
      uart_tx           	  => fpga_out_tx,

      -- Key pushbutton inputs
      key_press                   => key_n,

      -- Switch input
      --sw                      => sw,

      -- 7 Segment display output
      hex0                    => hex0,
      hex1                    => hex1,
      hex2                    => hex2,

      -- Green led outputs
      ledg                    => ledg,
      -- Red led outputs
      ledr                    => ledr);

   i_tb_serial_uart : entity work.serial_uart
   generic map(
      g_reset_active_state    => '0',
      g_serial_speed_bps      => 115200,
      g_clk_period_ns         => 20,      -- 50 MHz testbench clock
      g_parity                => 0)
   port map(
      clk                     => clock_50,
      reset                   => reset_n, -- active low reset
      rx                      => fpga_out_tx,
      tx                      => fpga_in_rx,

      received_data           => serial_received_data,
      received_valid          => serial_received_valid,
      received_error          => serial_received_error,
      received_parity_error   => serial_received_parity_error,

      transmit_ready          => serial_transmit_ready,
      transmit_valid          => serial_transmit_valid,
      transmit_data           => serial_transmit_data);

   dut_pwm <= ledg(0);

   --====================================================
   -- Process p_pwm_check
   -- Checks PWM output and calculates Duty cycle and
   -- Frequency of the PWM output signal.
   --====================================================
   p_pwm_check : process
      variable v_dc_high_cnt_us     : natural  := 0;
      variable v_dc_low_cnt_us      : natural  := 0;
      variable v_dc_period_cnt_us   : natural  := 0;
      --variable v_test_period        : real;
   begin
      v_dc_period_cnt_us      := 0;
      v_dc_high_cnt_us        := 0;
      v_dc_low_cnt_us         := 0;
      detected_dc             <= 0;
      while kill_clock /= '1' loop
         v_dc_high_cnt_us        := 0;
         v_dc_low_cnt_us         := 0;
         -- check if pwm signal is low
         if dut_pwm /= '1' then
            -- if pwm output is low wait until it gets high
            wait until dut_pwm = '1';
         end if;
         while dut_pwm = '1' and v_dc_high_cnt_us < 1200 loop
            wait for 1 us;
            v_dc_high_cnt_us       := v_dc_high_cnt_us + 1;
         end loop;
         if v_dc_high_cnt_us = 1200 then
            -- PWM output was high more than 1200 us expected 100% duty cycle
            detected_dc             <= 100;
            detected_freq           <= 0;
         end if;
                  
         -- check if pwm signal is still high
         if dut_pwm = '1' then
            -- Wait until pwm signal drops low
            wait until dut_pwm = '0';
         end if;
         while dut_pwm = '0' and v_dc_low_cnt_us < 1200 loop
            wait for 1 us;
            v_dc_low_cnt_us         := v_dc_low_cnt_us + 1;
         end loop;
         
         if v_dc_low_cnt_us = 1200 then
            -- PWM output was low more than 1200 us expected 0% duty cycle
            detected_dc             <= 0;
            detected_freq           <= 0;
         elsif v_dc_high_cnt_us < 1200 then
            -- PWM output was low less than 1200 us and high less than 1200 us
            -- calculate duty cycle
            v_dc_period_cnt_us      := v_dc_high_cnt_us + v_dc_low_cnt_us;
            wait for 1 ps;
            --v_test_period           := 1000.0;
            --v_test_high_cnt         := 500.0;
            wait for 1 ps;
            --v_test_dc               := 100.0 * v_test_high_cnt / v_test_period;

            --v_detected_dc_real      := 100.0 * real(v_dc_high_cnt_us) / real(v_dc_period_cnt_us);


            if v_dc_period_cnt_us > 0 then
               detected_dc             <= (100*v_dc_high_cnt_us) / v_dc_period_cnt_us;
               detected_freq           <= 1000000/v_dc_period_cnt_us;
            else
               detected_dc             <= 0;
               detected_freq           <= 0;
            end if;
            
         end if;
            -- NOTE if high time was timed out (1200 us) duty cycle is not calculated

      end loop;
      wait; -- wait forever

   end process p_pwm_check;



   p_7seg_check : process(hex0, hex1, hex2)
      variable v_hex_dc_calc  : natural range 0 to 100;
      variable v_hex_invalid  : std_logic;
      variable v_hex2_check   : natural;
      variable v_hex1_check   : natural;
      variable v_hex0_check   : natural;
   begin
      v_hex_dc_calc  := 0;
      v_hex2_check   := fn_7_seg_check(hex2);
      v_hex1_check   := fn_7_seg_check(hex1);
      v_hex0_check   := fn_7_seg_check(hex0);

      if v_hex2_check = 1 then
         v_hex_dc_calc     := 100;
         v_hex_invalid     := '0';
      elsif v_hex2_check = 0 or v_hex2_check = 17 then
         v_hex_dc_calc     := 0;
         v_hex_invalid     := '0';
      else
         v_hex_invalid     := '1';
      end if;
      if v_hex1_check < 10 and v_hex_invalid = '0' then
         v_hex_dc_calc     := v_hex_dc_calc + v_hex1_check*10;
      elsif fn_7_seg_check(hex2) = 17 and v_hex1_check = 17 then
         -- both hundreds and tens number is blank
         v_hex_dc_calc     := 0;
         v_hex_invalid     := '0';
      else
         v_hex_dc_calc     := 0;
         v_hex_invalid     := '1';
      end if;
      if v_hex_invalid = '0' and v_hex0_check < 10 then 
         v_hex_dc_calc     := v_hex_dc_calc + v_hex0_check;
      end if;
      hex_dc_valid      <= not v_hex_invalid;
      hex_dc_detected   <= v_hex_dc_calc;

   end process p_7seg_check;

   p_uart_recv : process(clock_50)
   begin
      if rising_edge(clock_50) then
         serial_dc_update     <= '0';
         case uart_recv_state is
            when s_idle =>
               dc_save  <= 0;
               if serial_received_valid = '1' then
                  if serial_received_data = X"20" or serial_received_data = X"30" then
                     -- Space or "0" received
                     -- Jump to get_tens state
                     uart_recv_state      <= s_get_tens;
                  elsif serial_received_data = X"31" then
                     -- "1" received
                     -- Jump to get_tens state
                     dc_save              <= 100;
                     uart_recv_state      <= s_get_tens;
                  else
                     -- not 0 or 1 or space
                     -- set error and go to get cr state
                     assert(false)
                        report "Hundreds character invalid on serial interface."
                        severity warning;
                     serial_dc_error      <= '1';
                     uart_recv_state      <= s_get_cr;
                  end if;
               else
                  uart_recv_state      <= s_idle;
               end if;

            when s_get_tens =>
               if serial_received_valid = '1' then
                  if serial_received_data = X"20" then
                     -- Space received
                     if dc_save = 0 then
                        uart_recv_state      <= s_get_ones;
                     else
                        -- dc_save is not 0 (set to 100 above) when space is received
                        -- set error and go to get cr state
                        assert(false)
                           report "Unexpected Space character was received"
                           severity warning;
                        serial_dc_error      <= '1';
                        uart_recv_state      <= s_get_cr;
                     end if;
                  elsif serial_received_data = X"30" and dc_save = 100 then
                     -- Zero received as expected
                     uart_recv_state      <= s_get_ones;
                  elsif serial_received_data(7 downto 4) = X"3" and to_integer(unsigned(serial_received_data(3 downto 0))) < 10 and dc_save < 100 then
                     dc_save              <= 10*to_integer(unsigned(serial_received_data(3 downto 0)));
                     uart_recv_state      <= s_get_ones;
                  else
                     -- Not space or number between 0 and 9
                     -- set error and go to get cr state
                     assert(false)
                        report "Unexpected character was received"
                        severity warning;
                     serial_dc_error      <= '1';
                     uart_recv_state      <= s_get_cr;
                  end if;
               else
                  uart_recv_state      <= s_get_tens;
               end if;

            when s_get_ones =>
               if serial_received_valid = '1' then
                  if dc_save = 100 and serial_received_data = X"30" then
                     -- zero received as expected for 100 % duty cycle
                     uart_recv_state      <= s_get_percent;
                  elsif serial_received_data(7 downto 4) = X"3" and to_integer(unsigned(serial_received_data(3 downto 0))) < 10 and dc_save < 100 then
                     dc_save              <= dc_save + to_integer(unsigned(serial_received_data(3 downto 0)));
                     uart_recv_state      <= s_get_percent;
                  else
                     assert(false)
                        report "Unexpected character was received"
                        severity warning;
                     serial_dc_error      <= '1';
                     uart_recv_state      <= s_get_percent;
                  end if;
               else
                  uart_recv_state      <= s_get_ones;
               end if;

            when s_get_percent =>
               if serial_received_valid = '1' then
                  if serial_received_data /= X"25" then
                     -- % character not received as expected
                     assert(false)
                        report "Unexpected character was received"
                        severity warning;
                     serial_dc_error      <= '1';
                  end if;
                  uart_recv_state      <= s_get_cr;
               else
                  uart_recv_state      <= s_get_percent;
               end if;

            when s_get_cr =>
               if serial_received_valid = '1' and serial_received_data = X"0D" then
                  -- Carriage return received
                  -- Update received serial duty cycle if no error was detected.
                  if serial_dc_error = '0' then
                     serial_dc_valid      <= '1';
                     serial_dc_update     <= '1';
                     serial_detected_dc   <= dc_save;
                  end if;
               end if;
               -- state is changed to idle below.

         end case;
         if serial_received_valid = '1' and serial_received_data = X"0D" then
            -- Carriage return received
            -- Jump to idle state
            uart_recv_state      <= s_idle;
            if uart_recv_state /= s_get_cr then
               assert(false)
                  report "Unexpected character was received"
                  severity warning;

               serial_dc_error      <= '1';
            end if;
         end if;

               

         if reset_n = '0' then
            dc_save              <= 0;
            serial_detected_dc   <= 0;
            serial_dc_valid      <= '0';
            serial_dc_update     <= '0';
            serial_dc_error      <= '0';
            uart_recv_state      <= s_idle;
         end if;

      end if;
   end process p_uart_recv;

end architecture bhv;