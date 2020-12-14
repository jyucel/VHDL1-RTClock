--------------------------------------
-- Filename 	:RTClock.vhd
-- File type	:VHDL
-- Date			:2020-12-1
-- Description	:Extrauppgift för VHDL Kurs1 uppgift 7-10
-- Author		:John Yucel, john@yucel.se
-- Error		:None
--	Version		:0.1
-- History 		:Initial 
-- -----------------------------
-- Version   	| Author    | Comment                     
--	----------------------------- 
-- 0.1    		| Yucel, John | Initial version. 
-- 0.2          | Yucel, John | * Modified DP - Now it is set in an individual vector for all LED (5 downt 0)
--                              * Added functionality to change time. When Switch (8) is active key1 will choose hours or minutes. 
--                                2 DP under the LEDs will indicate which number to change ex h.h.mm00 will indicate that hh can be changed. By pressing key2 the number will Increase
--                                Seconds are set to 00 during time adjustment. When done set set sw(8) to false. DP will now show hh.mm.ss
--                              * Added delay (3 clock signals) on in each input to prevent (minimize) debounce 
-- 0.3         | Yucel, John  | * Removed 1 flipflop from input signals.
--                              * Cleaned up major bug in code regarding sync process
-- Description
------------------
-- RTClock is a Real Time Clock
--
--  Conditions
------------------
-- SW(9) pressed     --> Resetn. Sets the counter to 0. LED Dipslay can be preset to a predefined time
-- 50MHz system clock 
-- 

-- Things that I would like to add
------------------------------------
-- Set time (DONE)
-- Maybe set an alarm

--------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY RTClock IS
    PORT (
        clk        : IN STD_LOGIC;
        reset_n    : IN STD_LOGIC;
        time_set_n : IN STD_LOGIC;
        key1       : IN STD_LOGIC;
        key2       : IN STD_LOGIC;

        -- Time presentation hh.mm.ss, ex 13.45.10

        -- Seconds 00-59
        LED_S1     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- 2 digit seconds 0 -> 9
        LED_S2     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- 2 digit seconds 0->5 

        -- Minutes 00-59 
        LED_M1     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- 2 digit minutes 0->9 
        LED_M2     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- 7 segment display 0->5

        -- Hours 00-23
        LED_H1     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- 7 segment display 0->9
        LED_H2     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- 7 segment display 0 ->2

        -- DP 
        LED_DP     : OUT STD_LOGIC_VECTOR(5 DOWNTO 0)  -- DP on LEDs
    );
END ENTITY;

ARCHITECTURE rtl OF RTClock IS
    SIGNAL counter_value            : UNSIGNED (2 DOWNTO 0);
    SIGNAL clock_div                : UNSIGNED (25 DOWNTO 0);
    SIGNAL seconds                  : UNSIGNED (5 DOWNTO 0);
    SIGNAL minutes                  : UNSIGNED (5 DOWNTO 0);
    SIGNAL hours                    : UNSIGNED (4 DOWNTO 0);
    SIGNAL t_counter                : UNSIGNED(1 DOWNTO 0);

    SIGNAL DP                       : STD_LOGIC_VECTOR (5 DOWNTO 0);

    CONSTANT DIGIT_0                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"1000000"; --  0
    CONSTANT DIGIT_1                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"1111001"; --  1
    CONSTANT DIGIT_2                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0100100"; --  2
    CONSTANT DIGIT_3                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0110000"; --  3
    CONSTANT DIGIT_4                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0011001"; --  4
    CONSTANT DIGIT_5                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0010010"; --  5
    CONSTANT DIGIT_6                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0000010"; --  6
    CONSTANT DIGIT_7                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"1111000"; --  7
    CONSTANT DIGIT_8                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0000000"; --  8
    CONSTANT DIGIT_9                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0011000"; --  9

    CONSTANT DIGIT_E                : STD_LOGIC_VECTOR(6 DOWNTO 0) := b"0000110"; --  E for Error. hopefully will never occur
    SIGNAL RESET_t1, reset_t2       : STD_LOGIC;
    SIGNAL time_set_t1, time_set_t2 : STD_LOGIC;
    SIGNAL KEY1_t1, KEY1_t2         : STD_LOGIC;
    SIGNAL KEY2_t1, KEY2_t2         : STD_LOGIC;
