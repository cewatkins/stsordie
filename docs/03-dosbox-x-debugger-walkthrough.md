# DOSBox-X Built-in Debugger Walkthrough — STS-12UC.EXE

**Target:** `STS12UC.EXE` (baseline SHA1: `120f8d982a31de4bdd5292b65264491af0a2c11a`)
**Goal:** Step through from boot to card type gate, demo mode selection, and user login progression using DOSBox-X's **built-in debugger** (not the DOS DEBUG program).

---

## 0. Critical Distinction — Two Debuggers

DOSBox-X has **two** separate debugging mechanisms. Do not confuse them:

| | **DOSBox-X Built-in Debugger** | **DOS DEBUG Program** |
|---|---|-|
| **What it is** | Emulator-level debugger built into DOSBox-X | Classic MS-DOS debugger program (DEBUG.COM) that runs inside DOS |
| **How to access** | `-break-start -debug` flags on launch | Type `DEBUG` at DOS prompt |
| **Debugger commands** | `bpx`, `bpd`, `g`, `t`, `u`, `d`, `r`, `q`, `h`, `mem`, `cpu`, `int`, `port`, `seg`, `stack`, `log`, `trace` | `t`, `p`, `g`, `u`, `d`, `r`, `bpx`, `bpd`, `e`, `q`, `h` |
| **Scope** | Can pause emulator at any time, inspect CPU/memory/ports/segments | Only works while DOS program is running, limited to DOS memory |
| **Best for** | Hardware debugging, port I/O, ROM inspection, emulator state | In-DOS debugging, file I/O tracing, program-level stepping |

**This document covers the DOSBox-X Built-in Debugger.** For DOS DEBUG instructions, see `02-tool-instructions.md` Section 4.

---

## 1. POLL Environment Variable — What It Does

### POLL=1 vs POLL=0

| POLL Value | Behavior |
|------|--|--|
| **`POLL=1`** | Enables **polling mode** for COM3 and COM4. The BBS actively polls these ports for activity instead of relying on interrupt-driven detection. Use this when COM3/COM4 are **not connected** to real hardware — polling prevents the program from hanging waiting for a card interrupt. |
| **`POLL=0`** (or unset) | Uses **interrupt-driven** detection. The program waits for the expansion card to signal activity via IRQ. Requires the actual 16-channel serial card hardware present. |

### When to Use Each

| Scenario | POLL Value | Why |
|------|--|--|
| **No expansion card** (demo mode, modern PC, VM) | **`POLL=1`** | Polling mode skips the card interrupt dependency entirely. COM1/COM2 work via standard UART ports (3F8h/2F8h). |
| **Expansion card present** (original hardware) | **`POLL=0`** or **unset** | The card handles interrupts natively. Polling is unnecessary. |
| **COM3/COM4 not wired** (only COM1/COM2) | **`POLL=1`** | Prevents the program from hanging on COM3/COM4 polling loops. |
| **Debugging / fault isolation** | **`POLL=1`** | Reduces hardware-dependent variables. Focus on the code path, not hardware timing. |

### NOCOM Environment Variables

| Variable | Effect |
|------|--|
| `NOCOM1=1` | Disable COM1 |
| `NOCOM2=1` | Disable COM2 |
| `NOCOM3=1` | Disable COM3 |
| `NOCOM4=1` | Disable COM4 |

### Recommended Settings for Demo Mode (No Card)

```batch
SET NOCOM3=1
SET NOCOM4=1
SET POLL=1
```

This tells the program:
- **Don't look for COM3/COM4** (they don't exist)
- **Use polling mode** (no card interrupts)
- **COM1/COM2** are the only active lines (demo mode = 2 lines max)

---

## 2. Starting DOSBox-X Built-in Debugger

### 2.1 Configuration

In your `dosbox-x.conf`:

```ini
[cpu]
core=normal
cputype=386_slow
cycles=fixed 20000
```

**Critical:** `core=normal` — NOT `dynamic`. Dynamic core changes instruction timing and can obscure fault locations.

