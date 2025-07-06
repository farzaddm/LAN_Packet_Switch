LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity declaration for the packet handler module
ENTITY packet_handler IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        serial_input : IN STD_LOGIC;

        port1 : OUT STD_LOGIC;
        port2 : OUT STD_LOGIC;
        port3 : OUT STD_LOGIC;
        port4 : OUT STD_LOGIC;
        port5 : OUT STD_LOGIC;
        port6 : OUT STD_LOGIC;
        port7 : OUT STD_LOGIC;
        port8 : OUT STD_LOGIC;

        valid_output : OUT STD_LOGIC
    );
END packet_handler;

ARCHITECTURE behavior OF packet_handler IS

    -- FSM state declarations
    TYPE state_type IS (
        WAITING, READ_DEST, READ_SRC, READ_LEN, READ_DATA, READ_CRC, VERIFY_CRC, ROUTE_LOOKUP, SEND_DATA, DISCARD
    );
    SIGNAL curr_state : state_type := WAITING;

    -- Internal signal declarations
    SIGNAL bit_idx : INTEGER RANGE 0 TO 1024 := 0;
    SIGNAL dest_mac : STD_LOGIC_VECTOR(47 DOWNTO 0);
    SIGNAL src_mac : STD_LOGIC_VECTOR(47 DOWNTO 0);
    SIGNAL length_field : unsigned(9 DOWNTO 0);
    SIGNAL data_index : INTEGER RANGE 0 TO 8322 := 0;
    SIGNAL total_bits : INTEGER;
    SIGNAL full_packet : STD_LOGIC_VECTOR(8321 DOWNTO 0);
    SIGNAL received_crc : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL crc_bit_count : INTEGER RANGE 0 TO 31 := 0;

    SIGNAL crc_data_in : STD_LOGIC := '0';
    SIGNAL crc_complete : STD_LOGIC := '0';
    SIGNAL crc_enable : STD_LOGIC := '0';
    SIGNAL crc_rst : STD_LOGIC := '0';
    SIGNAL crc_pass : STD_LOGIC;
    SIGNAL crc_result : STD_LOGIC_VECTOR(32 DOWNTO 0);

    SIGNAL output_port : STD_LOGIC_VECTOR(2 DOWNTO 0);

    SIGNAL lookup_sel : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL lookup_data : STD_LOGIC_VECTOR(50 DOWNTO 0);

