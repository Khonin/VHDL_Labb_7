begin-- architecture

   ledr(9 downto 1)     <= (others => '0');
   ledg(7 downto 1)     <= (others => '0');

   b_gen_pll : if (not g_simulation) generate
   -- Instance of PLL
      i_altera_pll : entity work.altera_pll
      port map(
         areset		=> '0',        -- Reset towards PLL is inactive
         inclk0		=> clock_50,   -- 50 MHz input clock
         c0		      => open,       -- 25 MHz output clock unused
         c1		      => clk_50,     -- 50 MHz output clock
         c2		      => open,       -- 100 MHz output clock unused
         locked		=> pll_locked);-- PLL Locked output signal

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
      clk_50   <= clock_50;
      p_internal_reset : process
      begin
         reset    <= '1';
         wait until clock_50 = '1';
         wait for 1 us;
         wait until clock_50 = '1';
         reset    <= '0';
         wait;
      end process p_internal_reset;
   end generate;
