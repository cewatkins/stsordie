# STS-12UC.EXE — Tool-Specific Operation Instructions

**Target:** STS-12 BBS host (`STS12UC.EXE`, baseline SHA1: `120f8d982a31de4bdd5292b65264491af0a2c11a`)
**Purpose:** Step-by-step operational instructions for DOSBox-X, IDA Free, Ghidra, and DOS DEBUG.

---

## 1. DOSBox-X — Runtime Execution & Debugging

### 1.1 Configuration

Create or edit `dosbox-x.conf` in your DOSBox-X config directory:

```ini
[cpu]
core=normal
cputype=386_slow
cycles=fixed 20000

[memsize]
memsize=16

[serial]
serial1=true active true port 3f8 irq 4
serial2=true active true port 2f8 irq 3
serial3=true active true port 2e8 irq 5
serial4=true active true port 3e8 irq 11

[dos]
xms=true
ems=true
umb=true

[keyboard]
keymap=
```

**Critical settings:**
- `core=normal` — NOT dynamic. Dynamic core obscures exact fault location.
- `cputype=386_slow` — Matches the original 386-era hardware.
- `cycles=fixed 20000` — Deterministic timing for reproducible results.

### 1.2 Environment Setup

Create `SETCO.BAT` in the demo folder:

```batch
@echo off
set NOCOM3=1
set NOCOM4=1
set POLL=1
```

Run before launching the EXE:
```batch
SETCO
STS12UC.EXE
```

### 1.3 Running a Patched Variant

```bash
# From ~/sb/demo/
cd ~/sb/demo

# Run with environment variables
SETCO
STS12UC.EXE

# Or run a specific patched variant
SETCO
V2D9292.EXE
```

### 1.4 Capturing INT 6 Faults

When INT 6 (Invalid Opcode) occurs, DOSBox-X logs:
```
ERROR CPU:Illegal Unhandled Interrupt Called 6
```

To capture the **first** fault site:

1. **In DOSBox-X debug mode:**
   ```bash
   dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo
   ```

2. **At the DOS prompt:**
   ```batch
   SETCO
   V2D9292.EXE
   ```

3. **When INT 6 fires**, note the DOSBox-X log timestamp and the CS:IP from the debugger.

4. **Map to file offset:**
   ```bash
   ./mz_map.py STSorg.exe --runtime CS:IP --load-seg XXXX
   ```

### 1.5 DOSBox-X Startup Break Mode

For pre-entry debugging:

```bash
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo
```

At the DOS prompt:
```batch
SETCO
V2D9292.EXE
```

The `-break-start` flag pauses execution before the first instruction, allowing you to set breakpoints at the entry point.

### 1.6 ROM Loading (for 86Box)

If you have the expansion card ROM dump:

```ini
# In 86Box machine config
rom_c4570 = /path/to/card_rom.bin
```

Or use LOADROM in DOSBox-X:
```bash
romload C4570 /path/to/card_rom.bin
```

### 1.7 Required Files in Working Directory

Place these in the same directory as the EXE:

| File | Purpose |
|------|---------|
| `INFO1.TXT` – `INFO5.TXT` | Welcome/info screens |
| `CMD.TXT` | Command help text |
| `P1000.DAT` | Main data file (created by original, may need to be pre-created) |

### 1.8 Expected Original Behavior

Running the **unpatched** original (`STS12UC.EXE.bak`):
1. Boots, shows demo banner
2. Checks card type → finds 0x0099 → ROM calls → reboot
3. If ROM calls are patched → reaches user login
4. Progresses past user #4
5. Writes populated `.DAT` files (P1000.DAT, P1100.DAT, etc.)
6. Later fails at CMD.TXT path check

---

## 2. IDA Free — Static Analysis

### 2.1 Loading the Binary

1. Open IDA Free
2. File → Open → select `STS12UC.EXE`
3. Select **Intel 8086** processor type
4. Choose **MZ** executable format
5. Click OK

### 2.2 Configuring Segmented Memory

IDA struggles with 16-bit segmented code. Configure manually:

1. **Edit → Segments → Define Segment**
2. Add segments for ROM addresses:
   - `F000:0000` – size 0x10000 (BIOS ROM)
   - `C000:0000` – size 0x10000 (Video BIOS)
   - `C800:0000` – size 0x10000 (HDD BIOS)
   - `C457:0000` – size 0x10000 (Expansion card ROM)

### 2.3 Fixing IDA Problems

#### ALREADY (Duplicate/Conflicting Definitions)

```
Right-click the address → Undefine (U)
Then redefine as code (C) or data (D)
```

