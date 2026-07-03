python3 - << 'EOF'
import struct

with open('/mnt/user-data/uploads/STS12UC.EXE', 'rb') as f:
    data = f.read()

# Entry point is seg000:C629, file offset 0x13d69
# The calls are NEAR calls (E8 opcode) since IDA shows "call sub_XXXX" without FAR
# Let's decode the first ~20 instructions at the entry point

code_start = 0x7740  # header_paras * 16

# The segment is seg000, so all these subs are within the same segment
# sub_57990 is at offset 0x57990 within the segment
# file offset = code_start + 0x57990... but that's > file size, so these are
# SEGMENT-relative offsets, meaning seg000 base + offset

# Actually in IDA's segmented view, seg000:C629 means:
# The segment called seg000 starts at some base, and C629 is the offset within it
# From our analysis, code_start = 0x7740
# seg000:C629 = file offset code_start + C629 = 0x7740 + 0xC629 = 0x13D69 ✓

# The sub names like sub_57990 - these are seg000:57990
# file offset = 0x7740 + 0x57990 = 0x5F0D0
# But file size is 0x52460... that's too big
# So the subs must be in OTHER segments

# Wait - IDA uses LINEAR addresses for sub names in some configs
# sub_57990 linear address = 0x57990
# With load segment, linear = (load_seg + seg_offset)*16 + off
# This is getting complex. Let's just look at the actual bytes at entry point

ep = 0x13d69
print(f"Entry point bytes at file offset {ep:#x}:")
region = data[ep:ep+80]
for i in range(0, 80, 16):
    h = ' '.join(f'{b:02x}' for b in region[i:i+16])
    a = ''.join(chr(b) if 32<=b<=126 else '.' for b in region[i:i+16])
    print(f"  {ep+i:#08x}: {h}  {a}")

# Decode the CALL instructions
print(f"\nDecoding calls at entry point:")
pos = ep
calls_found = 0
while pos < ep + 80 and calls_found < 15:
    b = data[pos]
    if b == 0x9A:  # CALL FAR
        off = struct.unpack_from('<H', data, pos+1)[0]
        seg = struct.unpack_from('<H', data, pos+3)[0]
        print(f"  {pos:#08x} (+{pos-ep:02d}): CALL FAR {seg:04X}:{off:04X}  -> file? {0x7740 + seg*16 + off:#08x}")
        pos += 5
        calls_found += 1
    elif b == 0xE8:  # CALL NEAR
        rel = struct.unpack_from('<h', data, pos+1)[0]
        target = pos + 3 + rel  # relative to next instruction
        print(f"  {pos:#08x} (+{pos-ep:02d}): CALL NEAR {rel:+d} -> {target:#08x}")
        pos += 3
        calls_found += 1
    elif b == 0xC3:
        print(f"  {pos:#08x}: RET"); pos+=1
    elif b == 0xCB:
        print(f"  {pos:#08x}: RETF"); pos+=1
    elif b == 0xCD:
        print(f"  {pos:#08x}: INT {data[pos+1]:02X}h"); pos+=2
    else:
        print(f"  {pos:#08x}: {b:02x} ...")
        pos += 1

# Now look at what sub_57990 actually is
# IDA linear address 57990h - let's try to find what file offset this maps to
# The relocation base prefixes we found were FFF0, 0BFF, 17FE, 23FF, 2FFF, 3BFF
# With load segment ~0x0010: (FFF0+0010)&FFFF = 0000, so seg000 = segment 0000
# The sub names use LINEAR addresses = seg*16 + offset
# sub_57990: find which segment contains linear 57990
# If seg000 base = 0x0000, then seg000:57990 = linear 0x57990 -> BUT that's > 64KB
# So these subs are in OTHER IDA segments

# The IDA segment called seg000 probably has its offset in IDA's linear space
# Let's look at what the CALL FAR targets actually resolve to in the file
# From the entry point, each 9A xx xx xx xx is a far call
# The segment value gets relocated - let's check the reloc table for these

reloc_count = struct.unpack_from('<H', data, 6)[0]
reloc_offset = struct.unpack_from('<H', data, 24)[0]
header_paras = 0x774

# Build the set of file offsets that contain relocatable segment values
reloc_positions = {}
for i in range(reloc_count):
    r_off = reloc_offset + i*4
    rel_off = struct.unpack_from('<H', data, r_off)[0]
    rel_seg = struct.unpack_from('<H', data, r_off+2)[0]
    file_pos = header_paras*16 + rel_seg*16 + rel_off
    # The value AT this file position is the pre-relocation segment
    if file_pos < len(data)-1:
        pre_reloc_seg = struct.unpack_from('<H', data, file_pos)[0]
        reloc_positions[file_pos] = pre_reloc_seg