### 2.2 Launch with Debugger Break at Startup

```bash
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo
```

**Flags explained:**
- `-break-start` — Pauses execution **before** the first instruction. You get control at the DOS prompt with the debugger active.
- `-debug` — Enables the built-in debugger.
- `-defaultdir` — Sets the working directory.

### 2.3 Set Environment Variables

At the DOS prompt inside DOSBox-X:

```batch
SET NOCOM3=1
SET NOCOM4=1
SET POLL=1
```

Or run `SETCO` if you have the batch file:

```batch
SETCO
```

### 2.4 Launch the EXE

```batch
STS12UC.EXE
```

The debugger will pause at the entry point. You should see the DOSBox-X debugger prompt.

---

## 3. DOSBox-X Debugger Commands Reference

### 3.1 Navigation Commands

| Command | Description |
|---------|---|
| `g` | Go — run until next breakpoint or crash |
| `g <address>` | Go to address (runs until you reach it) |
| `t` | Trace — step one instruction (follows CALLs) |
| `p` | Step over — step one instruction (skips CALLs) |
| `x <address>` | Execute — run to address (alias for `g`) |
| `q` | Quit debugger — return to DOS prompt |

### 3.2 Inspection Commands

| Command | Description |
|---------|---|
| `r` | Show all CPU registers |
| `r <reg>` | Show specific register (e.g., `r AX`, `r CS`, `r IP`) |
| `u <address>` | Unassemble at address |
| `u <start> <end>` | Unassemble range |
| `d <address>` | Dump memory at address |
| `d <start> <end>` | Dump memory range |
| `mem` | Show memory map (segments, free memory) |
| `cpu` | Show CPU info (mode, features, flags) |
| `seg <segment>` | Show segment info (base, limit, type) |
| `stack` | Show stack pointer and top of stack |
| `int` | Show interrupt vector table |
| `port` | Show I/O port status |

### 3.3 Breakpoint Commands

| Command | Description |
|---------|---|
| `bpx <address>` | Set hardware breakpoint at address |
| `bpx <segment>:<offset>` | Set hardware breakpoint at segment:offset |
| `bpd` | Delete all breakpoints |
| `bpd <n>` | Delete breakpoint number n |
| `bpe` | Enable all breakpoints |
| `bpd` (with list) | List all breakpoints |

### 3.4 Debugging Utilities

| Command | Description |
|---------|---|
| `h` | Show help |
| `log` | Toggle INT 21h logging |
| `trace` | Enable trace mode (log every instruction) |
| `tracefile <filename>` | Write trace log to file |
| `i <port>` | Input byte from I/O port |
| `o <port> <value>` | Output byte to I/O port |
| `s <start> <end> <pattern>` | Search memory for pattern |
| `c <start1> <end1> <start2>` | Compare memory ranges |

---

## 4. Stepping Through — From Entry to Card Type Gate

### 4.1 At the Entry Point

When the debugger pauses, you're at the EXE entry point:

```
seg000:C629  (file offset 0x13D69)
```

This is where the 23 CALL FAR instructions begin. The first few are:

```
File Offset    Address       Instruction
0x13D69        seg000:C629  CALL FAR 4799:0000   ; Turbo Pascal runtime init
0x13D6E        seg000:C62E  CALL FAR 4759:0102   ; Startup helper
0x13D73        seg000:C633  CALL FAR 4745:008A   ; Demo/card init wrapper  <-- KEY
0x13D78        seg000:C638  CALL FAR 46E3:0000   ; Another init function
```

### 4.2 Step-by-Step Debugger Commands

#### Option A: Trace Into Each Call (t = Trace Into)

```
# At the DOSBox-X debugger prompt, type:
t
```

Each `t` steps **into** the next instruction (follows CALLs).

**What you'll see:**

1. **First `t`** — Enters Turbo Pascal runtime init at `4799:0000` (file `0x04F0D0`). This sets up the runtime environment (heap, I/O, etc.). You'll see lots of setup code.

