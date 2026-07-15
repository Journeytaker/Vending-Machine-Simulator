library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity VendingMachineFSM is
  port (
    clk          : in  std_logic;
    btn_next     : in  std_logic;
    btn_prev     : in  std_logic;
    btn_select   : in  std_logic;
    btn_coin_a   : in  std_logic;
    btn_coin_s   : in  std_logic;
    AN0,AN1,AN2,AN3,AN4,AN5,AN6,AN7 : out std_logic;
    segment_a,segment_b,segment_c,
    segment_d,segment_e,segment_f,
    segment_g,segment_dp           : out std_logic
  );
end entity;

architecture top_level of VendingMachineFSM is

  type msg_t is array(0 to 7) of std_logic_vector(4 downto 0);
  type product_array_t is array(0 to 3) of msg_t;
  type accumulator_array_t is array(0 to 12) of msg_t;

  constant product_messages : product_array_t := (
    ("10101","00011","11111","00010","01111","01011","11111","11111"), --'P1 1.75'
    ("10101","00101","11111","00000","01101","01011","11111","11111"), --'P2 0.65'
    ("10101","00111","11111","00100","01001","00111","11111","11111"), --'P3 2.43'
    ("11011","00011","01011","10101","11101","10111","01011","11101")   -- 'dispense'
  );

  constant PRICE_P1 : integer := 175;
  constant PRICE_P2 : integer := 65;
  constant PRICE_P3 : integer := 243;

  constant accumulator_messages : accumulator_array_t := (
    ("11111","11111","11111","11111","11111","00000","00001","00001"), -- 0.00
    ("11111","11111","11111","11111","11111","00000","00101","01011"), -- 0.25
    ("11111","11111","11111","11111","11111","00000","01011","00001"), -- 0.50
    ("11111","11111","11111","11111","11111","00000","01111","01011"), -- 0.75
    ("11111","11111","11111","11111","11111","00010","00001","00001"), -- 1.00
    ("11111","11111","11111","11111","11111","00010","00101","01011"), -- 1.25
    ("11111","11111","11111","11111","11111","00010","01011","00001"), -- 1.50
    ("11111","11111","11111","11111","11111","00010","01111","01011"), -- 1.75
    ("11111","11111","11111","11111","11111","00100","00001","00001"), -- 2.00
    ("11111","11111","11111","11111","11111","00100","00101","01011"), -- 2.25
    ("11111","11111","11111","11111","11111","00100","01011","00001"), -- 2.50
    ("11111","11111","11111","11111","11111","00100","01111","01011"), -- 2.75
    ("11111","11111","11111","11111","11111","00110","00001","00001")  -- 3.00
  );


  constant blank_message : msg_t := ("11111","11111","11111","11111","11111","11111","11111","11111");

  type vending_state is (
    idle_p1, idle_p2, idle_p3,
    insert_0, insert_25, insert_50, insert_75,
    insert_100, insert_125, insert_150, insert_175,
    insert_200, insert_225, insert_250, insert_275, insert_300,
    dispensing, change
  );

  signal current_state : vending_state := idle_p1;
  signal refresh_cnt : unsigned(11 downto 0) := (others => '0');
  constant REFRESH_LIMIT : unsigned(11 downto 0) := to_unsigned(4095,12);

  signal scan_idx : unsigned(2 downto 0) := (others => '0');
  signal cs_nibble : std_logic_vector(3 downto 0);
  signal dp_bit : std_logic;

  signal selected_price : integer range 0 to 300 := 0;
  signal money_inserted : integer range 0 to 300 := 0;

  signal btn_next_cnt, btn_prev_cnt, btn_select_cnt : unsigned(16 downto 0) := (others => '0');
  signal btn_coin_a_cnt, btn_coin_s_cnt : unsigned(16 downto 0) := (others => '0');
  constant BTN_THRESHOLD : unsigned(16 downto 0) := to_unsigned(80000, 17);

  signal clk_1sec : std_logic;
  signal display_message : msg_t;

  constant SEC : integer := 50000000; -- assuming 50 MHz clock
  signal dispensing_counter : unsigned(28 downto 0) := (others => '0');
  constant DISPENSING_TARGET : unsigned(28 downto 0) := to_unsigned(5 * SEC, 29);

  signal change_counter : unsigned(28 downto 0) := (others => '0');
  constant CHANGE_DURATION     : unsigned(28 downto 0) := to_unsigned(10 * SEC, 29);
  signal change_val : integer range 0 to 300 := 0;
  signal change_digits : msg_t;
  signal hundreds, tens, ones : integer range 0 to 9 := 0;
 
  function digit_with_dp(val : integer; dp : std_logic) return std_logic_vector is
    variable result : std_logic_vector(4 downto 0);
  begin
    result(4 downto 1) := std_logic_vector(to_unsigned(val, 4));
    result(0) := dp;
    return result;
  end function;

