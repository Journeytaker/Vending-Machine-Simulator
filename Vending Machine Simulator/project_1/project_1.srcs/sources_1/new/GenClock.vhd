library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity GenClock is
    generic (time_period : integer range 1 to 4);
    port (clk   : in  std_logic;
          Clock : out std_logic);
end GenClock;
 
architecture Behavioral of GenClock is
    constant max_count: integer := 12500000 * (2**(time_period));
    signal count  : integer range 0 to max_count := 0;
    signal clk_out: std_logic := '0';
   
begin
    process(clk)
    begin
        if (clk'event and clk = '1') then
            if count = max_count then
                count <= 0;
                clk_out <= not clk_out;
            else
                count <= count + 1;
            end if;
        end if;
    end process;
   
    Clock <= clk_out;
   
end Behavioral;