2. **Continue stepping** — Eventually returns to the entry point.

3. **Next `t`** — Enters startup helper at `4759:0102` (file `0x04EDD2`).

4. **Next `t`** — Enters the **demo/card init wrapper** at `4745:008A` (file `0x04EC1A`). **This is the critical function.**

#### Option B: Set Breakpoint and Go

If you want to jump directly to the card type gate:

```
# Set a breakpoint at the demo/card init wrapper
bpx 4745:008A

# Run to the breakpoint
g

# When it hits, inspect
u 4745:008A 4745:0100
r
```

### 4.3 Inspecting the Card Type Gate

When you reach the card type gate at file offset `0x04EB90`:

```
# Unassemble the function
u 4745:008A 4745:0100

# You should see:
; File offset 0x04EB90 — Card Type Gate
55          PUSH BP
89 E5       MOV BP, SP
83 EC 0E    SUB SP, 0Eh
C7 46 F2 99 00  MOV word [BP-0Eh], 0099h    ; <-- Card type = 0x0099 (production card)
8B 46 F2    MOV AX, [BP-0Eh]
3D 99 00    CMP AX, 0099h
75 69       JNZ short loc_4EC0C                     ; <-- NEVER TAKEN (AX always == 0x0099)
; ... card path (ROM calls) ...
loc_4EC0C:
3D C5 00    CMP AX, 00C5h
75 07       JNZ short loc_4EC13
EB 03       JMP short loc_4EC16
loc_4EC13:
E8 47 00    CALL near ptr loc_4EC5A                 ; <-- ROM reboot cluster
loc_4EC16:
; ... return ...
```

### 4.4 Key Decision Points

#### Decision 1: Card Type Check

```asm
MOV word [BP-0Eh], 0x0099    ; Hardcoded: 16-channel serial card
CMP AX, 0x0099h               ; Compare with itself → always true
JNZ -> 0x04EC0C               ; NEVER TAKEN
```

**Result:** Always takes the card path (0x0099). The demo path (0x00C5) is unreachable.

**What happens next:** Falls through to ROM calls at `0x04EC5A`:
- `CALL FAR F000:FFF0` → CPU reset (reboot)
- `CALL FAR C000:0000` → Video BIOS
- `CALL FAR C800:0000` → HDD BIOS

#### Decision 2: Demo Mode Check (if AX were 0x00C5)

```asm
CMP AX, 0x00C5h               ; Check for demo mode
JNZ short loc_4EC13           ; If not demo, go to ROM calls
JMP short loc_4EC16           ; If demo, skip ROM calls
```

**Result:** If AX == 0x00C5, skips the ROM reboot cluster and uses COM1/COM2.

#### Decision 3: User Login Progression

After the card type gate (if demo mode is forced), the program enters user login:

```
1. Welcome screen (INFO1.TXT)
2. User login prompt
3. User #0 → User #1 → ... → User #4
4. Message system
5. .DAT file writes (P1000.DAT, P1100.DAT, etc.)
6. Later: CMD.TXT path check (where original fails)
```

---

## 5. Complete Debugger Session — Full Walkthrough

### 5.1 Full Session Script

```bash
# Terminal 1: Start DOSBox-X with debugger
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo

# Terminal 2 (or inside DOSBox-X): Set environment
SET NOCOM3=1
SET NOCOM4=1
SET POLL=1

# Launch the EXE
STS12UC.EXE
```

### 5.2 Step-by-Step Commands

