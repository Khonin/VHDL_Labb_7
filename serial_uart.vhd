library ieee;
   use ieee.std_logic_1164.all;

--=================================================================
--
-- Serial UART
--
-- Sends and receives data on serial bus.
-- One stop bit is assumed
-- Parity is configurable
-- Speed is configurable depending on bit rate and clock period
-- generics.
--
--=================================================================
entity serial_uart is
   generic(
      g_reset_active_state    : std_logic                      := '1';
      g_serial_speed_bps      : natural range 9600 to 115200   := 115200;
      g_clk_period_ns         : natural range 10 to 100        := 20;      -- 100 MHz standard clock
      g_parity                : natural range 0 to 2           := 0);      -- 0 = no, 1 = odd, 2 = even
   port(
      clk                     : in  std_logic;
      reset                   : in  std_logic;   -- active high reset
      rx                      : in  std_logic;
      tx                      : out std_logic;

      received_data           : out std_logic_vector(7 downto 0); -- Received data
      received_valid          : out std_logic;  -- Set high one clock cycle when byte is received.
      received_error          : out std_logic;  -- Stop bit was not high
      received_parity_error   : out std_logic;  -- Parity error detected

      transmit_ready          : out std_logic;
      transmit_valid          : in  std_logic;
      transmit_data           : in  std_logic_vector(7 downto 0));
end entity serial_uart;

architecture rtl of serial_uart is

   -- Types and constants
   type t_rx_state is ( s_idle,
                        s_rx_data,
                        s_parity,
                        s_stop_bit);
   type t_tx_state is ( s_idle,
                        s_start_bit,
                        s_tx_data,
                        s_parity,
                        s_stop_bit);

   constant c_bit_cnt_max        : natural := (10**9)/(g_clk_period_ns*g_serial_speed_bps) - 1;
   constant c_half_bit_cnt_max   : natural := c_bit_cnt_max/2;

   -- double synchronize rx_data
   signal rx_r                   : std_logic;
   signal rx_2r                  : std_logic;
   signal reset_r                : std_logic;
   signal reset_2r               : std_logic;

   -- Signals for p_rx_data process
   signal rx_state               : t_rx_state;
   signal rx_byte_int            : std_logic_vector(6 downto 0);
   signal rx_bit_no              : natural range 0 to 7;
   signal rx_parity_toggle       : std_logic;

   -- Signals for p_counters process
   signal rx_bit_cnt             : natural range 0 to c_bit_cnt_max;
   signal rx_bit_cnt_en          : std_logic;
   signal rx_bit_cnt_wrap        : std_logic;
   signal rx_bit_cnt_half        : std_logic;
   signal tx_bit_cnt             : natural range 0 to c_bit_cnt_max;
   signal tx_bit_cnt_en          : std_logic;
   signal tx_bit_cnt_wrap        : std_logic;

   -- Signals for p_tx_data process
   signal tx_state               : t_tx_state;
   signal tx_bit_no              : natural range 0 to 7;
   signal tx_byte_saved          : std_logic_vector(7 downto 0);
   signal tx_parity_bit          : std_logic;

