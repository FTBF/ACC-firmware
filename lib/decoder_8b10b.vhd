-----------------------------------
--
-- decoder 8b10b.vhd
--
-----------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.defs.all;



entity decoder_8b10b is port(
	clock:			in		std_logic;
	rd_reset:		in		std_logic;
	din:				in 	std_logic_vector(9 downto 0);
	din_valid:		in		std_logic;
	kout:				out	std_logic;
	dout:				out 	std_logic_vector(7 downto 0);
	dout_valid:		out 	std_logic;
	rd_out:			out	integer;
	symbol_error:	out	std_logic
);
end decoder_8b10b;


architecture vhdl of decoder_8b10b is




begin




-------------------------------------------------
-- 8b10b DECODER
-------------------------------------------------
DECODER: process(clock)
variable w: std_logic_vector(0 to 9);
variable abcdei: std_logic_vector(0 to 5);
variable fghj: std_logic_vector(0 to 3);
variable err: std_logic;
variable d_err: std_logic;
variable k_err: std_logic;
variable rd: integer:= 0;
variable disp: integer range -10 to +10:= 0;
variable d4_disp: integer range -10 to +10:= 0;
variable d6_disp: integer range -10 to +10:= 0;
variable dx: natural range 0 to 31;
variable dy: natural range 0 to 7;
variable d3: std_logic_vector(2 downto 0);
variable d5: std_logic_vector(4 downto 0);
variable byte_k: std_logic_vector(7 downto 0);
begin
	if (rising_edge(clock)) then
	
	
		if (rd_reset = '1') then rd := 0; end if;
	
	
	
		-- bit order correction
		for i in 0 to 9 loop w(i) := din(i); end loop;				-- 10 bit symbol code
		for i in 0 to 3 loop fghj(i) := din(i + 6); end loop;		-- 4 bit upper sub-code
		for i in 0 to 5 loop abcdei(i) := din(i); end loop;		-- 6 bit lower sub-code	
	
		k_err := '0';
		d_err := '0';
		
	
	
		
		-- 8b10b control codes
		-------------------------------------------------

		case w is
		
			when "0011110100" => byte_k := x"1C";	disp := 0;
			when "0011111001" => byte_k := x"3C";	disp := 2;
			when "0011110101" => byte_k := x"5C";	disp := 2;
			when "0011110011" => byte_k := x"7C";	disp := 2;
			when "0011110010" => byte_k := x"9C";	disp := 0;
			when "0011111010" => byte_k := x"BC";	disp := 2;
			when "0011110110" => byte_k := x"DC";	disp := 2;
			when "0011111000" => byte_k := x"FC";	disp := 0;
			when "1110101000" => byte_k := x"F7";	disp := 0;
			when "1101101000" => byte_k := x"FB";	disp := 0;
			when "1011101000" => byte_k := x"FD";	disp := 0;
			when "0111101000" => byte_k := x"FE";	disp := 0;
			
			when "1100001011" => byte_k := x"1C";	disp := 0;
			when "1100000110" => byte_k := x"3C";	disp := -2;
			when "1100001010" => byte_k := x"5C";	disp := -2;
			when "1100001100" => byte_k := x"7C";	disp := -2;
			when "1100001101" => byte_k := x"9C";	disp := 0;
			when "1100000101" => byte_k := x"BC";	disp := -2;
			when "1100001001" => byte_k := x"DC";	disp := -2;
			when "1100000111" => byte_k := x"FC";	disp := 0;
			when "0001010111" => byte_k := x"F7";	disp := 0;
			when "0010010111" => byte_k := x"FB";	disp := 0;
			when "0100010111" => byte_k := x"FD";	disp := 0;
			when "1000010111" => byte_k := x"FE";	disp := 0;
			
			when others => k_err := '1';
		
		end case;


		
		-- 3B4B decoder
		-------------------------------------------------
	
		case fghj is							
			when "0001" => dy := 7;	d4_disp := -2;
			when "0010" => dy := 4;	d4_disp := -2;
			when "0011" => dy := 3;	d4_disp := 0;
			when "0100" => dy := 0;	d4_disp := -2;  
			when "0101" => dy := 2;	d4_disp := 0;
			when "0110" => dy := 6;	d4_disp := 0;
			when "0111" => dy := 7;	d4_disp := 2;
			when "1000" => dy := 7;	d4_disp := -2;  
			when "1001" => dy := 1;	d4_disp := 0;
			when "1010" => dy := 5;	d4_disp := 0;
			when "1011" => dy := 0;	d4_disp := 2;
			when "1100" => dy := 3;	d4_disp := 0;  
			when "1101" => dy := 4;	d4_disp := 2;
			when "1110" => dy := 7;	d4_disp := 2;
			when others => d_err := '1';
		end case;					
		
		

		-- 5B6B decoder
		-------------------------------------------------
	
		case abcdei is			
			when "000101" => dx := 23;	d6_disp := -2;
			when "000110" => dx := 8;	d6_disp := -2;
			when "000111" => dx := 7;	d6_disp := 0;
			when "001001" => dx := 27;	d6_disp := -2;
			when "001010" => dx := 4;	d6_disp := -2;
			when "001011" => dx := 20;	d6_disp := 0;
			when "001100" => dx := 24;	d6_disp := -2;  
			when "001101" => dx := 12;	d6_disp := 0;
			when "001110" => dx := 28;	d6_disp := 0;
			when "010001" => dx := 29;	d6_disp := -2;
			when "010010" => dx := 2;	d6_disp := -2;
			when "010011" => dx := 18;	d6_disp := 0;
			when "010100" => dx := 31;	d6_disp := -2;  
			when "010101" => dx := 10;	d6_disp := 0;
			when "010110" => dx := 26;	d6_disp := 0;
			when "010111" => dx := 15;	d6_disp := 2;
			when "011000" => dx := 0; 	d6_disp := -2; 
			when "011001" => dx := 6;	d6_disp := 0;
			when "011010" => dx := 22;	d6_disp := 0;
			when "011011" => dx := 16;	d6_disp := 2;
			when "011100" => dx := 14;	d6_disp := 0;  
			when "011101" => dx := 1;	d6_disp := 2;
			when "011110" => dx := 30;	d6_disp := 2;
			when "100001" => dx := 30;	d6_disp := -2;
			when "100010" => dx := 1;	d6_disp := -2;
			when "100011" => dx := 17;	d6_disp := 0;
			when "100100" => dx := 16;	d6_disp := -2;  
			when "100101" => dx := 9;	d6_disp := 0;
			when "100110" => dx := 25;	d6_disp := 0;
			when "100111" => dx := 0;	d6_disp := 2;
			when "101000" => dx := 15;	d6_disp := -2;  
			when "101001" => dx := 5;	d6_disp := 0;
			when "101010" => dx := 21;	d6_disp := 0;
			when "101011" => dx := 31;	d6_disp := 2;
			when "101100" => dx := 13;	d6_disp := 0;  
			when "101101" => dx := 2;	d6_disp := 2;
			when "101110" => dx := 29;	d6_disp := 2;
			when "110001" => dx := 3;	d6_disp := 0;
			when "110010" => dx := 19;	d6_disp := 0;
			when "110011" => dx := 24;	d6_disp := 2;
			when "110100" => dx := 11;	d6_disp := 0;  
			when "110101" => dx := 4;	d6_disp := 2;
			when "110110" => dx := 27;	d6_disp := 2;
			when "111000" => dx := 7; 	d6_disp := 0; 
			when "111001" => dx := 8;	d6_disp := 2;
			when "111010" => dx := 23;	d6_disp := 2;
			when others => d_err := '1';	
		end case;
		
		
		if (k_err = '0') then
	
			kout <= '1';
			dout <= byte_k;
			rd := rd + disp;
			err := '0';
				
		elsif (d_err = '0') then
			
			d3 := std_logic_vector(to_unsigned(dy,3));
			d5 := std_logic_vector(to_unsigned(dx,5));
			kout <= '0';
			dout <= d3 & d5;			-- concatenate the 3 bit and 5 bit decoded words to get the output byte
			rd := rd + d4_disp + d6_disp;
			err := '0';
									
		else
		
			kout <= '0';
			err := '1';
			disp := 0;
			
		end if;
	
		dout_valid <= din_valid and (not err);
		rd_out <= rd;
		symbol_error <= err;
	
	end if;
	
end process;



end vhdl;

