# STS-12UC.EXE Project — Complete State Snapshot (lastchat.md)

**Generated:** 2026-07-03
**Purpose:** Full project state snapshot — everything needed to restart the project from scratch without losing any context.

---

## 1. PROJECT OVERVIEW

**Target:** `STS12UC.EXE` — STS-12, a vintage DOS BBS host by Lightspeed Electronics (22 Glenside Road, South Orange, NJ 07079, (201)761-1793). "The Jungle" was a known BBS running this software.

**Goal:** Make the demo build run in DOSBox-X/86Box without hardware card dependency, reach the 900-check stage (user login progression), and write populated `.DAT` files.

**Baseline SHA1:** `120f8d982a31de4bdd5292b65264491af0a2c11a`

**Current Status:** **BLOCKED** — No patched variant reaches past user #4 with populated `.DAT` files.

---

## 2. ROOT CAUSE — WHY IT REBOOTS

The binary has **24 hardcoded far calls** into specific ROM addresses (none in the relocation table, all absolute):

| Physical Address | What It Is |
|-----------------|------------|
| `F000:FFF0` | x86 CPU Reset Vector (reboots machine) |
| `C000:0000` | Video BIOS ROM |
| `C800:0000` | HDD Controller BIOS ROM |
| `C457:0Exx` (5 entries) | Expansion serial card ROM BIOS |
| `F07E:C402` | Specific BIOS entry point |
| `F946:8A00` | Above 1MB |

### The Card Type Gate (Root Cause)

At file offset `0x04EB90`:

```asm
MOV word [BP-0Eh], 0x0099    ; hardcoded card type constant
CMP AX, 0x0099h               ; compare with itself → always true
JNZ -> 0x04EC0C               ; NEVER TAKEN — falls through to reboot
```

Two card type codes:
- **`0x0099`** = 16-channel serial expansion card → ROM calls → reboot
- **`0x00C5`** = demo/standard mode → skip ROM calls → use COM1/COM2

**The fix:** Patch byte at `0x04EB99` from `99` to `C5`.

### Why INT 6 Happens After the Fix

The `0x0099` init block also patches a **dispatch stub table** at runtime (seg041:00CA):
- 3× CALL FAR to ROM (F000:FFF0, C000:0000, C800:0000)
- 19× CALL NEAR placeholder stubs (E8 00 00)

Demo path (`0x00C5`) skips this → stubs stay in factory state → INT6 when channels are used.

**19 patches applied:**
| # | Offset | Before | After | Purpose |
|--|--------|--------|-------|-----|
| 1 | 0x04EB99 | 99 | C5 | Take demo path |
| 2 | 0x04EC5A | 9A F0 FF 00 F0 | CB 90 90 90 90 | F000:FFF0 → RETF |
| 3 | 0x04EC5F | 9A 00 00 00 C0 | CB 90 90 90 90 | C000:0000 → RETF |
| 4 | 0x04EC64 | 9A 00 00 00 C8 | CB 90 90 90 90 | C800:0000 → RETF |
| 5–19 | 0x04EC78–0x04ECB1 | E8 00 00 | C3 90 90 | 19 dispatch stubs → RET |

---

## 3. ALL PATCH FAMILIES — COMPLETE REFERENCE

### 3.1 Patch Action Reference

