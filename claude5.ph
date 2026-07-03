bash
python3 - << 'EOF'
import struct

with open('/mnt/user-data/uploads/STS12UC.EXE', 'rb') as f:
    data = f.read()

# NOW WE HAVE THE ANSWER!
# 
# At 0x04eb9e: CMP AX, 0x0099h  (153 decimal)
# At 0x04eba1: JNZ -> 0x04ec0c
#
# At 0x04ec0c: CMP AX, 0x00c5h  (197 decimal)  
# At 0x04ec0f: JNZ -> 0x04ec13
# At 0x04ec11: JMP SHORT -> 0x04ec16  (skip the reboot call)
#
# At 0x04ec13: CALL NEAR -> 0x04ec5a  <-- THIS IS THE REBOOT CALL CLUSTER
#
# So the logic is:
# if AX == 0x0099: do stuff (the HLT/ES block), then JMP SHORT to 0x04ec13 (reboot)
# if AX == 0x00C5: JMP SHORT to 0x04ec16 (SKIP reboot - this is the safe path!)
# if AX == anything else: CALL 0x04ec5a (reboot)
#
# AX is loaded from somewhere before this function - let's find where
# The CMP AX,0099 at 0x04eb9e means AX was set before the function, or
# the MOV r,r/m at 0x04eb9d loaded it from [BP+something] (a parameter)
# 
# 0x04eb9b: MOV AX, [BP-0Eh]  (the 46 f2 = mod=01 reg=000 rm=110 -> [BP+disp8], disp=-14)
# Actually: 8B 46 F2 = MOV AX, [BP-0Eh]  -- a local variable or parameter
#
# Let's look at what calls 0x04eb90 and what AX/parameter value it passes
# The caller was 0x04ec1a which just does:
#   PUSH BP / MOV BP,SP / CALL 0x04eb90 / POP BP / RETF
# So 0x04ec1a is a thin wrapper
# 
# And 0x04ec1a is called from entry point call #3 at 0x013d73
# But BEFORE calling, the caller (start proc) would have set up a stack frame
#
# The key: 0x04eb9d: MOV AX, [BP+F2h] = [BP-0Eh] 
# This is a PARAMETER passed on the stack = the value passed by the caller
# 
# Let's look at what value is pushed before the call at 0x013d73

print("=== Code BEFORE entry point call #3 (the reboot call at 0x013d73) ===")
# Call #3 is at file offset 0x013d73
# Look at what preceded it (calls #1 and #2 set things up)
# But actually the VALUE comes from inside the function - let me re-read
# 
# 0x04eb90: PUSH BP
# 0x04eb91: MOV BP, SP     (89 E5)
# 0x04eb93: SUB SP, 0Eh    (83 EC 0E - allocate locals)
# 0x04eb96: MOV [BP-04], ?? (C7 46 FC?? - set a local)
# 0x04eb9b: MOV AX, [BP-0E]  (8B 46 F2)  <- reads a parameter
# 0x04eb9e: CMP AX, 99h
# 0x04eba1: JNZ -> 0x04ec0c

# 8B 46 F2: F2 = -14 = 0xF2 signed = [BP - 14]
# But parameters are at [BP+4] and above (BP+0=old BP, BP+2=ret addr, BP+4=first param)
# [BP-14] is a LOCAL, not a parameter
# So AX comes from a LOCAL variable set earlier in the function
# The 83 EC 0E allocates 14 bytes of locals (0x0E)
# And C7 46 FC = MOV word [BP-04], imm16

# Let's look at the raw bytes more carefully
print("Raw bytes 0x04eb90-0x04eba2:")
region = data[0x04eb90:0x04eba4]
hex_str = ' '.join(f'{b:02x}' for b in region)
print(f"  {hex_str}")
print()

# Decode properly byte by byte
# 55 89 e5 83 ec 0e c7 46 fc 00 00 8b 46 f2 3d 99 00 75 69
# 55        PUSH BP
# 89 E5     MOV BP, SP
# 83 EC 0E  SUB SP, 0Eh
# C7 46 FC 00 00  MOV word [BP-04h], 0000h   <- sets local to 0
# 8B 46 F2  MOV AX, [BP-0Eh]                 <- reads local at [BP-0Eh]
# 3D 99 00  CMP AX, 0099h
# 75 69     JNZ +0x69 -> 0x04ec0c

# BUT WAIT: [BP-0Eh] was NOT initialized in this function!
# The locals are only 0x0E bytes (SUB SP, 0Eh), so [BP-0Eh] = [SP] at entry
# This is the TOP OF STACK just before the call = a PASCAL PARAMETER!
# In Pascal calling convention: caller pushes params, then CALL
# The CALL pushes return address (2 bytes for near, 4 for far)
# Then PUSH BP / MOV BP,SP
# So [BP+0] = old BP, [BP+2] = return CS, [BP+4] = return IP (far) or just ret IP (near)
# For a FAR call (from entry point): [BP+4] = first param
# [BP-0Eh] = 14 bytes BELOW BP = in the local space BEFORE initialization

# Hmm - actually SUB SP, 0Eh means SP now points 14 bytes below BP
# [BP-0Eh] = [SP+0] = whatever was on stack before (not initialized)
# This looks like the function reads UNINITIALIZED stack space... OR
# it reads a parameter that's being passed IN AX (Turbo Pascal register params)

