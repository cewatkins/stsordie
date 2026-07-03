python3 - << 'EOF'
import struct

with open('/mnt/user-data/uploads/STS12UC.EXE', 'rb') as f:
    data = f.read()

# All entry point calls are RELOCATED - good, they're all internal
# Now let's look at each called function and find which one does hardware detection
# The file offsets are: 0x04f0d0, 0x04edd2, 0x04ec1a, 0x04e570, etc.
# These are in DESCENDING order - Turbo Pascal init runs from last to first typically
# But these are FORWARD calls - let's look at each one's first few instructions
# to find which one touches I/O ports or calls the ROM segments

# Key ROM call addresses we found earlier:
# 0x04ec5a: CALL FAR F000:FFF0  (reset vector)
# 0x04ec5f: CALL FAR C000:0000  (video BIOS)
# 0x04ec64: CALL FAR C800:0000  (HDD BIOS)
# These are ALL inside the function called at entry point call #3: 0x04ec1a!
# That's only 16 bytes before the reboot calls!

print("=== Call #3 target: 0x04ec1a (the REBOOT function) ===")
off = 0x04ec1a
region = data[off:off+80]
for i in range(0, 80, 16):
    h = ' '.join(f'{b:02x}' for b in region[i:i+16])
    a = ''.join(chr(b) if 32<=b<=126 else '.' for b in region[i:i+16])
    print(f"  {off+i:#08x}: {h}  {a}")

# Decode it
print(f"\nDecoding 0x04ec1a:")
pos = off
while pos < off + 120:
    b = data[pos]
    if b == 0x9A:
        o = struct.unpack_from('<H', data, pos+1)[0]
        s = struct.unpack_from('<H', data, pos+3)[0]
        note = ""
        if s == 0xF000: note = "  <-- CPU RESET!"
        elif s == 0xC000: note = "  <-- Video BIOS"
        elif s == 0xC800: note = "  <-- HDD BIOS"
        print(f"  {pos:#08x}: CALL FAR {s:04X}:{o:04X}{note}")
        pos += 5
    elif b == 0xE8:
        rel = struct.unpack_from('<h', data, pos+1)[0]
        tgt = pos + 3 + rel
        print(f"  {pos:#08x}: CALL NEAR -> {tgt:#08x}")
        pos += 3
    elif b == 0xCD: print(f"  {pos:#08x}: INT {data[pos+1]:02X}h"); pos+=2
    elif b == 0xC3: print(f"  {pos:#08x}: RET"); pos+=1; break
    elif b == 0xCB: print(f"  {pos:#08x}: RETF"); pos+=1; break
    elif b == 0xFA: print(f"  {pos:#08x}: CLI"); pos+=1
    elif b == 0xFB: print(f"  {pos:#08x}: STI"); pos+=1
    elif b == 0xF4: print(f"  {pos:#08x}: HLT"); pos+=1
    elif b == 0xEA:
        o = struct.unpack_from('<H', data, pos+1)[0]
        s = struct.unpack_from('<H', data, pos+3)[0]
        print(f"  {pos:#08x}: JMP FAR {s:04X}:{o:04X}")
        pos += 5
    elif b == 0x74: print(f"  {pos:#08x}: JZ  +{data[pos+1]} -> {pos+2+data[pos+1]:#08x}"); pos+=2
    elif b == 0x75: print(f"  {pos:#08x}: JNZ +{data[pos+1]} -> {pos+2+data[pos+1]:#08x}"); pos+=2
    elif b == 0x76: print(f"  {pos:#08x}: JBE +{data[pos+1]}"); pos+=2
    elif b == 0x77: print(f"  {pos:#08x}: JA  +{data[pos+1]}"); pos+=2
    elif b == 0xEB: 
        rel = data[pos+1]; rel = rel if rel < 128 else rel-256
        print(f"  {pos:#08x}: JMP SHORT {pos+2+rel:#08x}")
        pos+=2
    elif b == 0xBA:
        val = struct.unpack_from('<H', data, pos+1)[0]
        print(f"  {pos:#08x}: MOV DX, {val:#06x}h")
        pos+=3
    elif b == 0xB8:
        val = struct.unpack_from('<H', data, pos+1)[0]
        print(f"  {pos:#08x}: MOV AX, {val:#06x}h")
        pos+=3
    elif b == 0xEC: print(f"  {pos:#08x}: IN AL, DX"); pos+=1
    elif b == 0xEE: print(f"  {pos:#08x}: OUT DX, AL"); pos+=1
    elif b == 0x3C: print(f"  {pos:#08x}: CMP AL, {data[pos+1]:#04x}"); pos+=2
    elif b == 0x50: print(f"  {pos:#08x}: PUSH AX"); pos+=1
    elif b == 0x51: print(f"  {pos:#08x}: PUSH CX"); pos+=1
    elif b == 0x52: print(f"  {pos:#08x}: PUSH DX"); pos+=1
    elif b == 0x53: print(f"  {pos:#08x}: PUSH BX"); pos+=1
    elif b == 0x55: print(f"  {pos:#08x}: PUSH BP"); pos+=1
    elif b == 0x58: print(f"  {pos:#08x}: POP AX"); pos+=1
    elif b == 0x59: print(f"  {pos:#08x}: POP CX"); pos+=1
    elif b == 0x5A: print(f"  {pos:#08x}: POP DX"); pos+=1
    elif b == 0x5B: print(f"  {pos:#08x}: POP BX"); pos+=1
    elif b == 0x5D: print(f"  {pos:#08x}: POP BP"); pos+=1
    elif b == 0xC2:
        val = struct.unpack_from('<H', data, pos+1)[0]
        print(f"  {pos:#08x}: RET {val}"); pos+=3; break
    else:
        print(f"  {pos:#08x}: {b:02x} {data[pos+1]:02x} ...")
        pos+=1