| Patch Name | File Offset | Before | After | Theory / Meaning |
|------------|--|-----|-------|------|
| **selector_c5** | `0x04EB96` | `C7 46 F2 99 00` | `C7 46 F2 C5 00` | Forces AX=00C5 at card type gate. **Most critical patch.** |
| **safe_stubs** | `0x04EC5A`–`0x04ECB4` | 3× CALL FAR + 19× CALL NEAR | 3× RETF+NOP + 19× RET+NOP | Neutralizes dispatch stub cluster. Without this → INT6. |
| **nop_call3** | `0x13D73` | `9A 8A 00 45 47` | `90 90 90 90 90` | NOPs entry call #3. Weakens init fidelity. |
| **nop_call4** | `0x13D78` | `9A 00 00 E3 46` | `90 90 90 90 90` | NOPs entry call #4. |
| **skip_reboot_call** | `0x04EC0A` | `EB 07` | `EB 0A` | Skips past EC5A call in demo path. |
| **cmp_c5** | `0x04EB9E` | `3D 99 00` | `3D C5 00` | Alternative to selector_c5. |
| **jnz_to_jmp** | `0x04EBA1` | `75 69` | `EB 69` | Forces card path regardless of AX. |
| **csip_1978_retguard** | `0x44BC6` | `05 CC C2 B8 1C` | `C3 90 90 90 90` | Forces return from fault region. |
| **csip_probe_cc** | `0x44BC8` | `C2 B8 1C` | `CC 90 90` | Forces INT3 probe at fault site. |
| **force_jz_taken** | `0x44BE4` | `74 06` | `EB 06` | Forces JZ to jump to 19A0. |
| **force_jz_not_taken** | `0x44BE4` | `74 06` | `90 90` | NOPs JZ, forces fall-through. |
| **force_zf1_no_memread** | `0x44BE4` area | varies | varies | Removes ES:DI memread side effect. |
| **midop_jmp_1992** | `0x44BE4` area | varies | varies | Redirects to 1992. Most progress-preserving. |
| **midop_jmp_19a0** | `0x44BE4` area | varies | varies | Redirects to 19A0. Triggers ROM write errors. |
| **midop_jmp_1c08** | `0x44BE4` area | varies | varies | Redirects to 1C08. Alternate landing. |
| **midop_c2_to_cb** | `0x44BE4` area | varies | varies | RETF semantics at overlap. |
| **bypass_call_0ee8** | varies | varies | varies | Caller bypass. Destabilizes flow. |
| **bypass_call_2b82** | varies | varies | varies | Caller bypass. Destabilizes flow. |
| **bypass_call_2bb2** | varies | varies | varies | Caller bypass. Destabilizes flow. |

### 3.2 Three-Layer Execution Model

```
Layer 1: Entry Point (0x13D69)
  └── 23 CALL FAR instructions
  └── Call #3 → demo/card init wrapper (0x04EC1A)
  └── Patch targets: nop_call3, nop_call4

Layer 2: Card Type Gate (0x04EB90)
  └── MOV [BP-0Eh], 0x0099 → CMP AX, 0x0099 → JNZ
  └── If AX==0x0099: card path → ROM calls → reboot
  └── If AX==0x00C5: demo path → skip ROM → COM1/COM2
  └── Patch targets: selector_c5, cmp_c5, jnz_to_jmp

Layer 3: Dispatch Stub Table (0x04EC5A–0x04ECB4)
  └── 3× CALL FAR to ROM
  └── 19× CALL NEAR +0
  └── Patch targets: safe_stubs, skip_reboot_call
```

### 3.3 PCH Matrix (71 Variants) — Key Outcomes

| Variant | Patch Set | Outcome |
|---------|-----|---|
| PCH52 | `selector_c5, safe_stubs, midop_jmp_1992` | account0-stop (no INT6) |
| PCH53 | `skip_reboot_call, safe_stubs, midop_jmp_1992` | account0-stop (no INT6) |
| **PCH58** | `selector_c5, safe_stubs, midop_jmp_1c08` | **account0-stop (best midop-only)** |
| PCH54, PCH55, PCH60, PCH68–PCH71 | various | INT6 |

### 3.4 V2A Profile Matrix (16 Profiles) — Key Outcomes