BEGIN

    reset_process : PROCESS (clk, reset_n)
    BEGIN
        IF reset_n = '0' THEN
            reset_t1 <= '0';
            reset_t2 <= '0';
        ELSIF rising_edge(clk) THEN
            reset_t1 <= reset_n;
            reset_t2 <= reset_t1;
        END IF;
    END PROCESS;

    time_set_process : PROCESS (clk, reset_t2)
    BEGIN
        IF reset_t2 = '0' THEN
            time_set_t1 <= '1';
            time_set_t2 <= '1';
        ELSIF rising_edge(clk) THEN
            time_set_t1 <= time_set_n;
            time_set_t2 <= time_set_t1;

        END IF;
    END PROCESS;

    key1_process : PROCESS (clk, reset_t2)
    BEGIN
        IF reset_t2 = '0' THEN
            Key1_t1 <= '1';
            Key1_t2 <= '1';
        ELSIF rising_edge(clk) THEN
            Key1_t1 <= key1;
            Key1_t2 <= Key1_t1;

        END IF;
    END PROCESS;

    key2_process : PROCESS (clk, reset_t2) --  key
    BEGIN
        IF reset_t2 = '0' THEN
            Key2_t1 <= '1';
            Key2_t2 <= '1';

        ELSIF rising_edge(clk) THEN
            Key2_t1 <= key2;
            Key2_t2 <= Key2_t1;

        END IF;
    END PROCESS;

    dp_counter : PROCESS (clk, reset_t2)
        VARIABLE dp_pos : unsigned(0 DOWNTO 0) := "0";
    BEGIN
        IF reset_t2 = '0' THEN
            dp_pos := b"0";
        ELSIF rising_edge(clk) THEN
            IF time_set_t2 = '0' THEN
                IF key1_t2 = '0' AND key1_t1 = '1' THEN
                    dp_pos := dp_pos + 1;
                    IF dp_pos = "0" THEN
                        dp <= b"001111";
                    ELSIF dp_pos = "1" THEN
                        dp <= b"110011";
                    END IF;
                END IF;
            END IF;
            IF reset_t2 = '1' THEN
                IF time_set_t2 = '1' THEN
                    dp <= b"101011";
                END IF;
            END IF;
        END IF;
    END PROCESS;
    -----------------------------------------
    --
    --  Time 
    --
    -----------------------------------------
    counter_process : PROCESS (clk, reset_t2)
    BEGIN
        IF reset_t2 = '0' THEN
            clock_div <= (OTHERS => '0');
            seconds   <= (OTHERS => '0');
            --minutes       <= (OTHERS => '0');
            --hours         <= (OTHERS => '0');
            ----------------------------
            -- Preset time
            -- Time is set to 20:10:00
            minutes   <= "001010";
            hours     <= "10100";
        ELSIF rising_edge(clk) THEN
            IF time_set_t2 = '1' THEN
                -- IF clock_div = "0000000000000000000000000100" THEN -- Use for Modelsim 
                IF clock_div = "0010111110101111000010000000" THEN -- 1 second has passed. Equals to 50 000 0000 (1s)
                    clock_div <= (OTHERS => '0');                      -- reset clock counter
                    IF seconds = "111011" THEN                         -- 59 seconds 
                        seconds <= (OTHERS => '0');
                        IF minutes = "111011" THEN -- 59 minutes 
                            minutes <= (OTHERS => '0');
                            IF hours = "10111" THEN -- 23 hours
                                hours <= (OTHERS => '0');
                            ELSE
                                hours <= hours + 1;
                            END IF;
                        ELSE
                            minutes <= minutes + 1;
                        END IF;
                    ELSE
                        seconds <= seconds + 1;
                    END IF;
                ELSE
                    clock_div <= clock_div + 1;
                END IF;
            END IF;

            IF time_set_t2 = '0' THEN
                seconds <= (OTHERS => '0'); -- Always set seconds to 00 when adjusting time, ie seconds should not be adjusted
                IF Key2_t2 = '0' AND key2_t1 = '1' THEN
                    IF dp = b"001111" THEN                       --  hr
                        IF hours = b"00000" OR hours < b"10111" THEN -- if hours is between 0 and 22 (dec) then we can can increase with 1
                            hours <= hours + 1;
                        ELSE
                            hours <= b"00000";
                        END IF;
                    END IF;
                    IF dp = b"110011" THEN                            --  min
                        IF minutes = b"00000" OR minutes < b"111011" THEN -- if minutes is between 0 and 58 (dec) then we can can increase with 1
                            minutes <= minutes + 1;
                        ELSE
                            minutes <= b"000000";
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -------------------------------------------
    --
    -- LED DISPLAY 
    --
    -------------------------------------------
    WITH seconds SELECT LED_S1 <=
        DIGIT_0 WHEN b"000000" | b"001010" | b"010100" | b"011110" | b"101000" | b"110010",
        DIGIT_1 WHEN b"000001" | b"001011" | b"010101" | b"011111" | b"101001" | b"110011",
        DIGIT_2 WHEN b"000010" | b"001100" | b"010110" | b"100000" | b"101010" | b"110100",
        DIGIT_3 WHEN b"000011" | b"001101" | b"010111" | b"100001" | b"101011" | b"110101",
        DIGIT_4 WHEN b"000100" | b"001110" | b"011000" | b"100010" | b"101100" | b"110110",
        DIGIT_5 WHEN b"000101" | b"001111" | b"011001" | b"100011" | b"101101" | b"110111",
        DIGIT_6 WHEN b"000110" | b"010000" | b"011010" | b"100100" | b"101110" | b"111000",
        DIGIT_7 WHEN b"000111" | b"010001" | b"011011" | b"100101" | b"101111" | b"111001",
        DIGIT_8 WHEN b"001000" | b"010010" | b"011100" | b"100110" | b"110000" | b"111010",
        DIGIT_9 WHEN b"001001" | b"010011" | b"011101" | b"100111" | b"110001" | b"111011",
        DIGIT_E WHEN OTHERS;

    WITH seconds SELECT LED_S2 <=
        DIGIT_0 WHEN "000000" | b"000001" | b"000010" | b"000011" | b"000100" | b"000101" | b"000110" | b"000111" | b"001000" | b"001001",
        DIGIT_1 WHEN "001010" | b"001011" | b"001100" | b"001101" | b"001110" | b"001111" | b"010000" | b"010001" | b"010010" | b"010011",
        DIGIT_2 WHEN "010100" | b"010101" | b"010110" | b"010111" | b"011000" | b"011001" | b"011010" | b"011011" | b"011100" | b"011101",
        DIGIT_3 WHEN "011110" | b"011111" | b"100000" | b"100001" | b"100010" | b"100011" | b"100100" | b"100101" | b"100110" | b"100111",
        DIGIT_4 WHEN "101000" | b"101001" | b"101010" | b"101011" | b"101100" | b"101101" | b"101110" | b"101111" | b"110000" | b"110001",
        DIGIT_5 WHEN "110010" | b"110011" | b"110100" | b"110101" | b"110110" | b"110111" | b"111000" | b"111001" | b"111010" | b"111011",
        DIGIT_E WHEN OTHERS;

    WITH minutes SELECT LED_M1 <=
        DIGIT_0 WHEN b"000000" | b"001010" | b"010100" | b"011110" | b"101000" | b"110010",
        DIGIT_1 WHEN b"000001" | b"001011" | b"010101" | b"011111" | b"101001" | b"110011",
        DIGIT_2 WHEN b"000010" | b"001100" | b"010110" | b"100000" | b"101010" | b"110100",
        DIGIT_3 WHEN b"000011" | b"001101" | b"010111" | b"100001" | b"101011" | b"110101",
        DIGIT_4 WHEN b"000100" | b"001110" | b"011000" | b"100010" | b"101100" | b"110110",
        DIGIT_5 WHEN b"000101" | b"001111" | b"011001" | b"100011" | b"101101" | b"110111",
        DIGIT_6 WHEN b"000110" | b"010000" | b"011010" | b"100100" | b"101110" | b"111000",
        DIGIT_7 WHEN b"000111" | b"010001" | b"011011" | b"100101" | b"101111" | b"111001",
        DIGIT_8 WHEN b"001000" | b"010010" | b"011100" | b"100110" | b"110000" | b"111010",
        DIGIT_9 WHEN b"001001" | b"010011" | b"011101" | b"100111" | b"110001" | b"111011",
        DIGIT_E WHEN OTHERS;

    WITH minutes SELECT LED_M2 <=
        DIGIT_0 WHEN b"000000" | b"000001" | b"000010" | b"000011" | b"000100" | b"000101" | b"000110" | b"000111" | b"001000" | b"001001",
        DIGIT_1 WHEN b"001010" | b"001011" | b"001100" | b"001101" | b"001110" | b"001111" | b"010000" | b"010001" | b"010010" | b"010011",
        DIGIT_2 WHEN b"010100" | b"010101" | b"010110" | b"010111" | b"011000" | b"011001" | b"011010" | b"011011" | b"011100" | b"011101",
        DIGIT_3 WHEN b"011110" | b"011111" | b"100000" | b"100001" | b"100010" | b"100011" | b"100100" | b"100101" | b"100110" | b"100111",
        DIGIT_4 WHEN b"101000" | b"101001" | b"101010" | b"101011" | b"101100" | b"101101" | b"101110" | b"101111" | b"110000" | b"110001",
        DIGIT_5 WHEN b"110010" | b"110011" | b"110100" | b"110101" | b"110110" | b"110111" | b"111000" | b"111001" | b"111010" | b"111011",
        DIGIT_E WHEN OTHERS;

    WITH hours SELECT LED_h1 <=
        DIGIT_0 WHEN b"00000" | b"01010" | b"10100",
        DIGIT_1 WHEN b"00001" | b"01011" | b"10101",
        DIGIT_2 WHEN b"00010" | b"01100" | b"10110",
        DIGIT_3 WHEN b"00011" | b"01101" | b"10111",
        DIGIT_4 WHEN b"00100" | b"01110" | b"11000",
        DIGIT_5 WHEN b"00101" | b"01111" | b"11001",
        DIGIT_6 WHEN b"00110" | b"10000" | b"11010",
        DIGIT_7 WHEN b"00111" | b"10001" | b"11011",
        DIGIT_8 WHEN b"01000" | b"10010" | b"11100",
        DIGIT_9 WHEN b"01001" | b"10011" | b"11101",
        DIGIT_E WHEN OTHERS;

    WITH hours SELECT LED_h2 <=
        DIGIT_0 WHEN b"00000" | b"00001" | b"00010" | b"00011" | b"00100" | b"00101" | b"00110" | b"00111" | b"01000" | b"01001",
        DIGIT_1 WHEN b"01010" | b"01011" | b"01100" | b"01101" | b"01110" | b"01111" | b"10000" | b"10001" | b"10010" | b"10011",
        DIGIT_2 WHEN b"10100" | b"10101" | b"10110" | b"10111",

        DIGIT_E WHEN OTHERS;

    LED_DP <= DP;
END rtl;