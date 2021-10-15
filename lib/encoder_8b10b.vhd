-----------------------------------
--
-- encoder 8b10b.vhd
--
-----------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.defs.all;



entity encoder_8b10b is port(
	clock:			in		std_logic;
	rd_reset:		in		std_logic;
	din:				in 	std_logic_vector(7 downto 0);
	din_valid:		in		std_logic;
	kin:				in		std_logic;
	dout:				out 	std_logic_vector(9 downto 0);
	dout_valid:		out 	std_logic;
	rd_out:			out	integer
);
end encoder_8b10b;


architecture vhdl of encoder_8b10b is








begin




ENCODER: process(clock)

type enc_3b4b_type is record
	data	:	std_logic_vector(0 to 3);
	disp	:	std_logic;
	dout	:	std_logic_vector(3 downto 0);	
end record;


type enc_5b6b_type is record
	data	:	std_logic_vector(0 to 5);
	disp	:	std_logic;
	dout	:	std_logic_vector(5 downto 0);
end record;

variable alt: std_logic;
variable s: std_logic_vector(0 to 9);
variable w: std_logic_vector(1 downto 0);
variable disp: integer;
variable rd: integer:= -1;
variable x: natural range 0 to 31;
variable y: natural range 0 to 7;
variable d4: enc_3b4b_type;
variable d6: enc_5b6b_type;
begin
	if (rising_edge(clock)) then
	
	
		if (rd_reset = '1') then rd := 0; end if;



		-- 8b10b control codes
		-------------------------------------------------

		if (kin = '1') then
		
			case din is
		
				when x"1C" => s := "0011110100"; disp := 0;
				when x"3C" => s := "0011111001"; disp := 2;
				when x"5C" => s := "0011110101"; disp := 2;
				when x"7C" => s := "0011110011"; disp := 2;
				when x"9C" => s := "0011110010"; disp := 0;
				when x"BC" => s := "0011111010"; disp := 2;
				when x"DC" => s := "0011110110"; disp := 2;
				when x"FC" => s := "0011111000"; disp := 0;
				when x"F7" => s := "1110101000"; disp := 0;
				when x"FB" => s := "1101101000"; disp := 0;
				when x"FD" => s := "1011101000"; disp := 0;
				when x"FE" => s := "0111101000"; disp := 0;
				when others => s := "0000000000";
		
			end case;
			
					
			if (rd > 0) then 	
				s := not s; 
				disp := -disp;
			end if;
			
			for i in 0 to 9 loop dout(i) <= s(i); end loop;			
		
		
		
		
		else			-- kin = 0  







			x := to_integer(unsigned(din(4 downto 0)));
			y := to_integer(unsigned(din(7 downto 5)));

		



		
			-- 3B4B encoder
			-------------------------------------------------
		
			alt := '0';
			if (rd < 0 and (x = 17 or x = 18 or x = 20)) then alt := '1'; end if;
			if (rd > 0 and (x = 11 or x = 13 or x = 14)) then alt := '1'; end if;

			case y is						
				when 0 => d4.data := "1011"; d4.disp := '1';
				when 1 => d4.data := "1001"; d4.disp := '0';
				when 2 => d4.data := "0101"; d4.disp := '0';
				when 3 => d4.data := "1100"; d4.disp := '0';
				when 4 => d4.data := "1101"; d4.disp := '1';
				when 5 => d4.data := "1010"; d4.disp := '0';
				when 6 => d4.data := "0110"; d4.disp := '0';
				when 7 => 	case alt is
									when '0' => d4.data := "1110"; d4.disp := '1';
									when '1' => d4.data := "0111"; d4.disp := '1';
								end case; 
							
			end case;	


		
			-- 5B6B encoder
			-------------------------------------------------
	
			case x is			
				when 0 => d6.data := "100111"; d6.disp := '1';
				when 1 => d6.data := "011101"; d6.disp := '1';
				when 2 => d6.data := "101101"; d6.disp := '1';
				when 3 => d6.data := "110001"; d6.disp := '0';
				when 4 => d6.data := "110101"; d6.disp := '1'; 
				when 5 => d6.data := "101001"; d6.disp := '0';
				when 6 => d6.data := "011001"; d6.disp := '0';  
				when 7 => d6.data := "111000"; d6.disp := '0'; 	
				when 8 => d6.data := "111001"; d6.disp := '1'; 	
				when 9 => d6.data := "100101"; d6.disp := '0';	
				when 10 => d6.data := "010101"; d6.disp := '0';	
				when 11 => d6.data := "110100"; d6.disp := '0'; 	
				when 12 => d6.data := "001101"; d6.disp := '0'; 	
				when 13 => d6.data := "101100"; d6.disp := '0'; 	
				when 14 => d6.data := "011100"; d6.disp := '0';	
				when 15 => d6.data := "010111"; d6.disp := '1'; 	
				when 16 => d6.data := "011011"; d6.disp := '1';	
				when 17 => d6.data := "100011"; d6.disp := '0';	
				when 18 => d6.data := "010011"; d6.disp := '0'; 	
				when 19 => d6.data := "110010"; d6.disp := '0'; 	
				when 20 => d6.data := "001011"; d6.disp := '0'; 	
				when 21 => d6.data := "101010"; d6.disp := '0'; 	
				when 22 => d6.data := "011010"; d6.disp := '0'; 	
				when 23 => d6.data := "111010"; d6.disp := '1'; 	
				when 24 => d6.data := "110011"; d6.disp := '1'; 	
				when 25 => d6.data := "100110"; d6.disp := '0'; 	
				when 26 => d6.data := "010110"; d6.disp := '0'; 	
				when 27 => d6.data := "110110"; d6.disp := '1'; 				
				when 28 => d6.data := "001110"; d6.disp := '0';
				when 29 => d6.data := "101110"; d6.disp := '1'; 	
				when 30 => d6.data := "011110"; d6.disp := '1'; 	
				when 31 => d6.data := "101011"; d6.disp := '1'; 	
			end case;	
	
	
	
			w := d4.disp & d6.disp;
		
		
			-- bit order correction
			for i in 0 to 3 loop d4.dout(i) := d4.data(i); end loop;			
			for i in 0 to 5 loop d6.dout(i) := d6.data(i); end loop;			


			if (rd < 0) then		-- positive disparity required (more ones than zeros) to restore balance
		
				case w is				
					when "00" => dout <=  d4.dout & d6.dout;			disp := 0;								
					when "01" => dout <=  d4.dout & d6.dout;			disp := 2;								
					when "10" => dout <=  d4.dout & d6.dout;			disp := 2;								
					when "11" => dout <=  d4.dout & (not d6.dout);	disp := 0;								
				end case;	
		
			else			-- negative disparity required (more zeros than ones) to restore balance
		
				case w is				
					when "00" => dout <=  d4.dout & d6.dout;			disp := 0;							
					when "01" => dout <=  d4.dout & (not d6.dout);	disp := -2;								
					when "10" => dout <=  (not d4.dout) & d6.dout;	disp := -2;								
					when "11" => dout <=  d4.dout & (not d6.dout);	disp := 0;								
				end case;
				
			end if;
					
		
		
		end if;
		
		
		-- calculate the running disparity (the number of ones transmitted minus the number of zeros transmitted)
		if (din_valid = '1') then rd := rd + disp; end if;
		
		
		dout_valid <= din_valid;
		rd_out <= rd;
			
	
	
	end if;
	
	
	
end process;



end vhdl;