| Profile | Output | Patch Set | Outcome |
|---------|-----|------|---|
| demo-900-j1992 | V2D9292.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_1992` | **user #4, INT6** (best progress) |
| demo-900-target | V2D900.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_1c08` | **user #4, INT6** |
| demo-safe | V2DSAFE.EXE | `selector_c5, safe_stubs` | user #0 stop |
| demo-900-basejmp | V2D90BJ.EXE | `selector_c5, midop_jmp_1c08` | user #0 stop |
| demo-900-cb | V2D90CB.EXE | `selector_c5, nop_call3, nop_call4, midop_c2_to_cb` | early INT6 |
| demo-900-j19a0 | V2D92A0.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_19a0` | ROM write errors (F000) |
| demo-dat-j1992 | V2DD992.EXE | `selector_c5, midop_jmp_1992` | user #0 stop |
| demo-dat-j1992-ns | V2DD99N.EXE | `selector_c5, midop_jmp_1992, force_jz_not_taken` | user #0 stop |
| demo-dat-j1992-zf1 | V2DD99Z.EXE | `selector_c5, midop_jmp_1992, force_zf1_no_memread` | user #0 stop |
| demo-dat-j19a0 | V2DD9A0.EXE | `selector_c5, midop_jmp_19a0` | user #0 stop |

---

## 4. HARD CONSTRAINTS & LESSONS LEARNED

1. **No patched profile passes user #4** — only original baseline writes populated `.DAT` files.
2. **Entry bypasses (nop_call3/nop_call4)** improve startup speed but weaken initialization fidelity.
3. **19A0-leaning branches** trigger invalid memory/ROM writes in DOSBox-X.
4. **Caller bypass patches** destabilize later control flow, increase INT6 risk.
5. **Midop_jmp_1992 / midop_jmp_1c08** are the most progress-preserving but stall at user #4.
6. **Original baseline** reboots/fails later (after checks like CMD.TXT path) but reliably writes populated `.DAT` files.
7. **Demo mode is built-in** — the EXE is already the demo build (2-line cap, passwords disabled). The 00C5 selector just makes it reachable.
8. **All patching must start from STSorg.exe** — never stack patches from previous runs.
9. **POLL=1** for no card / COM3/COM4 not wired. **POLL=0** for original hardware with card.
10. **NOCOM3=1, NOCOM4=1** when COM3/COM4 are not connected.

---

## 5. CURRENT STATUS

**BLOCKED:** No patched variant reaches past user #4 with populated `.DAT` files.

**Active Candidates (Priority Order):**
| Priority | Variant | Reached | Outcome |
|------|---------|-----|---|
| 1 | V2D9292.EXE | user #4 | INT6 |
| 2 | V2D900.EXE | user #4 | INT6 |
| 3 | STSorg.exe (original) | beyond user #4 | Reboots later, writes populated DATs |

**Archived / Frozen:**
- V2D90BJ.EXE, V2D90CB.EXE, V2D92A0.EXE, V2DD992/99N/99Z/9A0.EXE
- All bypass_call_* variants
- All midop_jmp_19a0 variants

**Next cycle — two branches only:**
- **Branch A (fidelity-first):** demo force + minimal overlap control, no entry bypass, no safe-stubs.
- **Branch B (progress-first):** V2D9292 lineage with one-at-a-time branch control toggles.

**Reference contract:** Original baseline = "must write populated DATs before user#4+ stage."

---

## 6. KEY FILE OFFSETS

| Offset | Content |
|--------|-----|
| `0x013D69` | Entry point (23 CALL FAR) |
| `0x04EB90` | Card type gate function |
| `0x04EB96` | selector_c5 target (`C7 46 F2 99 00`) |
| `0x04EB99` | selector_c5 byte target (99 → C5) |
| `0x04EBA1` | jnz_to_jmp target (75 → EB) |
| `0x04EC0A` | skip_reboot_call target (EB 07 → EB 0A) |
| `0x04EC1A` | demo/card init wrapper |
| `0x04EC5A` | ROM stub 1 (F000:FFF0) |
| `0x04EC5F` | ROM stub 2 (C000:0000) |
| `0x04EC64` | ROM stub 3 (C800:0000) |
| `0x04EC78` | Dispatch stub table start (19× E8 00 00) |
| `0x44BE4` | force_jz target |
| `0x44BC6` | csip_1978_retguard target |

---

## 7. TOOLS & SCRIPTS

| Tool | Purpose |
|------|-----|
| `sts_patch.pl` | Perl patcher: `--demo`, `--safe-stubs`, `--bypass`, `--fail-cmp`, `--infinite` |
| `demo/mkpatch.py` | Python patch generator (PCH01–PCH71) |
| `demo/mkpatch_v2a.py` | V2A name remap |
| `demo/mz_map.py` | MZ SEG:OFF → file offset mapper |
| `acs/ADDRUN.SH` | Run result logger |
| `SETCO.BAT` | Environment variable setup |
| `SETDBG.BAT` | DOS DEBUG setup |

---

## 8. DOSBOX-X CONFIGURATION

```ini
[cpu]
core=normal
cputype=386_slow
cycles=fixed 20000
```

**Critical:** `core=normal` — NOT `dynamic`. Dynamic core obscures fault locations.

### Environment Variables

```batch
SET NOCOM3=1
SET NOCOM4=1
SET POLL=1
```

| Variable | Effect |
|------|-----|
| `NOCOM1=1` | Disable COM1 |
| `NOCOM2=1` | Disable COM2 |
| `NOCOM3=1` | Disable COM3 |
| `NOCOM4=1` | Disable COM4 |
| `POLL=1` | Polling mode for COM3/COM4 (no card = use this) |
| `POLL=0` | Interrupt-driven (original hardware with card) |

### Launch with Debugger

```bash
dosbox-x -break-start -debug -defaultdir /home/oo/sb/demo
```

---

## 9. DOSBOX-X BUILT-IN DEBUGGER COMMANDS

### Navigation
| Command | Description |
|---------|-----|
| `g` | Go — run until next breakpoint or crash |
| `g <address>` | Go to address |
| `t` | Trace — step one instruction (follows CALLs) |
| `p` | Step over — step one instruction (skips CALLs) |
| `q` | Quit debugger |

### Inspection
| Command | Description |
|---------|-----|
| `r` | Show all CPU registers |
| `r <reg>` | Show specific register |
| `u <address>` | Unassemble at address |
| `u <start> <end>` | Unassemble range |
| `d <address>` | Dump memory at address |
| `d <start> <end>` | Dump memory range |
| `mem` | Show memory map |
| `cpu` | Show CPU info |
| `seg <segment>` | Show segment info |
| `stack` | Show stack info |
| `int` | Show interrupt vector table |
| `port` | Show I/O port status |

### Breakpoints
| Command | Description |
|---------|-----|
| `bpx <address>` | Set hardware breakpoint |
| `bpx <segment>:<offset>` | Set breakpoint at segment:offset |
| `bpd` | Delete all breakpoints |
| `bpd <n>` | Delete breakpoint n |
| `bpe` | Enable all breakpoints |

### Utilities
| Command | Description |
|---------|-----|
| `h` | Show help |
| `log` | Toggle INT 21h logging |
| `trace` | Enable trace mode |
| `tracefile <filename>` | Write trace log to file |
| `i <port>` | Input byte from I/O port |
| `o <port> <value>` | Output byte to I/O port |
| `s <start> <end> <pattern>` | Search memory |
| `c <start1> <end1> <start2>` | Compare memory ranges |

---

## 10. DOS DEBUG PROGRAM COMMANDS (Inside DOS Shell)

### Navigation
| Command | Description |
|---------|-----|
| `g` | Go — run to breakpoint or crash |
| `g <address>` | Go to address |
| `t` | Trace — step into CALLs |
| `p` | Step over — skip CALLs |
| `q` | Quit DEBUG |

### Inspection
| Command | Description |
|---------|-----|
| `r` | Show registers |
| `u <address>` | Unassemble |
| `d <address>` | Dump memory |
| `e <address> <bytes>` | Edit memory |

### Breakpoints
| Command | Description |
|---------|-----|
| `bpx <address>` | Set hardware breakpoint |
| `bpd` | Delete all breakpoints |

---

## 11. WORKSPACE STRUCTURE

```
~/sb/
├── STS12UC.EXE.bak          # Original baseline (SHA1: 120f8d...c11a)
├── sts_patch.pl             # Perl patcher
├── SETCO.BAT                # SET NOCOM3=1, SET NOCOM4=1, SET POLL=1
├── SETDBG.BAT               # DOS DEBUG setup
├── log.txt                  # DOSBox-X runtime log
├── stsds.md                 # Project memory file
├── PATCH_MATRIX_RETHINK.md  # Patch matrix rethink
├── claude0.ph – claude5.ph  # Session logs
├── claudetalk               # Full conversation transcript
├── demo/
│   ├── STSorg.exe           # Clean baseline (byte-identical)
│   ├── stsdemo.exe          # selector_c5 only
│   ├── stsdemo_safe.exe     # selector_c5 + safe_stubs
│   ├── mkpatch.py           # Python patch generator (PCH01–PCH71)
│   ├── mkpatch_v2a.py       # V2A name remap
│   ├── mz_map.py            # MZ SEG:OFF → file offset mapper
│   ├── PATCHES.TXT          # PCH variant → patch set manifest
│   ├── V2A_PROFILES.TXT     # V2D profile manifest (16 profiles)
│   ├── PCH_TEST_DIFFS.md    # Runtime outcome table for PCH variants
│   ├── INT6_BEST_PRACTICE.md # INT6 debugging workflow
│   ├── V2A_PROFILE_PLAN.md  # V2D demo run profile plan
│   ├── CAPINT6.TXT          # INT6 capture notes
│   ├── PCH01.EXE–PCH71.EXE  # 71 generated patch variants
│   ├── V2A01.EXE–V2A71.EXE  # V2A remapped variants
│   ├── V2D*.EXE             # 16 V2D profiles
│   ├── V2DD*.EXE            # 4 DAT-preserving profiles
│   └── P*.DAT               # Generated .DAT files from original run
├── acs/
│   ├── RUNLOG.MD            # ACS run log with baseline contract
│   └── ADDRUN.SH            # Run result logger
├── docs/
│   ├── 01-patches-and-execution-theory.md  # Complete patch reference
│   ├── 02-tool-instructions.md              # Tool-specific instructions
│   ├── 03-dosbox-x-debugger-walkthrough.md  # DOSBox-X debugger walkthrough
│   ├── lastchat.md                            # This file — project state snapshot
│   ├── DOSBox‐X’s-Command‐Line-Options        # DOSBox-X CLI options (HTML)
│   ├── DOSBox‐X’s-Supported-Commands          # DOSBox-X commands (HTML)
│   └── README.debugger                        # DOSBox-X debugger docs (HTML)
├── sts-patch-rethink/       # Parallel rethink branch
├── patches/                 # (empty)
├── src/                     # (empty)
└── artifacts/               # (empty)
```

---

## 12. REMOTE REPOSITORY

**URL:** `https://github.com/cewatkins/stsordie.git`
**Branch:** `main`
**Last commit:** `240fb7f` — Fix: rewrite DOSBox-X debugger walkthrough