# Check the far calls at entry point
print(f"\nChecking relocation of entry point far calls:")
pos = ep
for i in range(15):
    if pos >= ep+80: break
    b = data[pos]
    if b == 0x9A:
        off = struct.unpack_from('<H', data, pos+1)[0]
        seg_field_pos = pos+3
        seg = struct.unpack_from('<H', data, pos+3)[0]
        is_reloc = seg_field_pos in reloc_positions
        print(f"  Call at {pos:#08x}: FAR {seg:04X}:{off:04X} - seg field at {seg_field_pos:#08x} {'RELOCATED' if is_reloc else 'HARDCODED'}")
        # If relocated, the actual target at load time = (load_seg + seg)*16 + off
        # The pre-reloc seg value encodes the RELATIVE segment from load point
        # Actual seg = load_seg + pre_reloc_seg (mod 0x10000)
        pos += 5
    else:
        pos += 1

EOF

Output
Entry point bytes at file offset 0x13d69:
  0x013d69: 9a 00 00 99 47 9a 02 01 59 47 9a 8a 00 45 47 9a  ....G...YG...EG.
  0x013d79: 00 00 e3 46 9a 59 0a 91 44 9a b3 06 b8 43 9a b2  ...F.Y..D....C..
  0x013d89: 11 9c 42 9a 65 04 40 42 9a 71 09 b9 40 9a e6 0a  ..B.e.@B.q..@...
  0x013d99: c8 3f 9a ee 04 78 3f 9a 73 16 9f 39 9a 1e 06 49  .?...x?.s..9...I
  0x013da9: 35 9a 54 0e e8 33 9a d2 01 9b 33 9a 28 45 3c 2f  5.T..3....3.(E</

Decoding calls at entry point:
  0x013d69 (+00): CALL FAR 4799:0000  -> file? 0x04f0d0
  0x013d6e (+05): CALL FAR 4759:0102  -> file? 0x04edd2
  0x013d73 (+10): CALL FAR 4745:008A  -> file? 0x04ec1a
  0x013d78 (+15): CALL FAR 46E3:0000  -> file? 0x04e570
  0x013d7d (+20): CALL FAR 4491:0A59  -> file? 0x04caa9
  0x013d82 (+25): CALL FAR 43B8:06B3  -> file? 0x04b973
  0x013d87 (+30): CALL FAR 429C:11B2  -> file? 0x04b2b2
  0x013d8c (+35): CALL FAR 4240:0465  -> file? 0x049fa5
  0x013d91 (+40): CALL FAR 40B9:0971  -> file? 0x048c41
  0x013d96 (+45): CALL FAR 3FC8:0AE6  -> file? 0x047ea6
  0x013d9b (+50): CALL FAR 3F78:04EE  -> file? 0x0473ae
  0x013da0 (+55): CALL FAR 399F:1673  -> file? 0x0427a3
  0x013da5 (+60): CALL FAR 3549:061E  -> file? 0x03d1ee
  0x013daa (+65): CALL FAR 33E8:0E54  -> file? 0x03c414
  0x013daf (+70): CALL FAR 339B:01D2  -> file? 0x03b2c2

Checking relocation of entry point far calls:
  Call at 0x013d69: FAR 4799:0000 - seg field at 0x013d6c RELOCATED
  Call at 0x013d6e: FAR 4759:0102 - seg field at 0x013d71 RELOCATED
  Call at 0x013d73: FAR 4745:008A - seg field at 0x013d76 RELOCATED
  Call at 0x013d78: FAR 46E3:0000 - seg field at 0x013d7b RELOCATED
  Call at 0x013d7d: FAR 4491:0A59 - seg field at 0x013d80 RELOCATED
  Call at 0x013d82: FAR 43B8:06B3 - seg field at 0x013d85 RELOCATED
  Call at 0x013d87: FAR 429C:11B2 - seg field at 0x013d8a RELOCATED
  Call at 0x013d8c: FAR 4240:0465 - seg field at 0x013d8f RELOCATED
  Call at 0x013d91: FAR 40B9:0971 - seg field at 0x013d94 RELOCATED
  Call at 0x013d96: FAR 3FC8:0AE6 - seg field at 0x013d99 RELOCATED
  Call at 0x013d9b: FAR 3F78:04EE - seg field at 0x013d9e RELOCATED
  Call at 0x013da0: FAR 399F:1673 - seg field at 0x013da3 RELOCATED
  Call at 0x013da5: FAR 3549:061E - seg field at 0x013da8 RELOCATED
  Call at 0x013daa: FAR 33E8:0E54 - seg field at 0x013dad RELOCATED
  Call at 0x013daf: FAR 339B:01D2 - seg field at 0x013db2 RELOCATED
Done

