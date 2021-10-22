library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;
use work.LibDG.all;
use ieee.std_logic_misc.all;

entity prbsGenerator is
  Generic(
    ITERATIONS : natural := 1;
    POLY       : std_logic_vector(PRBS_WIDTH-1 downto 0) := X"6000"
    );
  Port(
    clk    : in  std_logic;
    reset  : in  std_logic;
    input  : in  std_logic_vector(PRBS_WIDTH-1 downto 0);
    output : out std_logic_vector(PRBS_WIDTH-1 downto 0)
    );
end entity prbsGenerator;

architecture vhdl of prbsGenerator is

  signal output_Z : std_logic_vector(PRBS_WIDTH-1 downto 0);
  
begin  -- architecture vhdl

  prbsGen : process(all)
    variable output_tmp : std_logic_vector(PRBS_WIDTH-1 downto 0);
  begin
    output_tmp := input;
    for iter in 0 to ITERATIONS - 1 loop
      output_tmp := output_tmp(PRBS_WIDTH-2 downto 0) & (xor_reduce(output_tmp and POLY));
    end loop;
    output_z <= output_tmp;
  end process;
  
  prbsLatch : process(clk)
    
  begin
    if rising_edge(clk) then
      if reset = '1' then
        output   <= X"0001";
      else
        output <= output_z;
      end if;
    end if;
  end process;

end architecture vhdl;