---

## 13. RETIRE / ARCHIVE RULES

1. Any profile regressing to user #0 → archived, do not re-test.
2. Any profile generating ROM-write spam → archived immediately.
3. A profile passes only if: farthest user > 4 AND DAT files populated.

---

## 14. DEBUGGING WORKFLOW — INT 6 BEST PRACTICE

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

**Never:** Stack unknown patches, apply broad NOP sweeps, use dynamic CPU core, ignore first INT 6.

**Always:** Keep STSorg.exe untouched, build from baseline only, record offset/old/new/reason/effect, one proven instruction per round, validate DAT files after each run.

---

## 15. DOSBOX-X DEBUGGER VS DOS DEBUG — DISTINCTION

DOSBox-X has **two** separate debugging mechanisms:

| | DOSBox-X Built-in Debugger | DOS DEBUG Program |
|---|---|---|
| **What** | Emulator-level debugger | Classic MS-DOS debugger (DEBUG.COM) |
| **Access** | `-break-start -debug` flags | Type `DEBUG` at DOS prompt |
| **Scope** | Inspect CPU/memory/ports/segments | Only DOS-visible memory |
| **Best for** | Hardware debugging, port I/O, ROM | In-DOS debugging, file I/O tracing |

---

## 16. QUICK REFERENCE — MINIMUM VIABLE PATCHES