For bulk fixes, use IDAPython:
```python
# Undefine conflicting ranges
for addr in range(start, end):
    idc.ua_del(addr, 1)
```

#### BOUNDS (Far Call to Unmapped Segment)

The calls at `seg041:00CA`, `00CF`, `00D4` point to unmapped ROM segments.

**Fix:**
1. Right-click the call instruction
2. Edit operand → set target manually
3. Or add manual segments (see 2.2 above)

#### BADSTACK (Stack Imbalance)

Instructions like `retn 6`, `retf 2`, `retn 0Ch` indicate Pascal calling convention cleanup.

**Fix:**
1. Click the function
2. Edit → Functions → Edit function (Alt+P)
3. Set "Far function" appropriately
4. Set the correct **purged bytes** count (stack cleanup amount)

### 2.4 Key Addresses to Navigate To

| Address | Content |
|---------|---------|
| `seg000:C629` | Entry point |
| `seg041:00CA` | ROM stub dispatch table |
| `seg041:00CF` | Video BIOS call |
| `seg041:00D4` | HDD BIOS call |
| `0x04EB90` | Card type gate function |
| `0x04EC1A` | Demo/card init wrapper |
| `0x04EC5A` | ROM stub 1 (F000:FFF0) |
| `0x04EC78` | Dispatch stub table start |
| `0x44BC6` | CS:IP 1978 fault region |
| `0x44BE4` | force_jz target |

### 2.5 Analyzing the Card Type Gate

Navigate to `0x04EB90` and analyze:

```asm
; Card type gate at file offset 0x04EB90
55          PUSH BP
89 E5       MOV BP, SP
83 EC 0E    SUB SP, 0Eh
C7 46 F2 99 00  MOV word [BP-0Eh], 0099h
8B 46 F2    MOV AX, [BP-0Eh]
3D 99 00    CMP AX, 0099h
75 69       JNZ short loc_4EC0C
; ... card path (ROM calls) ...
loc_4EC0C:
3D C5 00    CMP AX, 00C5h
75 07       JNZ short loc_4EC13
EB 03       JMP short loc_4EC16
loc_4EC13:
E8 47 00    CALL near ptr loc_4EC5A
loc_4EC16:
; ... return ...
```

### 2.6 Reanalyzing After Patches

After applying patches:
1. Right-click the patched area
2. Undefine (U)
3. Redefine as code (C)
4. Edit → Reanalyze program

---

## 3. Ghidra — Static Analysis

### 3.1 Loading the Binary

1. Open Ghidra
2. File → Import
3. Select `STS12UC.EXE`
4. Choose **Intel 16-bit LE** or **Intel 8086** processor
5. For format, select **MZ Executable**
6. Set base address to `0x0000`
7. Click Import

### 3.2 Configuring Memory Map

After loading, configure the memory map:

1. **Window → Memory Map**
2. Add segments for ROM:
   - `0xF0000` – size `0x10000` – ROM BIOS
   - `0xC0000` – size `0x10000` – Video BIOS
   - `0xC8000` – size `0x10000` – HDD BIOS
   - `0xC4570` – size `0x10000` – Expansion card ROM

### 3.3 Setting Entry Point

1. Navigate to file offset `0x13D69`
2. Press `P` to create a function
3. Name it `entry` or `start`

### 3.4 Key Functions to Analyze

#### Card Type Gate

Navigate to file offset `0x04EB90`:

```c
// Ghidra decompiled view of card type gate
void card_type_gate(void) {
    short local_var;
    
    local_var = 0x0099;           // hardcoded card type
    if (AX == 0x0099) {
        // Card path - ROM calls
        call_rom_f000_ffff();     // CPU reset
        call_rom_c000_0000();     // Video BIOS
        call_rom_c800_0000();     // HDD BIOS
    } else if (AX == 0x00C5) {
        // Demo path - skip ROM
        goto skip_rom;
    }
    call_rom_cluster();           // fallback
skip_rom:
    return;
}
```

#### Dispatch Stub Table

Navigate to file offset `0x04EC5A`:

```c
// Dispatch stub table at 0x04EC5A
void dispatch_stubs(void) {
    // 3 ROM calls
    call_far(0xF000, 0xFFFF);   // CPU reset
    call_far(0xC000, 0x0000);   // Video BIOS
    call_far(0xC800, 0x0000);   // HDD BIOS
    
    // 19 channel dispatch stubs (E8 00 00 → CALL NEAR +0)
    for (int i = 0; i < 19; i++) {
        stub_table[i] = call_near_zero();
    }
}
```

