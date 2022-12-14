library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
	--use IEEE.math_real.all;
	
entity dc_disp_ctrl is
generic(
	bit_length	: integer :=8

);

port (
	
	-- inputs
	duty_cycle_update		: in std_logic:='0';
	clk				: in std_logic:='0';
	reset				: in std_logic:='0'; -- Active high reset
	reset_n			: in std_logic:='1'; -- Active low reset
	dc_value			: in std_logic_vector((bit_length-1) downto 0):="00000000";
	transmit_ready : in std_logic:='1';
	
	
	-- outputs
	transmit_data  		: out std_logic_vector(7 downto 0);
	transmit_valid			: out std_logic;
	ready 					: out std_logic;
	hex0						: out std_logic_vector(6 downto 0);	
	hex1						: out std_logic_vector(6 downto 0);	
	hex2						: out std_logic_vector(6 downto 0)


);

end entity;



architecture seg_control of dc_disp_ctrl is
signal bcd_ones                   : unsigned(3 downto 0):="0000"; -- ones
signal bcd_tens                   : unsigned(3 downto 0):="0000"; -- tens
signal bcd_hundreds               : unsigned(3 downto 0):="0000"; -- hundreds
signal valid_out					: boolean:=false;
signal transmission_flag		: boolean:=false;
signal transmission_buffer		: boolean:=false;
signal transmission_iteration : integer range 0 to 5:=0;

function int_to_ascii(int : integer)
	return std_logic_vector is
begin
	case int is 
			when 0 =>
				return "00110000"; -- ASCII 0
			when 1 =>
				return "00110001"; -- ASCII 1
			when 2 =>
				return "00110010"; -- ASCII 2
			when 3 =>
				return "00110011"; -- ASCII 3
			when 4 =>
				return "00110100"; -- ASCII 4
			when 5 =>
				return "00110101"; -- ASCII 5
			when 6 =>
				return "00110110"; -- ASCII 6
			when 7 =>
				return "00110111"; -- ASCII 7
			when 8 =>
				return "00111000"; -- ASCII 8 
			when 9 =>
				return "00111001"; -- ASCII 9
			when others =>
				return "00111111"; -- ASCII ?
	end case;
end function int_to_ascii;


begin 

DC_transmitt_process : process (clk,valid_out,transmit_ready)


begin
	
	if(rising_edge(clk)) then
		transmit_valid <= '0';	
		if(transmission_buffer AND transmission_flag = false) then
			transmission_flag <= true;
			transmission_buffer <= false;
		elsif(duty_cycle_update ='1' AND transmission_flag = false) then
			transmission_flag <= true;
		elsif (duty_cycle_update ='1' AND transmission_flag) then
			transmission_buffer <= true;
			
		end if;
		if(transmit_ready = '1' and transmission_flag) then
			
			if( transmission_iteration = 0) then
				if(bcd_hundreds = "0001") then
					transmit_data <= int_to_ascii(to_integer(bcd_hundreds));
				else
					transmit_data <= "00100000"; -- ASCII SPACE
				end if;
			elsif (transmission_iteration = 1) then
				if(bcd_tens /= "0000" or bcd_hundreds = "0001") then
					transmit_data <= int_to_ascii(to_integer(bcd_tens));
				else
					transmit_data <= "00100000"; -- ASCII SPACE
				end if;
			elsif transmission_iteration = 2 then
				transmit_data <= int_to_ascii(to_integer(bcd_ones));
			elsif transmission_iteration = 3 then
				transmit_data <= "00100101";
			elsif transmission_iteration = 4 then
				transmit_data <= "00001101";
			end if;
		
			if(transmission_iteration < 5) then
				transmit_valid <= '1';
				transmission_iteration <= transmission_iteration + 1;
			else
				transmit_valid <= '0';
				transmit_data <= "00000000";
				transmission_iteration <= 0;
				transmission_flag <= false;
			end if;
		end if;
	
	end if;
end process DC_transmitt_process;


bcd_to_7seg   : process(valid_out,bcd_ones,bcd_tens,bcd_hundreds)

