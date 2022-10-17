--=================================================================
--
-- Testbench Package
--
-- Package file for testbench,
-- containing useful functions for the testbench.
--
--    2019-02-14  Kent Abrahamsson
--                   First revision.
--
----=================================================================
library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

package testbench_pkg is
   
   type t_7seg_check is array (17 downto 0) of std_logic_vector(6 downto 0);
   constant c_7seg_check       : t_7seg_check   := ("1111111",  -- " "
                                                   "0111111",  -- "-"
                                                   "0001110",  -- "F"
                                                   "0000110",  -- "E"
                                                   "0100001",  -- "d"
                                                   "1000110",  -- "C"
                                                   "0000011",  -- "b"
                                                   "0001000",  -- "A"
                                                   "0011000",  -- "9"
                                                   "0000000",  -- "8"
                                                   "1111000",  -- "7"
                                                   "0000010",  -- "6"
                                                   "0010010",  -- "5"
                                                   "0011001",  -- "4"
                                                   "0110000",  -- "3"
                                                   "0100100",  -- "2"
                                                   "1111001",  -- "1"
                                                   "1000000");  -- "0"

   constant c_ascii_u_uc   : std_logic_vector(7 downto 0) := X"55";
   constant c_ascii_u_lc   : std_logic_vector(7 downto 0) := X"75";
   constant c_ascii_d_uc   : std_logic_vector(7 downto 0) := X"44";
   constant c_ascii_d_lc   : std_logic_vector(7 downto 0) := X"64";
   constant c_ascii_0      : std_logic_vector(7 downto 0) := X"30";
   constant c_ascii_1      : std_logic_vector(7 downto 0) := X"31";
   
   --========================================================
   -- Function fn_7_seg_check
   -- Check 7 segmend display output
   -- returns natural value 
   --    0-15 for regular hex data 0-9 -> A-F
   --    16 for "-"
   --    17 for blank display
   --    18 for unknown
   --========================================================
   function fn_7_seg_check(
      seven_seg_number : in std_logic_vector(6 downto 0))
      return natural;

   function fn_chr(
         int: integer) 
         return character;
   
   function fn_str(
         int: integer; 
         base: integer) 
         return string;

end package testbench_pkg;

package body testbench_pkg is

   --========================================================
   -- Function fn_7_seg_check
   -- Check 7 segmend display output
   -- returns natural value 
   --    0-15 for regular hex data 0-9 -> A-F
   --    16 for "-"
   --    17 for blank display
   --    18 for unknown
   --========================================================
   function fn_7_seg_check(
      seven_seg_number : in std_logic_vector(6 downto 0))
      return natural is
         variable v_loop_cnt : natural range 0 to 18;
   begin
      v_loop_cnt := 0;
      while v_loop_cnt < 18 loop
         if seven_seg_number = c_7seg_check(v_loop_cnt) then
            exit;
         else
            v_loop_cnt  := v_loop_cnt + 1;
         end if;
      end loop;
      return v_loop_cnt;
      
   end function fn_7_seg_check;
   -- converts an integer into a character
   -- for 0 to 9 the obvious mapping is used, higher
   -- values are mapped to the characters A-Z
   -- (this is usefull for systems with base > 10)
   -- (adapted from Steve Vogwell's posting in comp.lang.vhdl)

   -- Fetched from https://opencores.org/websvn/filedetails?repname=ion&path=%2Fion%2Ftrunk%2Fvhdl%2Ftb%2Ftxt_util.vhdl
   -- and renamed function names to fn_
 
   function fn_chr(int: integer) return character is
    variable c: character;
   begin
        case int is
          when  0 => c := '0';
          when  1 => c := '1';
          when  2 => c := '2';
          when  3 => c := '3';
          when  4 => c := '4';
          when  5 => c := '5';
          when  6 => c := '6';
          when  7 => c := '7';
          when  8 => c := '8';
          when  9 => c := '9';
          when 10 => c := 'A';
          when 11 => c := 'B';
          when 12 => c := 'C';
          when 13 => c := 'D';
          when 14 => c := 'E';
          when 15 => c := 'F';
          when 16 => c := 'G';
          when 17 => c := 'H';
          when 18 => c := 'I';
          when 19 => c := 'J';
          when 20 => c := 'K';
          when 21 => c := 'L';
          when 22 => c := 'M';
          when 23 => c := 'N';
          when 24 => c := 'O';
          when 25 => c := 'P';
          when 26 => c := 'Q';
          when 27 => c := 'R';
          when 28 => c := 'S';
          when 29 => c := 'T';
          when 30 => c := 'U';
          when 31 => c := 'V';
          when 32 => c := 'W';
          when 33 => c := 'X';
          when 34 => c := 'Y';
          when 35 => c := 'Z';
          when others => c := '?';
        end case;
        return c;
    end fn_chr;
 
   
   -- convert integer to string using specified base
   -- (adapted from Steve Vogwell's posting in comp.lang.vhdl)
   -- Fetched from https://opencores.org/websvn/filedetails?repname=ion&path=%2Fion%2Ftrunk%2Fvhdl%2Ftb%2Ftxt_util.vhdl
   -- and renamed function names to fn_
 
   function fn_str(int: integer; base: integer) return string is
 
    variable temp:      string(1 to 10);
    variable num:       integer;
    variable abs_int:   integer;
    variable len:       integer := 1;
    variable power:     integer := 1;
 
   begin
 
    -- bug fix for negative numbers
    abs_int := abs(int);
 
    num     := abs_int;
 
    while num >= base loop                     -- Determine how many
      len := len + 1;                          -- characters required
      num := num / base;                       -- to represent the
    end loop ;                                 -- number.
 
    for i in len downto 1 loop                 -- Convert the number to
      temp(i) := fn_chr(abs_int/power mod base);  -- a string starting
      power := power * base;                   -- with the right hand
    end loop ;                                 -- side.
 
    -- return result and add sign if required
    if int < 0 then
       return '-'& temp(1 to len);
     else
       return temp(1 to len);
    end if;
 
   end fn_str;


end package body testbench_pkg;