--=================================================================
--
-- Reset Control
--
-- Reset control block to asynchonously assert and
-- synchonously deassert the reset in the design.
-- Both active high and active low inputs can be used.
-- Unused inputs shall be set to inactive value.
--
--    2019-02-14  Kent Abrahamsson
--                   First revision.
--
----=================================================================
library ieee;
   use ieee.std_logic_1164.all;
  
entity reset_ctrl is
generic(
   g_reset_hold_clk  : in natural range 10 to 1023);
port (
   clk         : in std_logic;
   reset_in    : in std_logic;
   reset_in_n  : in std_logic;
   
   reset_out   : out std_logic;
   reset_out_n : out std_logic);
end entity reset_ctrl;

architecture rtl of reset_ctrl is
   signal reset_cnt     : natural range 0 to g_reset_hold_clk;
begin

   p_reset_ctrl : process(reset_in,reset_in_n,clk)
   begin
      if reset_in = '1' or reset_in_n = '0' then
         -- Input reset is active
         -- asynchronously set output reset active
         reset_out      <= '1';
         reset_out_n    <= '0';
         reset_cnt      <= 0;
      elsif rising_edge(clk) then
         if reset_cnt < g_reset_hold_clk then
            reset_out      <= '1';
            reset_out_n    <= '0';
            reset_cnt      <= reset_cnt + 1;
         else
            -- Reset counter is max  
            -- Deassert output reset signals synchronous to 
            -- rising edge of clock 
            reset_out      <= '0';
            reset_out_n    <= '1';
         end if;
      end if;
   end process p_reset_ctrl;

end architecture rtl;