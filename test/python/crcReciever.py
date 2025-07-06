def crc_check_receiver(bitstream: str) -> bool:
    """
    Simulates your VHDL CRC receiver logic:
    - No reflection
    - Generator: 0x104C11DB7 (33-bit)
    - Remainder initialized to 0
    - Accepts full message + checksum
    - Returns True if CRC check passes (remainder = 0)
    """

    # 33-bit CRC generator (same as in your VHDL)
    generator = '100000100110000010001110110110111'  # 0x104C11DB7

    # Initialize 33-bit remainder with zeros
    remainder = [0] * 33

    # Process each bit of the input
    for bit in bitstream:
        # Shift left by 1 (multiply by x) and bring in next bit
        remainder = remainder[1:] + [int(bit)]

        # If MSB (x^32) is 1, XOR with generator
        if remainder[0] == 1:
            for i in range(33):
                remainder[i] ^= int(generator[i])
            

    # CRC check passes if the remainder is all zeros
    for i in remainder:
        print(i,end='')
    print('')
    return all(bit == 0 for bit in remainder)

stream = '1001000010000010010010001000101101010110001111111110000011100100000001110111010001101101101'
print(crc_check_receiver(stream))