```
# You're now at the entry point (seg000:C629)

# Show current registers
r

# Unassemble entry point
u seg000:C629 seg000:C650

# Step into Turbo Pascal init (Call #1)
t

# Continue stepping through TP init (lots of setup)
# Watch for: heap allocation, I/O initialization, string table setup

# Eventually returns to entry point

# Step into startup helper (Call #2)
t

# Continue stepping
# Watch for: COM port detection, environment variable parsing

# Eventually returns to entry point

# Step into demo/card init wrapper (Call #3) — THE KEY FUNCTION
t

# You're now at file offset 0x04EC1A
# Step into the card type gate
t

# You're now at file offset 0x04EB90
# Watch the card type check:
# MOV word [BP-0Eh], 0x0099
# CMP AX, 0x0099h
# JNZ -> 0x04EC0C (NEVER TAKEN)

# Step past the card type check
t

# Watch: falls through to ROM calls at 0x04EC5A
# CALL FAR F000:FFF0 (CPU reset)
# This is where the reboot happens

# If you patched selector_c5 (0x04EB99 99→C5):
# The CMP AX, 0x00C5h check will pass
# JMP to 0x04EC16 (skip ROM calls)
# Program continues to user login
```

### 5.3 Inspecting Memory at Key Points

```
# At the card type gate, inspect the local variable
d BP-0Eh BP-0Ch    ; Show the card type value (should be 99 00)

# Inspect the dispatch stub table
d 04EC5A 04ECB5     ; Show ROM stubs and channel dispatch stubs

# Inspect environment variables
d 01385A 013865     ; Show Pascal shortstrings (NOCOM1, NOCOM2, etc.)

# Inspect entry point bytes
u 13D69 13DB0       ; Show all 23 CALL FAR instructions

# Show memory map
mem

# Show CPU state
cpu

# Show segment info
seg 0000
seg 4745
```

---

## 5.4 HowTo — INT 21h EXEC Breakpoint Workflow

This section shows a step-by-step workflow for catching the STS program's first INT 21h EXEC call (function 4Bh — load and execute a program), then tracing into the STS code from there.

### Step-by-Step Commands

```
# Step 1: Mount C drive to the demo directory
MOUNT C C:\TEMP\

# Step 2: Change to the C: drive
C:

# Step 3: Run with debugger
# If DOSBox-X was started with -break-start, the debugger is already active.
# If not, launch DOSBox-X with: dosbox-x -break-start -debug -defaultdir C:\TEMP

# Step 4: Set breakpoint on INT 21h function 4Bh (EXEC)
# Option A: Break on all INT 21h calls
bpx F000:0000    ; BIOS INT 21h entry point (varies by system)

# Option B: Use INT 21h logging to catch EXEC calls
log              ; toggle INT 21h logging

# Step 5: Run to the breakpoint
F5               ; Go — runs until breakpoint hits (or g in command line)

# Step 6: Run the STS program
STS12UC.EXE

# When you see it stop at the breakpoint, inspect:

# F000:DAC6 — ROM BIOS data area (INT 21h entry)
u F000:DAC6 F000:DB00
; Expected output:
; F000:DAC6:  int 21
; F000:D100:  sti
; F000:D101:  callback 0038 (DOS Int 21)
; F000:D106:  retf

# F000:D100 — INT 21h callback entry
u F000:D100 F000:D110
; Shows the DOS interrupt handler entry point

# Step 7: Step into the STS program
F11              ; Step into (equivalent to 't' — traces into CALLs)
; You'll now see the first call into the STS program code

# Continue stepping through the STS program
t                ; trace into next instruction
t                ; continue stepping
; Watch for:
; - Card type gate at 0x04EB90
; - Demo mode selection at 0x04EB99
; - User login progression
; - .DAT file writes (INT 21h function 3Ch/3Dh)
```

### Key ROM Addresses to Watch

| Address | Purpose |
|---------|-----|
| `F000:DAC6` | INT 21h entry in ROM BIOS |
| `F000:D100` | INT 21h callback entry (sti → callback → retf) |
| `F000:FFF0` | CPU reset vector (reboot) |
| `C000:0000` | Video BIOS ROM |
| `C800:0000` | HDD Controller BIOS ROM |

### When to Use This Approach

- **When you want to catch the EXEC call** that loads the STS program
- **When you want to inspect ROM BIOS state** before the program runs
- **When you want to trace from the INT 21h handler** into the STS code
- **When the entry-point approach** (stepping from 0x13D69) is too early and you want to start closer to the action