begin

  clk1_inst : entity work.GenClock generic map (time_period => 2) port map (clk, clk_1sec);

  process(clk)
  begin
    if rising_edge(clk) then

       -- Button debouncing and actions
      if btn_next = '1' then
        if btn_next_cnt < BTN_THRESHOLD then
          btn_next_cnt <= btn_next_cnt + 1;
        elsif btn_next_cnt = BTN_THRESHOLD then
          if current_state = idle_p1 then current_state <= idle_p2;
          elsif current_state = idle_p2 then current_state <= idle_p3;
          elsif current_state = idle_p3 then current_state <= idle_p1;
          end if;
          btn_next_cnt <= btn_next_cnt + 1;
        end if;
      else
        btn_next_cnt <= (others => '0');
      end if;

      if btn_prev = '1' then
        if btn_prev_cnt < BTN_THRESHOLD then
          btn_prev_cnt <= btn_prev_cnt + 1;
        elsif btn_prev_cnt = BTN_THRESHOLD then
          if current_state = idle_p1 then current_state <= idle_p3;
          elsif current_state = idle_p2 then current_state <= idle_p1;
          elsif current_state = idle_p3 then current_state <= idle_p2;
          end if;
          btn_prev_cnt <= btn_prev_cnt + 1;
        end if;
      else
        btn_prev_cnt <= (others => '0');
      end if;

      if btn_select = '1' then
        if btn_select_cnt < BTN_THRESHOLD then
          btn_select_cnt <= btn_select_cnt + 1;
        elsif btn_select_cnt = BTN_THRESHOLD then
          if current_state = idle_p1 then selected_price <= PRICE_P1; current_state <= insert_0; money_inserted <= 0;
          elsif current_state = idle_p2 then selected_price <= PRICE_P2; current_state <= insert_0; money_inserted <= 0;
          elsif current_state = idle_p3 then selected_price <= PRICE_P3; current_state <= insert_0; money_inserted <= 0;
          elsif current_state >= insert_0 and current_state <= insert_300 then
            if money_inserted >= selected_price then
              current_state <= dispensing;
              dispensing_counter <= (others => '0');
            end if;
          end if;
          btn_select_cnt <= btn_select_cnt + 1;
        end if;
      else
        btn_select_cnt <= (others => '0');
      end if;

      if btn_coin_a = '1' then
        if btn_coin_a_cnt < BTN_THRESHOLD then
          btn_coin_a_cnt <= btn_coin_a_cnt + 1;
        elsif btn_coin_a_cnt = BTN_THRESHOLD then
          if current_state >= insert_0 and current_state <= insert_300 then
            if money_inserted < 300 then
              money_inserted <= money_inserted + 25;
              if current_state /= insert_300 then
                current_state <= vending_state'succ(current_state);
              end if;
            end if;
          end if;
          btn_coin_a_cnt <= btn_coin_a_cnt + 1;
        end if;
      else
        btn_coin_a_cnt <= (others => '0');
      end if;

      if btn_coin_s = '1' then
        if btn_coin_s_cnt < BTN_THRESHOLD then
          btn_coin_s_cnt <= btn_coin_s_cnt + 1;
        elsif btn_coin_s_cnt = BTN_THRESHOLD then
          if current_state >= insert_0 and current_state <= insert_300 then
            if money_inserted > 0 then
              money_inserted <= money_inserted - 25;
              if current_state /= insert_0 then
                current_state <= vending_state'pred(current_state);
              end if;
            end if;
          end if;
          btn_coin_s_cnt <= btn_coin_s_cnt + 1;
        end if;
      else
        btn_coin_s_cnt <= (others => '0');
      end if;

      if current_state = dispensing then
        if clk_1sec = '1' then
          display_message <= product_messages(3);
        else
          display_message <= blank_message;
        end if;

        if dispensing_counter < DISPENSING_TARGET then
          dispensing_counter <= dispensing_counter + 1;
        else
          dispensing_counter <= (others => '0');
          change_val <= money_inserted - selected_price;
          change_counter <= (others => '0');
          hundreds <= (money_inserted - selected_price) / 100;
          tens     <= ((money_inserted - selected_price) mod 100) / 10;
          ones     <= (money_inserted - selected_price) mod 10;
          current_state <= change;
        end if;

      elsif current_state = change then
        if change_counter < CHANGE_DURATION then
          change_counter <= change_counter + 1;
        else
          change_counter <= (others => '0');
          current_state <= idle_p1;
        end if;

        change_digits(0) <= "11001"; -- 'C'
        change_digits(1) <= "11001"; -- 'C'
        change_digits(2) <= "10111"; -- 'n'
        change_digits(3) <= "01101"; -- 'G'
        change_digits(4) <= "11111"; -- blank
        change_digits(5) <= digit_with_dp(hundreds, '0'); -- decimal point ON
        change_digits(6) <= digit_with_dp(tens, '1');     -- decimal point OFF
        change_digits(7) <= digit_with_dp(ones, '1');     -- decimal point OFF

        display_message <= change_digits;

      else
        case current_state is
          when idle_p1 => display_message <= product_messages(0);
          when idle_p2 => display_message <= product_messages(1);
          when idle_p3 => display_message <= product_messages(2);
          when insert_0 => display_message <= accumulator_messages(0);
          when insert_25 => display_message <= accumulator_messages(1);
          when insert_50 => display_message <= accumulator_messages(2);
          when insert_75 => display_message <= accumulator_messages(3);
          when insert_100 => display_message <= accumulator_messages(4);
          when insert_125 => display_message <= accumulator_messages(5);
          when insert_150 => display_message <= accumulator_messages(6);
          when insert_175 => display_message <= accumulator_messages(7);
          when insert_200 => display_message <= accumulator_messages(8);
          when insert_225 => display_message <= accumulator_messages(9);
          when insert_250 => display_message <= accumulator_messages(10);
          when insert_275 => display_message <= accumulator_messages(11);
          when insert_300 => display_message <= accumulator_messages(12);
          when others => null;
        end case;
      end if;

      if refresh_cnt = REFRESH_LIMIT then
        refresh_cnt <= (others => '0');
        scan_idx <= scan_idx + 1;
      else
        refresh_cnt <= refresh_cnt + 1;
      end if;

      cs_nibble <= display_message(to_integer(scan_idx))(4 downto 1);
      dp_bit    <= display_message(to_integer(scan_idx))(0);

    end if;
  end process;

  AN7 <= '0' when scan_idx = "000" else '1';
  AN6 <= '0' when scan_idx = "001" else '1';
  AN5 <= '0' when scan_idx = "010" else '1';
  AN4 <= '0' when scan_idx = "011" else '1';
  AN3 <= '0' when scan_idx = "100" else '1';
  AN2 <= '0' when scan_idx = "101" else '1';
  AN1 <= '0' when scan_idx = "110" else '1';
  AN0 <= '0' when scan_idx = "111" else '1';

  segment_dp <= dp_bit;

  dec7 : entity work.dec_7seg
    port map (
      current_state => cs_nibble,
      segment_a     => segment_a,
      segment_b     => segment_b,
      segment_c     => segment_c,
      segment_d     => segment_d,
      segment_e     => segment_e,
      segment_f     => segment_f,
      segment_g     => segment_g
    );

end architecture top_level;