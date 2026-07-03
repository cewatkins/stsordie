ython3 - << 'EOF'
import struct

with open('/mnt/user-data/uploads/STS12UC.EXE', 'rb') as f:
    data = f.read()

# Call #3 at file 0x04ec1a is:
#   PUSH BP
#   MOV BP, SP  (89 e5)
#   CALL NEAR -> 0x04eb90   <- this is the real guts
#   POP BP
#   RETF
#
# So the REBOOT is triggered inside 0x04eb90 - let's decode that

print("=== 0x04eb90 - the function that actually reboots ===")
off = 0x04eb90
pos = off
while pos < off + 200:
    b = data[pos]
    if b == 0x9A:
        o = struct.unpack_from('<H', data, pos+1)[0]
        s = struct.unpack_from('<H', data, pos+3)[0]
        note = ""
        if s == 0xF000: note = "  <<<<< CPU RESET"
        elif s == 0xC000: note = "  <- Video BIOS"
        elif s == 0xC800: note = "  <- HDD BIOS"
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
        pos += 5; break
    elif b == 0x74:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JZ  -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x75:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JNZ -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x72:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JB  -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x73:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JAE -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x76:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JBE -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x77:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JA  -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x7C:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JL  -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x7D:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JGE -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x7E:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JLE -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0x7F:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JG  -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0xEB:
        rel = data[pos+1]; rel = rel if rel<128 else rel-256
        print(f"  {pos:#08x}: JMP SHORT -> {pos+2+rel:#08x}"); pos+=2
    elif b == 0xBA:
        val = struct.unpack_from('<H', data, pos+1)[0]
        print(f"  {pos:#08x}: MOV DX, {val:#06x}h"); pos+=3
    elif b == 0xB8:
        val = struct.unpack_from('<H', data, pos+1)[0]
        print(f"  {pos:#08x}: MOV AX, {val:#06x}h"); pos+=3
    elif b == 0xB0: print(f"  {pos:#08x}: MOV AL, {data[pos+1]:#04x}h"); pos+=2
    elif b == 0xB4: print(f"  {pos:#08x}: MOV AH, {data[pos+1]:#04x}h"); pos+=2
    elif b == 0xEC: print(f"  {pos:#08x}: IN AL, DX"); pos+=1
    elif b == 0xEE: print(f"  {pos:#08x}: OUT DX, AL"); pos+=1
    elif b == 0xE4: print(f"  {pos:#08x}: IN AL, {data[pos+1]:#04x}h"); pos+=2
    elif b == 0xE6: print(f"  {pos:#08x}: OUT {data[pos+1]:#04x}h, AL"); pos+=2
    elif b == 0x3C: print(f"  {pos:#08x}: CMP AL, {data[pos+1]:#04x}h"); pos+=2
    elif b == 0x3D:
        val = struct.unpack_from('<H', data, pos+1)[0]
        print(f"  {pos:#08x}: CMP AX, {val:#06x}h"); pos+=3
    elif b == 0x50: print(f"  {pos:#08x}: PUSH AX"); pos+=1
    elif b == 0x51: print(f"  {pos:#08x}: PUSH CX"); pos+=1
    elif b == 0x52: print(f"  {pos:#08x}: PUSH DX"); pos+=1
    elif b == 0x53: print(f"  {pos:#08x}: PUSH BX"); pos+=1
    elif b == 0x55: print(f"  {pos:#08x}: PUSH BP"); pos+=1
    elif b == 0x56: print(f"  {pos:#08x}: PUSH SI"); pos+=1
    elif b == 0x57: print(f"  {pos:#08x}: PUSH DI"); pos+=1
    elif b == 0x58: print(f"  {pos:#08x}: POP AX"); pos+=1
    elif b == 0x59: print(f"  {pos:#08x}: POP CX"); pos+=1
    elif b == 0x5A: print(f"  {pos:#08x}: POP DX"); pos+=1
    elif b == 0x5B: print(f"  {pos:#08x}: POP BX"); pos+=1
    elif b == 0x5D: print(f"  {pos:#08x}: POP BP"); pos+=1
    elif b == 0x5E: print(f"  {pos:#08x}: POP SI"); pos+=1
    elif b == 0x5F: print(f"  {pos:#08x}: POP DI"); pos+=1
    elif b == 0x89:
        print(f"  {pos:#08x}: MOV r/m,r  {data[pos+1]:02x}"); pos+=2
    elif b == 0x8B:
        print(f"  {pos:#08x}: MOV r,r/m  {data[pos+1]:02x}"); pos+=2
    elif b == 0x8C:
        print(f"  {pos:#08x}: MOV r/m,seg {data[pos+1]:02x}"); pos+=2
    elif b == 0x8E:
        print(f"  {pos:#08x}: MOV seg,r/m {data[pos+1]:02x}"); pos+=2
    elif b == 0x26: print(f"  {pos:#08x}: ES:"); pos+=1
    elif b == 0x2E: print(f"  {pos:#08x}: CS:"); pos+=1
    elif b == 0x36: print(f"  {pos:#08x}: SS:"); pos+=1
    elif b == 0x3E: print(f"  {pos:#08x}: DS:"); pos+=1
    elif b == 0x1E: print(f"  {pos:#08x}: PUSH DS"); pos+=1
    elif b == 0x1F: print(f"  {pos:#08x}: POP DS"); pos+=1
    elif b == 0x06: print(f"  {pos:#08x}: PUSH ES"); pos+=1
    elif b == 0x07: print(f"  {pos:#08x}: POP ES"); pos+=1
    elif b == 0x0E: print(f"  {pos:#08x}: PUSH CS"); pos+=1
    elif b == 0xA8: print(f"  {pos:#08x}: TEST AL, {data[pos+1]:#04x}h"); pos+=2
    elif b == 0xA9:
        val = struct.unpack_from('<H', data, pos+1)[0]
        print(f"  {pos:#08x}: TEST AX, {val:#06x}h"); pos+=3
    elif b == 0xF6: print(f"  {pos:#08x}: F6 {data[pos+1]:02x} {data[pos+2]:02x} (TEST/NOT/NEG/MUL...)"); pos+=3
    elif b == 0xF7: print(f"  {pos:#08x}: F7 {data[pos+1]:02x} (word op)"); pos+=3
    elif b == 0x80: print(f"  {pos:#08x}: 80 {data[pos+1]:02x} {data[pos+2]:02x} (CMP/ADD byte imm)"); pos+=3
    elif b == 0x83: print(f"  {pos:#08x}: 83 {data[pos+1]:02x} {data[pos+2]:02x} (CMP/ADD word imm8)"); pos+=3
    elif b == 0x81: print(f"  {pos:#08x}: 81 {data[pos+1]:02x} {data[pos+2]:02x}{data[pos+3]:02x} (word op imm16)"); pos+=4
    elif b == 0xC4: print(f"  {pos:#08x}: LES {data[pos+1]:02x}"); pos+=2
    elif b == 0xC5: print(f"  {pos:#08x}: LDS {data[pos+1]:02x}"); pos+=2
    elif b == 0xFF: print(f"  {pos:#08x}: FF {data[pos+1]:02x} (INC/DEC/CALL/JMP r/m)"); pos+=2
    elif b == 0xFE: print(f"  {pos:#08x}: FE {data[pos+1]:02x} (INC/DEC byte)"); pos+=2
    elif b == 0x40: print(f"  {pos:#08x}: INC AX"); pos+=1
    elif b == 0x41: print(f"  {pos:#08x}: INC CX"); pos+=1
    elif b == 0x42: print(f"  {pos:#08x}: INC DX"); pos+=1
    elif b == 0x43: print(f"  {pos:#08x}: INC BX"); pos+=1
    elif b == 0x48: print(f"  {pos:#08x}: DEC AX"); pos+=1
    elif b == 0x49: print(f"  {pos:#08x}: DEC CX"); pos+=1
    elif b == 0x4A: print(f"  {pos:#08x}: DEC DX"); pos+=1
    elif b == 0x4B: print(f"  {pos:#08x}: DEC BX"); pos+=1
    elif b == 0x85: print(f"  {pos:#08x}: TEST r/m,r {data[pos+1]:02x}"); pos+=2
    elif b == 0x84: print(f"  {pos:#08x}: TEST r/m8,r8 {data[pos+1]:02x}"); pos+=2
    elif b == 0x90: print(f"  {pos:#08x}: NOP"); pos+=1
    elif b == 0x32: print(f"  {pos:#08x}: XOR r8,r/m8 {data[pos+1]:02x}"); pos+=2
    elif b == 0x33: print(f"  {pos:#08x}: XOR r,r/m {data[pos+1]:02x}"); pos+=2
    elif b == 0x30: print(f"  {pos:#08x}: XOR r/m8,r8 {data[pos+1]:02x}"); pos+=2
    elif b == 0x31: print(f"  {pos:#08x}: XOR r/m,r {data[pos+1]:02x}"); pos+=2
    elif b == 0x09: print(f"  {pos:#08x}: OR r/m,r {data[pos+1]:02x}"); pos+=2
    elif b == 0x0B: print(f"  {pos:#08x}: OR r,r/m {data[pos+1]:02x}"); pos+=2
    elif b == 0x23: print(f"  {pos:#08x}: AND r,r/m {data[pos+1]:02x}"); pos+=2
    elif b == 0x29: print(f"  {pos:#08x}: SUB r/m,r {data[pos+1]:02x}"); pos+=2
    elif b == 0x2B: print(f"  {pos:#08x}: SUB r,r/m {data[pos+1]:02x}"); pos+=2
    elif b == 0x3B: print(f"  {pos:#08x}: CMP r,r/m {data[pos+1]:02x}"); pos+=2
    elif b == 0x39: print(f"  {pos:#08x}: CMP r/m,r {data[pos+1]:02x}"); pos+=2
    elif b == 0x03: print(f"  {pos:#08x}: ADD r,r/m {data[pos+1]:02x}"); pos+=2
    elif b == 0x01: print(f"  {pos:#08x}: ADD r/m,r {data[pos+1]:02x}"); pos+=2
    elif b == 0xC6: print(f"  {pos:#08x}: MOV r/m8,imm8 {data[pos+1]:02x} {data[pos+2]:02x}"); pos+=3
    elif b == 0xC7: print(f"  {pos:#08x}: MOV r/m16,imm16 {data[pos+1]:02x}..."); pos+=4
    elif b == 0xA0: print(f"  {pos:#08x}: MOV AL,[{struct.unpack_from('<H',data,pos+1)[0]:#06x}]"); pos+=3
    elif b == 0xA1: print(f"  {pos:#08x}: MOV AX,[{struct.unpack_from('<H',data,pos+1)[0]:#06x}]"); pos+=3
    elif b == 0xA2: print(f"  {pos:#08x}: MOV [{struct.unpack_from('<H',data,pos+1)[0]:#06x}],AL"); pos+=3
    elif b == 0xA3: print(f"  {pos:#08x}: MOV [{struct.unpack_from('<H',data,pos+1)[0]:#06x}],AX"); pos+=3
    else:
        print(f"  {pos:#08x}: ?? {b:02x}")
        pos+=1