### 3.5 Cross-Reference Analysis

1. Right-click any function → **References** → **Show References**
2. Find all callers of the ROM call cluster
3. Trace back to the card type gate

### 3.6 Scripting Batch Patches

Ghidra Python script to apply patches:

```python
from ghidra.app.script import GhidraScript
from ghidra.program.model.mem import MemoryAccessException

class PatchApplicator(GhidraScript):
    def run(self):
        # selector_c5: 0x04EB96 C7 46 F2 99 00 → C7 46 F2 C5 00
        addr = toAddr(0x04EB96)
        current = getBytes(addr, 5)
        if current == bytes.fromhex('c746f29900'):
            patch(addr, bytes.fromhex('c746f2c500'))
            println("selector_c5 applied")
        
        # safe_stubs: 0x04EC5A 9A F0 FF 00 F0 → CB 90 90 90 90
        addr = toAddr(0x04EC5A)
        current = getBytes(addr, 5)
        if current == bytes.fromhex('9af0ff00f0'):
            patch(addr, bytes.fromhex('cb90909090'))
            println("safe_stubs ROM stub 1 applied")
```

---

## 4. DOS DEBUG — Runtime Debugging

### 4.1 Setup

Create `SETDBG.BAT`:

```batch
@echo off
set NOCOM3=1
set NOCOM4=1
set POLL=1
if "%1"=="" goto defexe
debug %1
goto done
:defexe
debug PCH12.EXE
:done
```

### 4.2 Basic Debugging Session

```bash
# From ~/sb/demo/
SETDBG V2D9292.EXE
```

At the DEBUG prompt:

```
- g              ; Run to next breakpoint or crash
- r              ; Show registers
- u cs:ip        ; Unassemble at fault address
- d cs:ip        ; Dump memory at fault address
```

### 4.3 Capturing INT 6 Faults

```
1. Run: g
2. When INT 6 fires, DEBUG breaks
3. Type: r
4. Record: CS=XXXX IP=XXXX
5. Type: u cs:ip
6. Type: d cs:ip
7. Report:
   - filename tested
   - CS:IP
   - first 5 lines from 'u cs:ip'
   - first 2 lines from 'd cs:ip'
```

### 4.4 Setting Breakpoints

```
- a 0100         ; Assemble at 0100
- mov ax, 00C5   ; Set AX to demo mode
- int 3          ; Software breakpoint
- g=0100         ; Run to breakpoint
```

### 4.5 Patching in DEBUG

```
- e 4EB99 C5    ; Edit byte at 0x04EB99 to C5 (selector_c5)
- e 4EC5A CB 90 90 90 90  ; Edit ROM stub 1 to RETF+NOP
- u 13D69        ; Verify entry point
- g              ; Run
```

### 4.6 Memory Dump for Analysis

```
- d 4EB90 4EC20 ; Dump card type gate function
- d 4EC5A 4ECB5 ; Dump dispatch stub table
- d 13D69 13DB0 ; Dump entry point
```

### 4.7 DOSBox-X Debug Integration

```bash
# Start DOSBox-X with debug break at startup
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo

# At DOS prompt
SETDBG V2D9292.EXE

# In DEBUG
- g              ; Run
# When INT 6 fires:
- r              ; Get CS:IP
- u cs:ip        ; See instruction
- q              ; Quit DEBUG
```

---

## 5. Applying Patches — Quick Reference

### 5.1 Using sts_patch.pl (Perl)

```bash
# Demo mode only
perl sts_patch.pl --file STS12UC.EXE --demo

# Demo + safe stubs (recommended minimum)
perl sts_patch.pl --file STS12UC.EXE --demo-safe

# All patches
perl sts_patch.pl --file STS12UC.EXE --demo --safe-stubs --bypass --fail-cmp --infinite

# Custom output
perl sts_patch.pl --file STS12UC.EXE --nobackup --demo
```

### 5.2 Using mkpatch.py (Python)

```bash
cd ~/sb/demo

# Generate a single variant
python3 mkpatch.py --selector_c5 --safe_stubs --output V2DSAFE.EXE

# Generate all 71 PCH variants
python3 mkpatch.py --all-pch

# Generate V2A name remap
python3 mkpatch_v2a.py --all
```

### 5.3 Manual Byte Patching

