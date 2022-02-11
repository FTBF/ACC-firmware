---------------------------------------------------------------------------------
-- FILE:         synchronizer.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  used to transfer valid signals from one clock domain to another
--                note that valid_in must not be high for two consecutive  
--                clock cycles
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;


entity pulseSync is
   port (
      inClock	    : in std_logic;
		outClock     : in std_logic;
		din_valid	 : in	std_logic;       
      dout_valid   : out std_logic);
		
end pulseSync;

architecture vhdl of pulseSync is
   
   signal sync_latch : std_logic;
   signal sync_latch_z : std_logic;
   signal sync_reset : std_logic;
   signal valid_in_z : std_logic;
	
begin	


------------------------------------
--	DATA SYNCHRONIZER
------------------------------------


-- Purpose is to take a single 'data valid' pulse in from one clock domain,
-- and forward it to another clock domain also as a single pulse
--
-- assumptions
-- 1. Data in and valid in will arrive on rising edge of clock in
-- 2. data_in will remain unchanged until a new din valid appears
-- 3. there will never be two consecutive 1's on valid in


FALLING_EDGE_DETECT: process(inClock)
--latch valid_in on the falling edge of clock in
--
-- This gives a safeguard that there is some delay between valid in rising 
-- and the output clock clocking the data, thus ensuring the clock out
-- does not rise before the data is present at the input
begin
   if (falling_edge(inClock)) then
      valid_in_z <= din_valid;
   end if;
end process;


-- detect rising edge on valid in
RISING_EDGE_DETECT: process(valid_in_z, sync_reset)
begin
   if (sync_reset = '1') then 
      sync_latch <= '0';
   elsif (rising_edge(valid_in_z)) then
      sync_latch <= '1';  
   end if;
end process;


-- clock the data and valid out using the out clock
-- and reset the latch
VALID_DATA_OUT: process(outClock)
begin
   if (rising_Edge(OutClock)) then
      sync_latch_z <= sync_latch; 
   elsif (falling_edge(OutClock)) then
      sync_reset <= sync_latch_z;
   end if;
end process;
   
dout_valid <= sync_latch_z; 
 
end vhdl;





library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;
use work.components.all;


entity pulseSync2 is
  Generic(
    RESET_VAL : std_logic := '0'
    );
  Port(
    src_clk     : in std_logic;
    src_pulse   : in std_logic;
    src_aresetn : in std_logic;

    dest_clk     : in std_logic;
    dest_pulse   : out std_logic;
    dest_aresetn : in std_logic);
end pulseSync2;

architecture vhdl of pulseSync2 is
  signal src_pulse_1 : std_logic;
  signal src_pulse_2 : std_logic_vector(0 downto 0);
  
  signal dest_pulse_1 : std_logic_vector(0 downto 0);
  signal dest_pulse_2 : std_logic;  

  component sync_Bits_Altera is
    generic (
      BITS       : positive;
      INIT       : std_logic_vector;
      SYNC_DEPTH : natural range 2 to 5);
    port (
      Clock  : in  std_logic;
      Input  : in  std_logic_vector(BITS - 1 downto 0);
      Output : out std_logic_vector(BITS - 1 downto 0));
  end component sync_Bits_Altera;
begin
  
  -- src clock domain edge detection
  src_clk_domain : process(src_clk, src_aresetn)
  begin
    if src_aresetn = '0' then
      src_pulse_1 <= '0';
      src_pulse_2 <= "0";
    else
      if rising_Edge(src_clk) then
        src_pulse_1 <= src_pulse;
        src_pulse_2(0) <= (src_pulse and not src_pulse_1) xor src_pulse_2(0);
      end if;
    end if;
  end process;

  sync_Bits_Altera_1: entity work.sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => "0000",
      SYNC_DEPTH => 2)
    port map (
      Clock  => dest_clk,
      Input  => src_pulse_2,
      Output => dest_pulse_1);

  dest_clk_domain : process(dest_clk, dest_aresetn)
  begin
    if dest_aresetn = '0' then
      dest_pulse_2 <= RESET_VAL;
      dest_pulse <= '0';
    else
      if rising_Edge(dest_clk) then
        dest_pulse_2 <= dest_pulse_1(0);
        dest_pulse <= dest_pulse_1(0) xor dest_pulse_2;
      end if;
    end if;
  end process;
  
  
end vhdl;
  




library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;
use work.components.all;
use work.pulseSync2;

entity param_handshake_sync is
  generic (
    WIDTH : natural
  );
  port (
    src_clk : in std_logic;
    src_params : in std_logic_vector(WIDTH-1 downto 0);
    src_aresetn : in std_logic;

    dest_clk : in std_logic;
    dest_params : out std_logic_vector(WIDTH-1 downto 0);
    dest_aresetn : in std_logic
  );