begin

   p_double_sync : process(clk)
   begin
      if rising_edge(clk) then
         rx_r        <= rx;
         rx_2r       <= rx_r;
         reset_r     <= reset;
         reset_2r    <= reset_r;
      end if;
   end process p_double_sync;


   p_rx_data : process(clk)
   begin
      if rising_edge(clk) then

         -- Default assignments
         received_valid          <= '0';
         rx_bit_cnt_en           <= '0';
         received_parity_error   <= '0';

         case rx_state is
            when s_idle =>
               -- Wait for one half bit time of start bit
               if rx_2r = '0' then
                  rx_bit_cnt_en     <= '1';
               end if;
               if rx_bit_cnt_half = '1' then
                  rx_state          <= s_rx_data;
                  -- reset bit counter
                  rx_bit_cnt_en     <= '0';
               end if;
               rx_byte_int       <= (others => '0');
               rx_bit_no         <= 0;
               rx_parity_toggle  <= '0';

            when s_rx_data =>
               -- Enable bit counter
               rx_bit_cnt_en  <= '1';
               if rx_bit_cnt_wrap = '1' then
                  rx_byte_int    <= rx_2r & rx_byte_int(6 downto 1);
                  -- Invert toggle bit if received bit is '1'
                  rx_parity_toggle  <= rx_parity_toggle xor rx_2r;
                  if rx_bit_no = 7 then
                     received_data  <= rx_2r & rx_byte_int;
                     if g_parity /= 0 then
                        rx_state       <= s_parity;
                     else
                        rx_state       <= s_stop_bit;
                     end if;
                  else
                     rx_bit_no      <= rx_bit_no + 1;
                     rx_state       <= s_rx_data;
                  end if;
               else
                  rx_state       <= s_rx_data;
               end if;

            when s_parity =>
               -- Enable bit counter
               rx_bit_cnt_en  <= '1';
               if rx_bit_cnt_wrap = '1' then
                  if g_parity = 1 then
                     -- Odd parity parity bit should not be equal to the toggle bit since
                     -- it toggles from zero for every 1 in the data.
                     received_parity_error   <= not (rx_2r xor rx_parity_toggle);
                  else
                     -- g_parity = 2 = even parity
                     received_parity_error   <= rx_2r xor rx_parity_toggle;
                  end if;
                  rx_state       <= s_stop_bit;
               else
                  rx_state       <= s_parity;
               end if;

            when s_stop_bit =>
               -- Wait in this state for stop bit
               if rx_bit_cnt_wrap = '1' then
                  -- Set error high if rx signal is low on stop bit
                  received_error <= not rx_2r;
                  received_valid <= rx_2r;
                  rx_state       <= s_idle;
               else
                  rx_bit_cnt_en  <= '1';
                  rx_state       <= s_stop_bit;
               end if;

         end case;


         if reset_2r = g_reset_active_state then
            received_error          <= '0';
            received_parity_error   <= '0';
            received_data           <= (others => '0');
            rx_state                <= s_idle;

         end if;
      end if;
   end process p_rx_data;

   p_tx_data : process(clk)
   begin
      if rising_edge(clk) then

         -- Enable tx_bit_counter by default
         tx_bit_cnt_en  <= '1';

         case tx_state is
            when s_idle =>
               tx_parity_bit  <= '0';
               if transmit_valid = '1' then
                  tx_byte_saved  <= transmit_data;
                  transmit_ready <= '0';
                  tx_state       <= s_start_bit;
               else
                  tx_bit_cnt_en  <= '0';
                  transmit_ready <= '1';
                  tx_state       <= s_idle;
               end if;
               tx_bit_no      <= 0;
               -- Set TX bit to '1' in idle state
               tx             <= '1';

            when s_start_bit =>
               -- Start bit is zero
               tx             <= '0';
               tx_parity_bit  <= tx_byte_saved(0);
               if tx_bit_cnt_wrap = '1' then
                  tx_state       <= s_tx_data;
               else
                  tx_state       <= s_start_bit;
               end if;

            when s_tx_data =>
               tx       <= tx_byte_saved(0);
               if tx_bit_cnt_wrap = '1' then
                  tx_parity_bit     <= tx_parity_bit xor tx_byte_saved(1);
                  tx_byte_saved     <= '0' & tx_byte_saved(7 downto 1);
                  if tx_bit_no = 7 then
                     if g_parity /= 0 then
                        tx_state       <= s_parity;
                     else
                        tx_state       <= s_stop_bit;
                     end if;
                  else
                     tx_bit_no      <= tx_bit_no + 1;
                     tx_state       <= s_tx_data;
                  end if;
               else
                  tx_state       <= s_tx_data;
               end if;

            when s_parity =>
               if g_parity = 1 then
                  -- Odd parity
                  tx       <= not tx_parity_bit;
               else
                  -- Even parity
                  tx       <= tx_parity_bit;
               end if;
               if tx_bit_cnt_wrap = '1' then
                  tx_state       <= s_stop_bit;
               else
                  tx_state       <= s_parity;
               end if;

            when s_stop_bit =>
               -- Set TX stop bit to '1'
               tx             <= '1';
               if tx_bit_cnt_wrap = '1' then
                  transmit_ready <= '1';
                  tx_bit_cnt_en  <= '0';
                  tx_state       <= s_idle;
               else
                  tx_state       <= s_stop_bit;
               end if;

         end case;

         if reset_2r = g_reset_active_state then
            tx_bit_cnt_en  <= '0';
            tx_state       <= s_idle;

         end if;
      end if;
   end process p_tx_data;

   p_counters : process(clk)
   begin
      if rising_edge(clk) then

         rx_bit_cnt_wrap   <= '0';
         rx_bit_cnt_half   <= '0';
         if rx_bit_cnt_en = '1' then
            if rx_bit_cnt < c_bit_cnt_max then
               rx_bit_cnt        <= rx_bit_cnt + 1;
            else
               rx_bit_cnt_wrap   <= '1';
               rx_bit_cnt        <= 0;
            end if;
            if rx_bit_cnt >= c_half_bit_cnt_max then
               rx_bit_cnt_half   <= '1';
            end if;
         else
            rx_bit_cnt     <= 0;
         end if;

         tx_bit_cnt_wrap   <= '0';
         if tx_bit_cnt_en = '1' then
            if tx_bit_cnt < c_bit_cnt_max then
               tx_bit_cnt     <= tx_bit_cnt + 1;
            else
               tx_bit_cnt_wrap   <= '1';
               tx_bit_cnt     <= 0;
            end if;
         else
            tx_bit_cnt     <= 0;
         end if;

      end if;
   end process p_counters;


end architecture rtl;
