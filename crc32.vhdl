LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY CRC32_Calculator IS
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        bit_in : IN STD_LOGIC;
        data_valid : IN STD_LOGIC;
        done : IN STD_LOGIC;
        crc_ok : OUT STD_LOGIC;
        remainder : BUFFER STD_LOGIC_VECTOR (32 DOWNTO 0)
    );
END CRC32_Calculator;

ARCHITECTURE RTL OF CRC32_Calculator IS

    -- CRC-32 Polynomial: 0x104C11DB7
    CONSTANT GENERATOR : STD_LOGIC_VECTOR(32 DOWNTO 0) := "100000100110000010001110110110111"; -- 0x104C11DB7

    -- Internal signal to store CRC check result
    SIGNAL valid_crc : STD_LOGIC := '0';

BEGIN
    PROCESS (clk)
        VARIABLE next_rem : STD_LOGIC_VECTOR(32 DOWNTO 0); -- Next value of the remainder
    BEGIN
        IF rising_edge(clk) THEN

            -- Reset condition: clear the remainder and CRC flag
            IF reset = '1' THEN
                remainder <= "000000000000000000000000000000000";
                valid_crc <= '0';

                -- While receiving valid data bits
            ELSIF data_valid = '1' THEN
                -- Shift in the new bit to the remainder
                next_rem := remainder(31 DOWNTO 0) & bit_in;

                -- If MSB is 1, perform XOR with the generator polynomial
                IF remainder(31) = '1' THEN
                    next_rem := next_rem XOR GENERATOR;
                END IF;

                -- Update the remainder
                remainder <= next_rem;
                valid_crc <= '0';

                -- When transmission is done, check if remainder is all zeros
            ELSIF done = '1' THEN
                IF remainder(31 DOWNTO 0) = "00000000000000000000000000000000" THEN
                    valid_crc <= '1'; -- CRC is correct
                ELSE
                    valid_crc <= '0'; -- CRC failed
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Assign the CRC status output
    crc_ok <= valid_crc;

END RTL;