begin
	if(valid_out) then
		case bcd_hundreds is
			when "0000" =>
				hex2 <= "1111111"; -- Blank
			when "0001" =>
				hex2 <= "1111001"; -- 1
			when others =>
				hex2 <= "0111111"; -- -
		end case;			
		case bcd_tens is	
			when "0000" =>
				if(bcd_hundreds /= "0001") then
					hex1 <= "1111111"; -- Blank
				else
					hex1 <= "1000000"; -- 0
				end if;
				
			when "0001" =>
				hex1 <= "1111001"; -- 1
				
			when "0010" =>
				hex1 <= "0100100"; -- 2
				
			when "0011" =>
				hex1 <= "0110000"; -- 3
				
			when "0100" =>
				hex1 <= "0011001"; -- 4
				
			when "0101" =>
				hex1 <= "0010010"; -- 5
				
			when "0110" =>
				hex1 <= "0000010"; -- 6
			
			when "0111" => 
				hex1 <= "1111000"; -- 7
				
			when "1000" => 
				hex1 <= "0000000"; -- 8
			
			when "1001" => 
				hex1 <= "0011000"; -- 9
				
			when others =>
				hex1 <= "0111111"; -- -
		end case;
		case  bcd_ones is
			when "0000" =>
				hex0 <= "1000000"; -- 0
		
			when "0001" =>
				hex0 <= "1111001"; -- 1
				
			when "0010" =>
				hex0 <= "0100100"; -- 2
				
			when "0011" =>
				hex0 <= "0110000"; -- 3
				
			when "0100" =>
				hex0 <= "0011001"; -- 4
				
			when "0101" =>
				hex0 <= "0010010"; -- 5
				
			when "0110" =>
				hex0 <= "0000010"; -- 6
			
			when "0111" => 
				hex0 <= "1111000"; -- 7
				
			when "1000" => 
				hex0 <= "0000000"; -- 8
			
			when "1001" => 
				hex0 <= "0011000"; -- 9
				
			when others =>
				hex0 <= "0111111"; -- -
		end case;
	end if;
end process bcd_to_7seg;

binary_to_BCD : process(duty_cycle_update,reset,reset_n,clk,dc_value)
	variable BCD 			: unsigned(11 downto 0):="000000000000";
	variable input			: unsigned(7 downto 0):="00000000";
	--Constants used to compare and add
	variable addThree		: unsigned(3 downto 0):="0011";
	variable compareFour	: unsigned(3 downto 0):="0100";
	begin
	-- Initial values
		input := unsigned(dc_value);
		BCD(11 downto 0) := "000000000000";
		addThree := "0011";
		compareFour := "0100";
		
		if(reset = '1' or reset_n ='0') then
			valid_out <= false;
			ready <= '1';
		elsif(rising_edge(clk)) then
			if(duty_cycle_update = '1') then
				ready <='0';
				for I in 0 to 7 loop
				-- Shift bits
					BCD(11 downto 1) := BCD(10 downto 0); 
					BCD(0) := input(7);
					input(7 downto 1) := input(6 downto 0);
					input(0) := '0';
					
					-- If  BCD digit is greater than 4 add 3
					if(I<7 and BCD(3 downto 0) > compareFour ) then 
						BCD(3 downto 0) := BCD(3 downto 0) + addThree;
					end if;
					-- If BCD digit is greater than 4 add 3
					if(I<7 and BCD(7 downto 4) > compareFour) then 
						BCD(7 downto 4) := BCD(7 downto 4) + addThree;
					end if;
					-- If BCD digit is greater than 4 add 3
					if(I<7 and BCD(11 downto 8) > compareFour) then 
						BCD(11 downto 8) := BCD(11 downto 8) + addThree;
					end if;
				end loop;
				-- enter new digits into BCD digits and set flag for transmission
				bcd_ones(3 downto 0) <= BCD(3 downto 0);
				bcd_tens(3 downto 0) <= BCD(7 downto 4);
				bcd_hundreds(3 downto 0) <= BCD(11 downto 8);
				valid_out <= true;
				ready <='1';
				else 
				valid_out <= false;
			end if;
		end if;
	end process;

end architecture seg_control;

