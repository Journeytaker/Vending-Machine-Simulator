library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dec_7seg is
  port (
    current_state : in  std_logic_vector(3 downto 0);
    segment_a,segment_b,segment_c,
    segment_d,segment_e,segment_f,
    segment_g      : out std_logic
  );
end entity;
architecture rtl of dec_7seg is
  signal segdata : std_logic_vector(6 downto 0);
begin
  process(current_state)
  begin
    case current_state is
      when "0000" => segdata <= "1111110"; -- 0
      when "0001" => segdata <= "0110000"; -- 1
      when "0010" => segdata <= "1101101"; -- 2
      when "0011" => segdata <= "1111001"; -- 3
      when "0100" => segdata <= "0110011"; -- 4
      when "0101" => segdata <= "1011011"; -- 5
      when "0110" => segdata <= "1011111"; -- 6
      when "0111" => segdata <= "1110000"; -- 7
      when "1000" => segdata <= "1111111"; -- 8
      when "1001" => segdata <= "1111011"; -- 9
      when "1010" => segdata <= "1100111"; -- P
      when "1011" => segdata <= "0010101"; -- n
      when "1100" => segdata <= "1001110"; -- C
      when "1101" => segdata <= "0111101"; -- D
      when "1110" => segdata <= "1001111"; -- E
      when "1111" => segdata <= "0000000"; -- blank
      when others => segdata <= "0111011"; -- H
    end case;
  end process;
  -- invert for common-anode
  segment_a <= not segdata(6);
  segment_b <= not segdata(5);
  segment_c <= not segdata(4);
  segment_d <= not segdata(3);
  segment_e <= not segdata(2);
  segment_f <= not segdata(1);
  segment_g <= not segdata(0);
end architecture rtl;