### F11 vs t in DOSBox-X Debugger

| Key | Action | Description |
|-----|---|---|
| `F11` | Step Into | Equivalent to `t` — steps into CALLs |
| `F10` | Step Over | Equivalent to `p` — steps over CALLs |
| `F5` | Go | Equivalent to `g` — runs to next breakpoint |
| `F9` | Breakpoint | Set/clear breakpoint at current IP |
| `F7` | Trace On | Enable trace mode |
| `F8` | Trace Off | Disable trace mode |

**Note:** F11 is the keyboard shortcut for "step into" in the DOSBox-X debugger GUI. In the command line, use `t` for the same action.

---

## 5.5 HowTo — INT 21h EXEC Breakpoint Approach

This section shows an alternative debugging workflow: set a breakpoint on INT 21h function 4Bh (EXEC — load and run a program), then trace into the STS program from there. This catches the moment the BBS tries to load/exec a file.

### Step-by-Step Commands

```
# Step 1: Mount C drive to the demo directory
MOUNT C C:\TEMP\

# Step 2: Change to the C: drive
C:

# Step 3: Run with debugger (if not already started with -break-start)
# If DOSBox-X is already running with -break-start, skip this and go to Step 4

# Step 4: Set breakpoint on INT 21h function 4Bh (EXEC)
bpx 0000:0000    ; set breakpoint at IVT entry
# OR more precisely, break when INT 21h is called with AH=4Bh:
# Use the INT 21h logging to catch EXEC calls:
log              ; toggle INT 21h logging

# Alternative: set a hardware breakpoint at the INT 21h handler entry
bpx F000:0000    ; BIOS INT 21h entry point (varies by system)

# Step 5: Run to the breakpoint
g                ; go — runs until breakpoint hits

# Step 6: Run the STS program
STS12UC.EXE

# When you see it stop at the breakpoint, inspect:

# F000:0000DAC6 — ROM BIOS data area
u F000:DAC6 F000:DB00
; Expected output:
; F000:0000DAC6:  int 21h
; F000:0000D100:  sti
; F000:0000D101:  callback 0038 (DOS Int 21)
; F000:0000D106:  retf

# F000:0000D100 — INT 21h callback entry
u F000:D100 F000:D110
; This shows the DOS interrupt handler entry point

# Step 7: Step into the STS program
F11              ; step into (equivalent to 't' — trace into CALLs)
; You'll now see the first call into the STS program code

# Continue stepping through the STS program
t                ; trace into next instruction
t                ; continue stepping
; Watch for:
; - Card type gate at 0x04EB90
; - Demo mode selection at 0x04EB99
; - User login progression
; - .DAT file writes (INT 21h function 3Ch/3Dh)
```

### What This Approach Catches

| Event | How It's Caught |
|-------|-----------------|
| Program EXEC | INT 21h AH=4Bh breakpoint |
| ROM BIOS calls | F000:xxxx inspection |
| First STS call | F11 (step into) from breakpoint |
| Card type gate | Manual inspection at 0x04EB90 |
| Demo mode selection | Watch AX register at 0x04EB99 |
| .DAT file writes | INT 21h logging (log command) |

### Key ROM Addresses to Watch

| Address | Purpose |
|---------|-----|
| `F000:DAC6` | INT 21h entry in ROM BIOS |
| `F000:D100` | INT 21h callback entry (sti → callback → retf) |
| `F000:FFF0` | CPU reset vector (reboot) |
| `C000:0000` | Video BIOS ROM |
| `C800:0000` | HDD Controller BIOS ROM |

### When to Use This Approach

- **When you want to catch the EXEC call** that loads the STS program
- **When you want to inspect ROM BIOS state** before the program runs
- **When you want to trace from the INT 21h handler** into the STS code
- **When the entry-point approach** (stepping from 0x13D69) is too early and you want to start closer to the action

### F11 vs t in DOSBox-X Debugger