# Let me re-examine: maybe 8B 46 F2 is not MOV AX,[BP-0E] but something else
# 8B = MOV r16, r/m16
# 46 = mod=01 reg=000 rm=110 -> [BP + disp8], disp = next byte
# F2 = -14 as signed byte
# So it IS [BP-0Eh]

# ALTERNATIVE: In TP, small integers are passed in registers
# The caller at 0x013d73 does CALL FAR - which pushes CS:IP (4 bytes)
# If AX is set BEFORE the call by the caller, it arrives intact in the callee
# TP Pascal calling convention for value params passes them on stack
# but some compilers use AX for single word params

# Let's look at what happens in 0x04ec1a (the wrapper) more carefully
print("Raw bytes of wrapper 0x04ec1a-0x04ec22:")
region = data[0x04ec1a:0x04ec25]
hex_str = ' '.join(f'{b:02x}' for b in region)
print(f"  {hex_str}")
# 55 89 e5 e8 70 ff 5d cb
# 55       PUSH BP
# 89 E5    MOV BP, SP
# E8 70 FF CALL NEAR -0x90 -> 0x04eb90
# 5D       POP BP  
# CB       RETF
# No parameters pushed! The wrapper just calls inner directly.
# So the parameter must come from AX or is already on the stack from the OUTER caller

# The entry point calls 0x04ec1a with CALL FAR 4745:008A
# Before that call, what does the entry point push?
print("\nEntry point sequence around call #3:")
region = data[0x013d65:0x013d80]
hex_str = ' '.join(f'{b:02x}' for b in region)
print(f"  {hex_str}")
# The entry point is just a series of CALL FAR instructions
# No pushes before the calls - so params come from somewhere else

# KEY INSIGHT: [BP-0Eh] might actually be initialized by the CALL FAR mechanism
# When CALL FAR happens: SP -= 4 (pushes CS:IP)
# Then PUSH BP: SP -= 2
# Then MOV BP,SP: BP = SP
# Then SUB SP, 0Eh: SP -= 14
# So [BP-0Eh] = [SP] at this point = uninitialized... 
# UNLESS this is actually [BP + 0xF2] where 0xF2 as UNSIGNED = +242
# Some disassemblers sign-extend, but maybe 0x46 0xF2 means [BP+0F2h] NOT [BP-0Eh]?
# 
# Actually in x86: ModRM 46 with disp8 = F2h:
# The disp8 is SIGN-EXTENDED: F2h = 1111 0010b -> negative -> -14 decimal
# So it IS [BP-14] = a local OR it means the function reads BELOW its own frame
# = reading the CALLER's locals or params

# Let's check: what does the CALLER of 0x04ec1a have at its [BP-14] or nearby?
# The caller is the entry point 'start' proc, which uses CALL FAR 4745:008A
# After that CALL FAR: SP is at whatever start's frame had

# SIMPLER APPROACH: The value 0x0099 = 153 and 0x00C5 = 197
# These look like version numbers or hardware type codes
# 0x99 = version 1.53? or hardware type 153?
# 0xC5 = 197 decimal -- could be a hardware ID returned from the card

print(f"\n0x0099 = {0x99} decimal")
print(f"0x00C5 = {0xC5} decimal")
print(f"\nIf these are hardware IDs returned from the serial card probe:")
print(f"  0x99 = card found, type A -> proceed with ROM calls (path that reboots)")
print(f"  0xC5 = card found, type B -> skip ROM calls (safe path)")  
print(f"  other = no card / unknown -> CALL reboot cluster")
print(f"\nThe REAL question: where does AX get this value before 0x04eb90 is called?")

# Search for where the value 0x0099 or 0x00C5 might be SET
# Look for MOV AX, 0099 or similar immediately before calls to this function
print(f"\nSearching for MOV AX,0099h or MOV AX,00C5h patterns near callers:")
for i in range(0x7740, len(data)-5):
    if data[i] == 0xB8:
        val = struct.unpack_from('<H', data, i+1)[0]
        if val in (0x0099, 0x00C5, 0x99, 0xC5):
            # Check if followed by a call to 0x04ec1a area
            print(f"  {i:#08x}: MOV AX, {val:#06x}h")
            ctx = data[i:i+20]
            print(f"    context: {' '.join(f'{b:02x}' for b in ctx)}")

EOF

Output
=== Code BEFORE entry point call #3 (the reboot call at 0x013d73) ===
Raw bytes 0x04eb90-0x04eba2:
  55 89 e5 83 ec 0e c7 46 f2 99 00 8b 46 f2 3d 99 00 75 69 b8

Raw bytes of wrapper 0x04ec1a-0x04ec22:
  55 89 e5 e8 70 ff 5d cb e8 e8 e8

Entry point sequence around call #3:
  74 69 63 6b 9a 00 00 99 47 9a 02 01 59 47 9a 8a 00 45 47 9a 00 00 e3 46 9a 59 0a

0x0099 = 153 decimal
0x00C5 = 197 decimal

If these are hardware IDs returned from the serial card probe:
  0x99 = card found, type A -> proceed with ROM calls (path that reboots)
  0xC5 = card found, type B -> skip ROM calls (safe path)
  other = no card / unknown -> CALL reboot cluster

The REAL question: where does AX get this value before 0x04eb90 is called?

Searching for MOV AX,0099h or MOV AX,00C5h patterns near callers:
Done