```bash
# selector_c5: 0x04EB99 99 → C5
printf '\xC5' | dd of=STS12UC.EXE bs=1 seek=0x4EB99 conv=notrunc

# safe_stubs ROM stub 1: 0x04EC5A 9A F0 FF 00 F0 → CB 90 90 90 90
printf '\xCB\x90\x90\x90\x90' | dd of=STS12UC.EXE bs=1 seek=0x4EC5A conv=notrunc

# safe_stubs ROM stub 2: 0x04EC5F 9A 00 00 00 C0 → CB 90 90 90 90
printf '\xCB\x90\x90\x90\x90' | dd of=STS12UC.EXE bs=1 seek=0x4EC5F conv=notrunc

# safe_stubs ROM stub 3: 0x04EC64 9A 00 00 00 C8 → CB 90 90 90 90
printf '\xCB\x90\x90\x90\x90' | dd of=STS12UC.EXE bs=1 seek=0x4EC64 conv=notrunc
```

### 5.4 Using xxd for Patching

```bash
# View bytes at offset
xxd -s 0x4EB96 -l 5 STSorg.exe

# Apply selector_c5 patch
xxd -r -p -s 0x4EB99 STSorg.exe << 'EOF'
c500
EOF

# Verify
sha1sum STSorg.exe
```

---

## 6. Debugging Workflow — INT 6 Best Practice

### 6.1 The Loop

```
1. Freeze baseline (STSorg.exe)
2. Run with deterministic CPU (core=normal, cputype=386_slow)
3. Capture FIRST fault CS:IP
4. Map to file offset (mz_map.py)
5. Patch ONE instruction
6. Re-test
7. Capture first fault again
8. Repeat
```

### 6.2 Never Do This

- ❌ Stack unknown patches from previous runs
- ❌ Apply broad speculative NOP sweeps
- ❌ Use dynamic CPU core for fault hunting
- ❌ Ignore the first INT 6 — it's the most important

### 6.3 Always Do This

- ✅ Keep STSorg.exe untouched
- ✅ Build from baseline only
- ✅ Record: offset, old bytes, new bytes, reason, effect
- ✅ One proven instruction per round
- ✅ Validate DAT files after each run

---

## 7. Address Mapping Reference

### 7.1 Using mz_map.py

```bash
# Pre-relocation mode (from IDA/Ghidra analysis)
./mz_map.py STSorg.exe --preloc 4745:008A

# Runtime mode (from debugger CS:IP)
./mz_map.py STSorg.exe --runtime 6A10:1F20 --load-seg 26F0
```

### 7.2 Manual Calculation

```
file_offset = header_paras * 16 + (seg << 4) + offset

Where:
  header_paras = MZ header at offset 0x16 (value * 16 = header size)
  seg = pre-relocation segment
  offset = offset within segment
```

### 7.3 Runtime to File Offset

```
preloc_seg = (CS - load_seg) & 0xFFFF
file_offset = header_paras * 16 + (preloc_seg << 4) + IP
```

---

## 8. Quick Reference Card

### Critical Patches (Minimum Viable)

| Patch | Offset | Bytes | Effect |
|-------|--------|-------|--------|
| selector_c5 | `0x04EB99` | `99` → `C5` | Take demo path |
| safe_stubs (3 ROM) | `0x04EC5A` | `9A F0 FF 00 F0` → `CB 90 90 90 90` | Neutralize ROM calls |
| safe_stubs (3 ROM) | `0x04EC5F` | `9A 00 00 00 C0` → `CB 90 90 90 90` | Neutralize ROM calls |
| safe_stubs (3 ROM) | `0x04EC64` | `9A 00 00 00 C8` → `CB 90 90 90 90` | Neutralize ROM calls |
| safe_stubs (19 stubs) | `0x04EC78` | `E8 00 00` → `C3 90 90` | Neutralize dispatch stubs |

### Key Addresses

| Address | What |
|---------|------|
| `0x13D69` | Entry point |
| `0x04EB90` | Card type gate |
| `0x04EC5A` | ROM stub 1 |
| `0x04EC78` | Dispatch stub table |
| `0x44BC6` | CS:IP 1978 fault region |
| `0x44BE4` | Branch control |

### Tool Commands

| Tool | Command |
|------|---------|
| DOSBox-X | `core=normal, cputype=386_slow, cycles=fixed 20000` |
| IDA Free | Load as 8086 MZ, add ROM segments F000/C000/C800/C457 |
| Ghidra | Import as Intel 16-bit LE, set base 0x0000 |
| DEBUG | `g` → `r` → `u cs:ip` → `d cs:ip` |
| mkpatch.py | `python3 mkpatch.py --selector_c5 --safe_stubs` |
| sts_patch.pl | `perl sts_patch.pl --demo --safe-stubs` |