| Key | Action | Description |
|-----|--------|-------------|
| `F11` | Step Into | Equivalent to `t` — steps into CALLs |
| `F10` | Step Over | Equivalent to `p` — steps over CALLs |
| `F5` | Go | Equivalent to `g` — runs to next breakpoint |
| `F9` | Breakpoint | Set/clear breakpoint at current IP |
| `F7` | Trace On | Enable trace mode |
| `F8` | Trace Off | Disable trace mode |

**Note:** F11 is the keyboard shortcut for "step into" in the DOSBox-X debugger GUI. In the command line, use `t` for the same action.

---

## 6. Debugging Patched Variants

### 6.1 Patched with selector_c5 (0x04EB99 99→C5)

```bash
# Run the patched variant
SETCO
V2D9292.EXE
```

**What changes:**
- Card type gate now sees `0x00C5` instead of `0x0099`
- `CMP AX, 0x00C5h` passes
- Skips ROM reboot cluster
- Enters user login via COM1/COM2

**Watch for:**
- INT 6 at channel operations (if safe_stubs not applied)
- User #0 stall (if midop patches are wrong)
- User #4 stall (known limitation)

### 6.2 Patched with selector_c5 + safe_stubs

```bash
SETCO
V2DSAFE.EXE
```

**What changes:**
- Demo mode forced (selector_c5)
- ROM stubs neutralized (safe_stubs)
- No INT 6 from dispatch stubs
- Still may stall at user #4 (midop region)

### 6.3 Patched with selector_c5 + midop_jmp_1992

```bash
SETCO
V2D9292.EXE
```

**What changes:**
- Demo mode forced
- Midop region redirected to 1992
- Reaches user #4 (best progress)
- INT 6 after user #4 (unknown cause)

---

## 7. Tracing the Card Type Gate — Detailed View

### 7.1 Before Patching (Original Behavior)

```
At file offset 0x04EB90:

55          PUSH BP
89 E5       MOV BP, SP
83 EC 0E    SUB SP, 0Eh
C7 46 F2 99 00  MOV word [BP-0Eh], 0099h    ; Card type = 0x0099
8B 46 F2    MOV AX, [BP-0Eh]                ; AX = 0x0099
3D 99 00    CMP AX, 0099h                   ; AX == 0x0099? YES
75 69       JNZ short loc_4EC0C               ; NEVER TAKEN
; ... card path code (HLT, LES, etc.) ...
loc_4EC0C:
3D C5 00    CMP AX, 00C5h                   ; AX == 0x00C5? NO
75 07       JNZ short loc_4EC13               ; TAKEN
EB 03       JMP short loc_4EC16               ; SKIPPED
loc_4EC13:
E8 47 00    CALL near ptr loc_4EC5A           ; ROM reboot cluster
loc_4EC16:
; ... return ...
```

**Result:** Reboot via ROM calls.

### 7.2 After selector_c5 Patch

```
At file offset 0x04EB90 (with 0x04EB99 patched to C5):

55          PUSH BP
89 E5       MOV BP, SP
83 EC 0E    SUB SP, 0Eh
C7 46 F2 C5 00  MOV word [BP-0Eh], 00C5h    ; Card type = 0x00C5 (patched)
8B 46 F2    MOV AX, [BP-0Eh]                ; AX = 0x00C5
3D 99 00    CMP AX, 0099h                   ; AX == 0x0099? NO
75 69       JNZ short loc_4EC0C               ; TAKEN (finally!)
loc_4EC0C:
3D C5 00    CMP AX, 00C5h                   ; AX == 0x00C5? YES
75 07       JNZ short loc_4EC13               ; SKIPPED
EB 03       JMP short loc_4EC16               ; TAKEN
loc_4EC16:
; ... skip ROM calls, use COM1/COM2 ...
```

**Result:** Demo mode activated. No reboot.

---

## 8. Tracing User Login Progression

### 8.1 After Demo Mode is Activated