EOF

Output
=== 0x04eb90 - the function that actually reboots ===
  0x04eb90: PUSH BP
  0x04eb91: MOV r/m,r  e5
  0x04eb93: 83 ec 0e (CMP/ADD word imm8)
  0x04eb96: MOV r/m16,imm16 46...
  0x04eb9a: ?? 00
  0x04eb9b: MOV r,r/m  46
  0x04eb9d: ?? f2
  0x04eb9e: CMP AX, 0x0099h
  0x04eba1: JNZ -> 0x04ec0c
  0x04eba3: MOV AX, 0x00cah
  0x04eba6: MOV DX, 0x4745h
  0x04eba9: MOV r/m,r  46
  0x04ebab: ?? fc
  0x04ebac: MOV r/m,r  56
  0x04ebae: FE c4 (INC/DEC byte)
  0x04ebb0: JLE -> 0x04ebae
  0x04ebb2: MOV r/m,r  f8
  0x04ebb4: MOV r/m,seg c2
  0x04ebb6: MOV r/m,r  46
  0x04ebb8: ?? f8
  0x04ebb9: MOV r/m,r  56
  0x04ebbb: CLI
  0x04ebbc: LES 7e
  0x04ebbe: ?? f8
  0x04ebbf: ES:
  0x04ebc0: ?? 8d
  0x04ebc1: ?? 45
  0x04ebc2: ADD r/m,r 8c
  0x04ebc4: ?? c2
  0x04ebc5: MOV r/m,r  46
  0x04ebc7: ?? fc
  0x04ebc8: MOV r/m,r  56
  0x04ebca: FE 8b (INC/DEC byte)
  0x04ebcc: ?? 46
  0x04ebcd: ?? fc
  0x04ebce: MOV r,r/m  56
  0x04ebd0: FE 89 (INC/DEC byte)
  0x04ebd2: ?? 46
  0x04ebd3: HLT
  0x04ebd4: MOV r/m,r  56
  0x04ebd6: F6 b8 9a (TEST/NOT/NEG/MUL...)
  0x04ebd9: ?? 00
  0x04ebda: LES 7e
  0x04ebdc: HLT
  0x04ebdd: ES:
  0x04ebde: MOV r/m,r  05
  0x04ebe0: LES 7e
  0x04ebe2: ?? f8
  0x04ebe3: ES:
  0x04ebe4: ?? 8d
  0x04ebe5: ?? 45
  0x04ebe6: ADD r,r/m 8c
  0x04ebe8: ?? c2
  0x04ebe9: MOV r/m,r  46
  0x04ebeb: ?? fc
  0x04ebec: MOV r/m,r  56
  0x04ebee: FE 8b (INC/DEC byte)
  0x04ebf0: ?? 46
  0x04ebf1: ?? fc
  0x04ebf2: MOV r,r/m  56
  0x04ebf4: FE 89 (INC/DEC byte)
  0x04ebf6: ?? 46
  0x04ebf7: HLT
  0x04ebf8: MOV r/m,r  56
  0x04ebfa: F6 8c c8 (TEST/NOT/NEG/MUL...)
  0x04ebfd: LES 7e
  0x04ebff: HLT
  0x04ec00: ES:
  0x04ec01: MOV r/m,r  05
  0x04ec03: LES 7e
  0x04ec05: ?? f8
  0x04ec06: ES:
  0x04ec07: MOV r/m8,imm8 05 ea
  0x04ec0a: JMP SHORT -> 0x04ec13
  0x04ec0c: CMP AX, 0x00c5h
  0x04ec0f: JNZ -> 0x04ec13
  0x04ec11: JMP SHORT -> 0x04ec16
  0x04ec13: CALL NEAR -> 0x04ec5a
  0x04ec16: MOV r/m,r  ec
  0x04ec18: POP BP
  0x04ec19: RET