end entity param_handshake_sync;

architecture vhdl of param_handshake_sync is

  component pulseSync2 is
    Generic(
      RESET_VAL : std_logic := '0'
    );
    port (
      src_clk      : in  std_logic;
      src_pulse    : in  std_logic;
      src_aresetn  : in  std_logic;
      dest_clk     : in  std_logic;
      dest_pulse   : out std_logic;
      dest_aresetn : in  std_logic);
  end component pulseSync2;

  signal src_params_latch : std_logic_vector(WIDTH-1 downto 0);
  signal src_latch        : std_logic;
  signal src_latch_sync   : std_logic;
  signal dest_latch       : std_logic;
  signal dest_latch_sync  : std_logic;

begin

  src2dest_sync : pulseSync2
  port map (
    src_clk      => src_clk,
    src_pulse    => src_latch,
    src_aresetn  => src_aresetn,
    dest_clk     => dest_clk,
    dest_pulse   => src_latch_sync,
    dest_aresetn => dest_aresetn
  );
  
  dest2src_sync : pulseSync2
  generic map (
    RESET_VAL => '1'
    )
  port map (
    src_clk      => dest_clk,
    src_pulse    => dest_latch,
    src_aresetn  => dest_aresetn,
    dest_clk     => src_clk,
    dest_pulse   => dest_latch_sync,
    dest_aresetn => src_aresetn
  );

  src_clk_domain : process(src_clk, src_aresetn)
  begin
    if src_aresetn = '0' then
      src_params_latch <= (others => '0');
      src_latch <= '0';
    else
      if rising_Edge(src_clk) then
        if dest_latch_sync = '1' then
          src_params_latch <= src_params;
          src_latch <= '1';
        else
          src_params_latch <= src_params_latch;
          src_latch <= '0';
        end if;
      end if;
    end if;
  end process;    

  dest_clk_domain : process(dest_clk, dest_aresetn)
  begin
    if dest_aresetn = '0' then
      dest_latch <= '0';
      dest_params <= (others => '0');
    else
      if rising_Edge(dest_clk) then
        if src_latch_sync = '1' then
          dest_params <= src_params_latch;
          dest_latch <= '1';
        else
          dest_params <= dest_params;
          dest_latch <= '0';
        end if;
      end if;
    end if;
  end process;
  
end vhdl;  
  



library IEEE;
use     IEEE.STD_LOGIC_1164.all;

entity sync_Bits_Altera is
  generic (
    BITS          : positive            := 1;                       -- number of bit to be synchronized
    INIT          : std_logic_vector    := x"00000000";             -- initialization bits
    SYNC_DEPTH    : natural range 2 to 5 := 2                       -- generate SYNC_DEPTH many stages, at least 2
  );
  port (
    Clock         : in  std_logic;                                  -- <Clock>  output clock domain
    Input         : in  std_logic_vector(BITS - 1 downto 0);        -- @async:  input bits
    Output        : out std_logic_vector(BITS - 1 downto 0)         -- @Clock:  output bits
  );
end entity;


architecture rtl of sync_Bits_Altera is
	attribute PRESERVE          : boolean;
	attribute ALTERA_ATTRIBUTE  : string;

	-- Apply a SDC constraint to meta stable flip flop
	attribute ALTERA_ATTRIBUTE of rtl        : architecture is "-name SDC_STATEMENT ""set_false_path -to [get_registers {*sync_Bits_Altera:*|\gen:*:Data_meta}] """;
begin
	gen : for i in 0 to BITS - 1 generate
		signal Data_async        : std_logic;
		signal Data_meta        : std_logic                                    := INIT(i);
		signal Data_sync        : std_logic_vector(SYNC_DEPTH - 1 downto 0)    := (others => INIT(i));

		-- preserve both registers (no optimization, shift register extraction, ...)
		attribute PRESERVE of Data_meta            : signal is TRUE;
		attribute PRESERVE of Data_sync            : signal is TRUE;
		-- Notify the synthesizer / timing analysator to identity a synchronizer circuit
		attribute ALTERA_ATTRIBUTE of Data_meta    : signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED IF ASYNCHRONOUS""";
	begin
		Data_async  <= Input(i);

		process(Clock)
		begin
			if rising_edge(Clock) then
				Data_meta <= Data_async;
				Data_sync <= Data_sync(Data_sync'high - 1 downto 0) & Data_meta;
			end if;
		end process;

		Output(i)    <= Data_sync(Data_sync'high);
	end generate;
end architecture;