| Patch | Offset | Bytes | Effect |
|-------|-----|-----|-----|
| selector_c5 | `0x04EB99` | `99` → `C5` | Take demo path |
| safe_stubs (3 ROM) | `0x04EC5A` | `9A F0 FF 00 F0` → `CB 90 90 90 90` | Neutralize ROM calls |
| safe_stubs (3 ROM) | `0x04EC5F` | `9A 00 00 00 C0` → `CB 90 90 90 90` | Neutralize ROM calls |
| safe_stubs (3 ROM) | `0x04EC64` | `9A 00 00 00 C8` → `CB 90 90 90 90` | Neutralize ROM calls |
| safe_stubs (19 stubs) | `0x04EC78` | `E8 00 00` → `C3 90 90` | Neutralize dispatch stubs |

---

## 17. DOCUMENTATION INDEX

| File | Purpose |
|------|-----|
| `docs/01-patches-and-execution-theory.md` | Complete patch reference, all 71 PCH variants, 16 V2D profiles, runtime outcomes, patch theory |
| `docs/02-tool-instructions.md` | Tool-specific instructions for DOSBox-X, IDA Free, Ghidra, DOS DEBUG |
| `docs/03-dosbox-x-debugger-walkthrough.md` | DOSBox-X built-in debugger walkthrough with step-by-step tracing |
| `docs/lastchat.md` | This file — complete project state snapshot |
| `stsds.md` | Project memory file for copilot instructions |
| `.github/copilot-instructions.md` | AI agent instructions for the project |
| `PATCH_MATRIX_RETHINK.md` | Patch matrix rethink with strategy |
| `demo/PCH_TEST_DIFFS.md` | PCH runtime outcome table |
| `demo/INT6_BEST_PRACTICE.md` | INT 6 debugging workflow |
| `demo/V2A_PROFILE_PLAN.md` | V2D demo run profile plan |
| `acs/RUNLOG.MD` | ACS run log with baseline contract |

---

## 18. NEXT STEPS (BLOCKED)

1. **No patched variant passes user #4** — only original writes populated `.DAT` files.
2. **Two active branches only:**
   - Branch A (fidelity-first): demo force + minimal overlap control, no entry bypass, no safe-stubs.
   - Branch B (progress-first): V2D9292 lineage with one-at-a-time branch control toggles.
3. **Reference contract:** Original baseline = "must write populated DATs before user#4+ stage."
4. **Add explicit `.DAT` validation checkpoint** after each run before deciding next patch.

---

## 19. ENVIRONMENT VARIABLES SUMMARY

| Variable | Value | When to Use |
|------|-----|-----|
| `NOCOM1=1` | Disable COM1 | When COM1 not needed |
| `NOCOM2=1` | Disable COM2 | When COM2 not needed |
| `NOCOM3=1` | Disable COM3 | When COM3 not connected |
| `NOCOM4=1` | Disable COM4 | When COM4 not connected |
| `POLL=1` | Polling mode | **No card / COM3/COM4 not wired / debugging** |
| `POLL=0` | Interrupt-driven | Original hardware with 16-channel serial card |

**Recommended for demo mode (no card):**
```batch
SET NOCOM3=1
SET NOCOM4=1
SET POLL=1
```