# Now decode the EARLIER calls to find hardware detection
# Call #1 target: 0x04f0d0 -- farthest, likely TP runtime init (safe)
# Call #2 target: 0x04edd2 -- close to reboot code, suspicious
# Call #4 target: 0x04e570 -- also close

print("\n=== Call #2 target: 0x04edd2 ===")
off2 = 0x04edd2
region = data[off2:off2+60]
for i in range(0, 60, 16):
    h = ' '.join(f'{b:02x}' for b in region[i:i+16])
    a = ''.join(chr(b) if 32<=b<=126 else '.' for b in region[i:i+16])
    print(f"  {off2+i:#08x}: {h}  {a}")

print("\n=== Call #1 target: 0x04f0d0 ===")
off3 = 0x04f0d0
region = data[off3:off3+60]
for i in range(0, 60, 16):
    h = ' '.join(f'{b:02x}' for b in region[i:i+16])
    a = ''.join(chr(b) if 32<=b<=126 else '.' for b in region[i:i+16])
    print(f"  {off3+i:#08x}: {h}  {a}")

EOF

Output
=== Call #3 target: 0x04ec1a (the REBOOT function) ===
  0x04ec1a: 55 89 e5 e8 70 ff 5d cb e8 e8 e8 e8 e8 e8 e8 e8  U...p.].........
  0x04ec2a: 8c c8 8e c0 b0 40 e8 24 00 83 eb 09 26 c6 07 c3  .....@.$....&...
  0x04ec3a: b8 cd 21 81 c3 c7 00 81 eb 9a 00 26 89 07 ba 25  ..!........&...%
  0x04ec4a: 01 b8 03 25 1e 0e 1f e8 03 00 1f eb d3 5b 53 c3  ...%.........[S.
  0x04ec5a: 9a f0 ff 00 f0 9a 00 00 00 c0 9a 00 00 00 c8 e8  ................

Decoding 0x04ec1a:
  0x04ec1a: PUSH BP
  0x04ec1b: 89 e5 ...
  0x04ec1c: e5 e8 ...
  0x04ec1d: CALL NEAR -> 0x04eb90
  0x04ec20: POP BP
  0x04ec21: RETF

=== Call #2 target: 0x04edd2 ===
  0x04edd2: 55 89 e5 ff 36 26 21 ff 36 24 21 e8 f0 fe 52 50  U...6&!.6$!...RP
  0x04ede2: ff 36 2a 21 ff 36 28 21 e8 e3 fe 59 5b 2b c1 1b  .6*!.6(!...Y[+..
  0x04edf2: d3 83 fa 00 7f 07 7c 35 3d ff 00 72 30 81 2e 28  ......|5=..r0..(
  0x04ee02: 21 00 f0 83 1e 2a 21 0f c6 06 a1 d3  !....*!.....

=== Call #1 target: 0x04f0d0 ===
  0x04f0d0: ba dd 48 8e da 8c 06 42 21 33 ed 8b c4 05 13 00  ..H....B!3......
  0x04f0e0: b1 04 d3 e8 8c d2 03 c2 a3 14 21 a3 16 21 03 06  ..........!..!..
  0x04f0f0: 0e 21 a3 18 21 a3 22 21 a3 26 21 a3 2e 21 26 8b  .!..!."!.&!..!&.
  0x04f100: 16 02 00 89 16 2a 21 c7 06 34 21 a9  .....*!..4!.