```
1. Welcome screen (INFO1.TXT)
   - Debugger: watch for INT 21h AH=3Fh (read file)
   - File: INFO1.TXT

2. User login prompt
   - Debugger: watch for INT 21h AH=0Ah (buffered input)
   - User enters name

3. User #0 check
   - Debugger: watch for CMP instructions
   - Compare against user database

4. User #1 → User #4 progression
   - Each user check involves:
     - Reading P####.DAT files
     - Comparing login credentials
     - Updating user counter

5. .DAT file writes
   - Debugger: watch for INT 21h AH=40h (write file)
   - Files: P1000.DAT, P1100.DAT, etc.

6. CMD.TXT path check (original fails here)
   - Debugger: watch for INT 21h AH=3Ch (create file)
   - Path: .\CMD.TXT
```

### 8.2 Key INT 21h Functions to Watch

| AH | Function | What to Watch |
|----|--|---|
| 0Ah | Buffered input | User login |
| 09h | Print string | Welcome screens |
| 3Fh | Read file | .TXT, .DAT files |
| 40h | Write file | .DAT file writes |
| 3Ch | Create file | STSCODE.BAT |
| 3Dh | Open file | INFO1.TXT, CMD.TXT |

---

## 9. Recommended Debugging Strategy

### 9.1 For New Analysis

```bash
# 1. Start with original (unpatched) to see reboot behavior
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo
SET NOCOM3=1
SET NOCOM4=1
SET POLL=1
STS12UC.EXE
# Step through to the ROM reboot cluster
# Note: CS:IP at reboot

# 2. Apply selector_c5 patch
# 3. Re-run and verify demo mode activation
# 4. Step through user login progression
# 5. Note where INT 6 occurs (if any)
```

### 9.2 For INT 6 Fault Isolation

```bash
# 1. Run patched variant
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo
SETCO
V2D9292.EXE

# 2. When INT 6 fires, note CS:IP
# 3. Map to file offset
./mz_map.py STSorg.exe --runtime CS:IP --load-seg XX

# 4. Unassemble at fault
u CS:IP

# 5. Step back to find root cause
# Trace back through CALL chain
```

---

## 10. Quick Reference — Key Addresses

| Address | What | How to Reach |
|---------|--|---|
| `seg000:C629` (0x13D69) | Entry point | Debugger pauses here at startup |
| `4799:0000` (0x04F0D0) | TP runtime init | Step from entry |
| `4745:008A` (0x04EC1A) | Demo/card init wrapper | Step from entry (Call #3) |
| `0x04EB90` | Card type gate | Inside demo/card init wrapper |
| `0x04EC5A` | ROM reboot cluster | After card type gate (card path) |
| `0x04EC16` | Demo path (skip ROM) | After card type gate (demo path) |
| `0x04EC78` | Dispatch stub table | After ROM cluster |
| `0x44BC6` | CS:IP 1978 fault region | Midop region (later) |
| `0x44BE4` | Branch control | Midop region (later) |

---

## 11. DOSBox-X Debugger vs DOS DEBUG — Quick Comparison

### DOSBox-X Built-in Debugger (This Document)

```bash
# Launch
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo

# Commands (at debugger prompt)
r          # Show registers
u <addr>   # Unassemble
d <addr>   # Dump memory
bpx <addr> # Set breakpoint
g          # Go/run
t          # Trace/step
mem        # Memory map
cpu        # CPU info
seg <seg>  # Segment info
stack      # Stack info
int        # Interrupt table
port       # Port status
q          # Quit debugger
```

### DOS DEBUG Program (Inside DOS Shell)

```bash
# Launch (inside DOSBox-X DOS prompt)
DEBUG

# Commands (at DEBUG prompt)
r        # Show registers
u <addr> # Unassemble
d <addr> # Dump memory
e <addr> # Edit memory
bpx <addr> # Set breakpoint
g        # Go/run
t        # Trace/step
p        # Step over
q        # Quit DEBUG
```

**Key difference:** DOSBox-X debugger can inspect emulator state (ports, segments, memory map, CPU flags). DOS DEBUG only sees what DOS programs can see.