BEGIN

    -- CRC checker instance
    crc_block : ENTITY work.CRC32_Calculator
        PORT MAP(
            clk => clk,
            reset => crc_rst,
            bit_in => crc_data_in,
            data_valid => crc_enable,
            done => crc_complete,
            crc_ok => crc_pass,
            remainder => crc_result
        );

    -- Routing table lookup
    route_table : ENTITY work.setting
        PORT MAP(
            sel => lookup_sel,
            output => lookup_data
        );

    -- Main FSM process
    PROCESS (clk)
        VARIABLE match_found : BOOLEAN := false;
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                curr_state <= WAITING;
                bit_idx <= 0;
                data_index <= 0;
                crc_enable <= '0';
                crc_rst <= '1';
                valid_output <= '0';

            ELSE
                CASE curr_state IS

                    -- Waiting for start of packet (bit falls to '0')
                    WHEN WAITING =>
                        valid_output <= '0';
                        crc_rst <= '1';
                        IF serial_input = '0' THEN
                            curr_state <= READ_DEST;
                            bit_idx <= 0;
                        END IF;

                    -- Reading destination MAC address
                    WHEN READ_DEST =>
                        crc_rst <= '0';
                        dest_mac(47 - bit_idx) <= serial_input;
                        total_bits <= total_bits + 1;
                        full_packet(total_bits) <= serial_input;
                        crc_data_in <= serial_input;
                        crc_enable <= '1';
                        crc_complete <= '0';
                        IF bit_idx = 47 THEN
                            bit_idx <= 0;
                            curr_state <= READ_SRC;
                        ELSE
                            bit_idx <= bit_idx + 1;
                        END IF;

                    -- Reading source MAC address
                    WHEN READ_SRC =>
                        src_mac(47 - bit_idx) <= serial_input;
                        total_bits <= total_bits + 1;
                        full_packet(total_bits) <= serial_input;
                        crc_data_in <= serial_input;
                        crc_rst <= '0';
                        crc_enable <= '1';
                        crc_complete <= '0';
                        IF bit_idx = 47 THEN
                            bit_idx <= 0;
                            curr_state <= READ_LEN;
                        ELSE
                            bit_idx <= bit_idx + 1;
                        END IF;

                    -- Reading data length field
                    WHEN READ_LEN =>
                        length_field(9 - bit_idx) <= serial_input;
                        total_bits <= total_bits + 1;
                        full_packet(total_bits) <= serial_input;
                        crc_data_in <= serial_input;
                        crc_rst <= '0';
                        crc_enable <= '1';
                        crc_complete <= '0';
                        IF bit_idx = 9 THEN
                            bit_idx <= 0;
                            data_index <= 0;
                            curr_state <= READ_DATA;
                        ELSE
                            bit_idx <= bit_idx + 1;
                        END IF;

                    -- Reading packet data bits
                    WHEN READ_DATA =>
                        crc_data_in <= serial_input;
                        total_bits <= total_bits + 1;
                        full_packet(total_bits) <= serial_input;
                        crc_rst <= '0';
                        crc_complete <= '0';
                        crc_enable <= '1';
                        IF data_index = (to_integer(length_field) * 8) - 1 THEN
                            bit_idx <= 0;
                            curr_state <= READ_CRC;
                        ELSE
                            data_index <= data_index + 1;
                        END IF;

                    -- Reading CRC from packet
                    WHEN READ_CRC =>
                        crc_enable <= '1';
                        crc_complete <= '0';
                        crc_rst <= '0';
                        crc_data_in <= serial_input;
                        total_bits <= total_bits + 1;
                        full_packet(total_bits) <= serial_input;
                        IF bit_idx = 31 THEN
                            bit_idx <= 0;
                            curr_state <= VERIFY_CRC;
                        ELSE
                            bit_idx <= bit_idx + 1;
                        END IF;

                    -- Verifying CRC correctness
                    WHEN VERIFY_CRC =>
                        IF crc_pass = '1' THEN
                            curr_state <= ROUTE_LOOKUP;
                        ELSE
                            curr_state <= DISCARD;
                        END IF;

                    -- Looking up destination address in routing table
                    WHEN ROUTE_LOOKUP =>
                        match_found := false;
                        FOR i IN 0 TO 15 LOOP
                            lookup_sel <= STD_LOGIC_VECTOR(to_unsigned(i, 4));
                            IF dest_mac = lookup_data(50 DOWNTO 3) THEN
                                output_port <= lookup_data(2 DOWNTO 0);
                                match_found := true;
                            END IF;
                        END LOOP;
                        IF match_found THEN
                            curr_state <= SEND_DATA;
                            data_index <= 0;
                        ELSE
                            curr_state <= DISCARD;
                        END IF;

                    -- Sending the packet to the matched port
                    WHEN SEND_DATA =>
                        valid_output <= '1';
                        CASE output_port IS
                            WHEN "000" => port1 <= full_packet(data_index);
                            WHEN "001" => port2 <= full_packet(data_index);
                            WHEN "010" => port3 <= full_packet(data_index);
                            WHEN "011" => port4 <= full_packet(data_index);
                            WHEN "100" => port5 <= full_packet(data_index);
                            WHEN "101" => port6 <= full_packet(data_index);
                            WHEN "110" => port7 <= full_packet(data_index);
                            WHEN "111" => port8 <= full_packet(data_index);
                            WHEN OTHERS => port1 <= full_packet(data_index);
                        END CASE;
                        IF data_index = total_bits THEN
                            curr_state <= WAITING;
                        ELSE
                            data_index <= data_index + 1;
                        END IF;

                    -- Drop packet on CRC fail or no routing match
                    WHEN DISCARD =>
                        valid_output <= '0';
                        curr_state <= WAITING;

                END CASE;
            END IF;
        END IF;
    END PROCESS;

END behavior;
