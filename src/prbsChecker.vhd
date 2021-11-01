library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;


entity prbsChecker is
  port(
    clk   : in std_logic;
    reset : in std_logic;
    data  : in serialRx_hs_8bit_array;
    error_counts   :  out DoubleArray_16bit;
    count_reset    :  in std_logic
    );

end prbsChecker;


architecture vhdl of prbsChecker is

  signal data_SR : DoubleArray_16bit;
  signal next_pattern : DoubleArray_16bit;
  signal error_counts_z : DoubleArray_16bit;
  
begin  -- architecture vhdl

  error_counts <= error_counts_z;

  error_counter : process(clk)
  begin
    for i in 0 to 2*N-1 loop

      if rising_edge(clk) then
        if reset = '1' or count_reset = '1' then
          error_counts_z(i) <= X"0000";
        else
          data_SR(i) <= data_SR(i)(7 downto 0) & data(i);

          if data_SR(i)(7 downto 0) /= next_pattern(i)(7 downto 0) and unsigned(error_counts_z(i)) < x"FFFF" then
            error_counts_z(i) <= std_logic_vector(unsigned(error_counts_z(i)) + 1);
          end if;
        end if;
      end if;
      
    end loop;
  end process;

  prbsGen_loop : for i in 0 to 15 generate
    prbsGen: prbsGenerator
      generic map (
        ITERATIONS => 8,
        POLY       => X"6000")
      port map (
        clk    => clk,
        reset  => reset,
        input  => data_SR(i),
        output => next_pattern(i));
    end generate;

  
end architecture vhdl;
