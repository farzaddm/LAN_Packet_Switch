def crc32_raw(message_bits: str, poly_bits: str) -> str:
    # Append 32 zeros
    msg = message_bits + '0' * 32
    msg = list(msg)

    poly = list(poly_bits)
    for i in range(len(message_bits)):
        if msg[i] == '1':
            for j in range(len(poly)):
                msg[i + j] = str(int(msg[i + j] != poly[j]))
    return ''.join(msg[-32:])

message = '10010000100000100100100010001011010101100011111111100000111'
generator = '100000100110000010001110110110111'  # 0x104C11DB7 (33 bits)

crc = crc32_raw(message, generator)
print("Message bits:  ", message)
print("CRC checksum:  ", crc)
print("Full stream:   ", len(message + crc))
