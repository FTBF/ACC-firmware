--
-- DG LIB: BURST PULSER
--
library ieee; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.Numeric_Std.all;


Entity DG_Lib_Time_Window_Comp is
	port(
	
	
	--in
		clock:			in		std_logic;
		reset_counter:	in		std_logic;		
		window_start:	in		natural;
		window_length:	in		natural;


	--out

		output:			out		std_logic		
		
	);
end DG_Lib_Time_Window_Comp;



architecture vhdl of DG_Lib_Time_Window_Comp is


	constant MAX_COUNT:		natural:= 1000000000;
	
begin





WINDOW_COMPARE: process(clock)


variable	count:		natural;
variable	valid:		std_logic;

begin
	if (rising_edge(clock)) then
		
		
		if (reset_counter = '1') then 
		
			count := 0; 
			
		end if;
				
		
		
		valid := '1';
		
		
		if (count < window_start) then 
		
			valid := '0'; 
			
		end if;
		
		if (count >= (window_start +  window_length)) then 
		
			valid := '0'; 
			
		end if;
		
		
		if (valid = '0') then 
			output <= '0';
		else
			output <= '1';
		end if;
	
	
		if(count < MAX_COUNT) then 
		
			count := count + 1;
			
		end if;
	
	end if;
	
	
	
end process;
			




	

end vhdl;






































