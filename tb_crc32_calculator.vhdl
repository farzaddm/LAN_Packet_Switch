LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_crc32_calculator IS
END tb_crc32_calculator;

ARCHITECTURE sim OF tb_crc32_calculator IS

    COMPONENT CRC32_Calculator
        PORT (
            clk : IN STD_LOGIC;
            reset : IN STD_LOGIC;
            bit_in : IN STD_LOGIC;
            data_valid : IN STD_LOGIC;
            done : IN STD_LOGIC;
            crc_ok : OUT STD_LOGIC;
            remainder : BUFFER STD_LOGIC_VECTOR (32 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    SIGNAL bit_in : STD_LOGIC := '0';
    SIGNAL data_valid : STD_LOGIC := '0';
    SIGNAL done : STD_LOGIC := '0';
    SIGNAL crc_ok : STD_LOGIC;
    SIGNAL remainder : STD_LOGIC_VECTOR (32 DOWNTO 0);

    CONSTANT full_stream : STD_LOGIC_VECTOR(90 DOWNTO 0) :=
    "1001000010000010010010001000101101010110001111111110000011100100000001110111010001101101101";

    CONSTANT clk_period : TIME := 10 ns;

BEGIN

    -- Instantiate the CRC32 checker
    uut : CRC32_Calculator
    PORT MAP(
        clk => clk,
        reset => reset,
        bit_in => bit_in,
        data_valid => data_valid,
        done => done,
        crc_ok => crc_ok,
        remainder => remainder
    );

    -- Clock generation
    clk_process : PROCESS
    BEGIN
        WHILE NOW < 2000 ns LOOP
            clk <= '0';
            WAIT FOR clk_period / 2;
            clk <= '1';
            WAIT FOR clk_period / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    -- Stimulus process
    stim_proc : PROCESS
    BEGIN
        -- Initial reset
        WAIT FOR 20 ns;
        reset <= '1';
        WAIT FOR clk_period;
        reset <= '0';

        -- Feed each bit with data_valid = '1'
        FOR i IN full_stream'RANGE LOOP
            bit_in <= full_stream(i);
            data_valid <= '1';
            WAIT FOR clk_period;
        END LOOP;

        -- Data finished, assert 'done'
        data_valid <= '0';
        bit_in <= '0';
        done <= '1';
        WAIT FOR clk_period;

        done <= '0';
        WAIT FOR 50 ns;

        WAIT;
    END PROCESS;

END sim;