# STS-12UC.EXE Reverse Engineering & Patching Project — Project Status & Memory

## Project Overview

**Target:** `STS12UC.EXE` — STS-12, a vintage DOS BBS (Bulletin Board System) host program by Lightspeed Electronics (22 Glenside Road, South Orange, NJ 07079, (201)761-1793). "The Jungle" was a known BBS running this software.

**Goal:** Make the demo build run in DOSBox-X/86Box without hardware card dependency, reaching the 900-check stage (user login progression) and writing populated `.DAT` files.

**Baseline SHA1:** `120f8d982a31de4bdd5292b65264491af0a2c11a` (all variants derive from this).

---

## Workspace Layout

```
~/sb/
├── STS12UC.EXE.bak          # Original baseline (SHA1: 120f8d...c11a)
├── sts_patch.pl             # Perl patcher: --demo, --safe-stubs, --bypass, --fail-cmp, --infinite
├── SETCO.BAT                # SET NOCOM3=1, SET NOCOM4=1, SET POLL=1
├── log.txt                  # DOSBox-X runtime log
├── claude0.ph / claude1.5 / claude2.ph / claude3.ph / claude5.ph  # Session logs
├── claudetalk               # Full conversation transcript
├── demo/
│   ├── STSorg.exe           # Clean baseline copy (byte-identical)
│   ├── stsdemo.exe          # selector_c5 only (0099→00C5)
│   ├── stsdemo_safe.exe     # selector_c5 + safe_stubs
│   ├── mkpatch.py           # Python patch generator (PCH01..PCH71)
│   ├── mkpatch_v2a.py       # V2A name remap of PCH
│   ├── mz_map.py            # MZ SEG:OFF → file offset mapper
│   ├── PATCHES.TXT          # PCH variant → patch set manifest
│   ├── V2A_PROFILES.TXT     # V2D profile manifest (16 profiles)
│   ├── PCH_TEST_DIFFS.md    # Runtime outcome table for PCH variants
│   ├── INT6_BEST_PRACTICE.md # INT6 debugging workflow
│   ├── V2A_PROFILE_PLAN.md  # V2D demo run profile plan
│   ├── PCH01.EXE..PCH71.EXE # Generated patch variants
│   ├── V2A01.EXE..V2A71.EXE # V2A remapped variants
│   ├── V2D*.EXE             # V2D profile outputs (16 variants)
│   ├── V2DD*.EXE            # DAT-preserving profile outputs (4 variants)
│   ├── P1000.DAT..P1501.DAT # Generated .DAT files from original run
│   └── CAPINT6.TXT          # INT6 capture notes
├── acs/
│   ├── RUNLOG.MD            # ACS run log with baseline contract
│   └── ADDRUN.SH            # Run result logger
├── sts-patch-rethink/       # Parallel rethink branch
├── patches/                 # (empty)
├── src/                     # (empty)
├── artifacts/               # (empty)
└── logs/                    # (empty)
```

---

## Binary Architecture (Key Findings)

### Entry Point
- **File offset:** `0x13D69` (seg000:C629)
- **23 CALL FAR instructions** to internal segments (all relocated)
- First call target: `4799:0000` → file `0x04F0D0` (Turbo Pascal runtime init)
- Call #3 target: `4745:008A` → file `0x04EC1A` (demo/card init wrapper)

### The Reboot Mechanism
The program calls hardcoded far addresses into ROM:

| Offset | Target | Purpose |
|--------|--------|---------|
| seg041:00CA | F000:FFFF | x86 BIOS Reset Vector (CPU reboot) |
| seg041:00CF | C000:0000 | Video BIOS ROM |
| seg041:00D4 | C800:0000 | HDD Controller BIOS ROM |
| 24x total | C457:0Exx | Expansion card ROM (serial/modem card BIOS) |

### The Card Type Gate (Root Cause)
At file offset `0x04EB90`, function checks card type:
```
MOV word [BP-0Eh], 0x0099    ; hardcoded card type
CMP AX, 0x0099h               ; compare with itself → always true
JNZ -> 0x04EC0C               ; NEVER TAKEN
; falls through to ROM reboot calls
```

Two card type codes:
- **0x0099** = 16-channel serial expansion card → ROM calls → reboot
- **0x00C5** = demo/standard mode → skip ROM calls → use COM1/COM2

### Dispatch Stub Table (at seg041:00CA)
The 0x0099 init block patches stubs at runtime:
- 3x CALL FAR to ROM (F000:FFF0, C000:0000, C800:0000)
- 19x CALL NEAR placeholder stubs (E8 00 00)
- Demo path (0x00C5) skips this entirely → stubs remain in factory state → INT6

### Environment Variables (Pascal shortstrings at 0x01385A)
| Variable | Purpose |
|----------|---------|
| NOCOM1 | Disable/skip COM1 |
| NOCOM2 | Disable/skip COM2 |
| NOCOM3 | Disable/skip COM3 |
| NOCOM4 | Disable/skip COM4 |
| POLL | Enable polling mode (COM3/COM4) |

### Required Files
| File | Purpose |
|------|---------|
| INFO1.TXT – INFO5.TXT | Welcome/info screens |
| CMD.TXT | Command help text |
| P####.DAT | User/message database (page-numbered) |
| STSCODE.BAT | Written on shutdown with exit code |

---

## Patch Families (from mkpatch.py)

| Patch Action | Description |
|-------------|-------------|
| `selector_c5` | Force AX=00C5 at 0x04EB96 (demo mode) |
| `safe_stubs` | Neutralize ROM stub cluster at 0x04EC5A–0x04ECB4 |
| `nop_call3` | NOP entry call #3 at 0x13D73 |
| `nop_call4` | NOP entry call #4 at 0x13D78 |
| `skip_reboot_call` | Jump past EC5A call at 0x04EC0A |
| `cmp_c5` | Change CMP AX,0099 to CMP AX,00C5 at 0x04EB9E |
| `jnz_to_jmp` | JNZ→JMP at 0x04EBA1 |
| `csip_1978_retguard` | Force return at 0x44BC6 |
| `csip_probe_cc` | Force INT3 probe at 0x44BC8 |
| `force_jz_taken` | 74 06→EB 06 at 0x44BE4 |
| `force_jz_not_taken` | 74 06→90 90 at 0x44BE4 |
| `force_zf1_no_memread` | Remove ES:DI memread side effect |
| `midop_*` | Overlap/midop control around 49B9:1978 |
| `bypass_call_*` | Caller bypasses into 1970 |
| `probe_*` | Runtime probes (INT3) |

---

## Runtime Outcome Matrix (Current State)

### Active Candidates (Priority Order)
| Priority | Variant | Why Keep |
|----------|---------|----------|
| 1 | V2D9292.EXE | Best progress (user #4), no ROM-write spam |
| 2 | V2D900.EXE | Also reaches user #4, alternate midop landing |
| 3 | STSorg.exe | Behavioral reference for DAT population |

### Archived / Frozen
| Variant | Outcome | Reason |
|---------|---------|--------|
| V2D90BJ.EXE | user #0 stop | Regressed |
| V2D90CB.EXE | early INT6 | Unsafe |
| V2D92A0.EXE | ROM write errors (F000) | Unsafe branch |
| V2DD992.EXE | user #0 stop | Regressed |
| V2DD99N.EXE | user #0 stop | Regressed |
| V2DD99Z.EXE | user #0 stop | Regressed |
| V2DD9A0.EXE | user #0 stop | Regressed |
| All bypass_call_* variants | INT6 | Destabilizes control flow |
| All midop_jmp_19a0 variants | ROM write errors | Unsafe |

### PCH Historical Outcomes
| Variant | Outcome |
|---------|---------|
| PCH52–PCH53, PCH56–PCH58 | account0-stop (no INT6) |
| PCH58 | Best prior midop-only behavior |
| PCH54–PCH55, PCH60, PCH68–PCH71 | INT6 |

---

## Hard Constraints & Lessons Learned

1. **No patched profile passes user #4** — only original baseline writes populated `.DAT` files.
2. **Entry bypasses (nop_call3/nop_call4)** improve startup speed but weaken initialization fidelity.
3. **19A0-leaning branches** trigger invalid memory/ROM writes in DOSBox-X.
4. **Caller bypass patches** destabilize later control flow, increase INT6 risk.
5. **Midop_jmp_1992 / midop_jmp_1c08** are the most progress-preserving but stall at user #4.
6. **Original baseline** reboots/fails later (after checks like CMD.TXT path) but reliably writes populated `.DAT` files.
7. **Demo mode is built-in** — the EXE is already the demo build (2-line cap, passwords disabled). The 00C5 selector just makes it reachable.

---

## Debugging Workflow (INT6 Best Practice)

1. **Freeze baseline:** Keep `STSorg.exe` untouched. Build from baseline only.
2. **Deterministic CPU:** `core=normal`, `cputype=386_slow`, `cycles=fixed 20000` in DOSBox-X.
3. **Capture first fault:** Get CS:IP at first INT6 + load_seg.
4. **Map to file offset:** `./mz_map.py STSorg.exe --runtime CS:IP --load-seg XXXX`
5. **Patch minimally:** One proven instruction per round. Re-test. Repeat.
6. **Keep patch log:** Record offset, old bytes, new bytes, reason, effect.

---

## Run Result Format

```
| DATE | VARIANT | Farthest User | DAT Status | Outcome | First Fault CS:IP | Notes |
```

Outcome values: `PASS`, `account0-stop`, `900-message`, `INT6`, `reboot`, `freeze`

---

## Retire / Archive Rules

1. Any profile regressing to user #0 → archived, do not re-test.
2. Any profile generating ROM-write spam → archived immediately.
3. A profile passes only if: farthest user > 4 AND DAT files populated.

---

## Current Status (2026-07-03)

**BLOCKED:** No patched variant reaches past user #4 with populated `.DAT` files.
**NEXT CYCLE:** Two active branches only:
- **Branch A (fidelity-first):** demo force + minimal overlap control, no entry bypass, no safe-stubs.
- **Branch B (progress-first):** V2D9292 lineage with one-at-a-time branch control toggles.

**Reference contract:** Original baseline behavior = "must write populated DATs before user#4+ stage."

---

## Key File Offsets Reference

| Offset | Content |
|--------|---------|
| 0x013D69 | Entry point (23 CALL FAR instructions) |
| 0x013D73 | Entry call #3 (4745:008A) |
| 0x013D78 | Entry call #4 (46E3:0000) |
| 0x01385A | Environment variable strings |
| 0x04EB90 | Card type gate function |
| 0x04EB96 | selector_c5 patch target (C7 46 F2 99 00) |
| 0x04EB99 | selector_c5 byte target (99 → C5) |
| 0x04EBA1 | jnz_to_jmp patch target (75 → EB) |
| 0x04EC0A | skip_reboot_call patch target (EB 07 → EB 0A) |
| 0x04EC1A | demo/card init wrapper |
| 0x04EC5A | ROM stub 1 (F000:FFF0) |
| 0x04EC5F | ROM stub 2 (C000:0000) |
| 0x04EC64 | ROM stub 3 (C800:0000) |
| 0x04EC78 | Dispatch stub table start (19x E8 00 00) |
| 0x04ECB1 | Dispatch stub table end |
| 0x44BE4 | force_jz_taken/not_taken target |
| 0x44BC6 | csip_1978_retguard target |

---

## Tools & Scripts

| Tool | Purpose |
|------|---------|
| `sts_patch.pl` | Perl patcher (legacy) |
| `demo/mkpatch.py` | Python patch generator (PCH01..PCH71) |
| `demo/mkpatch_v2a.py` | V2A name remap |
| `demo/mz_map.py` | MZ SEG:OFF → file offset mapper |
| `acs/ADDRUN.SH` | Run result logger |
| `SETCO.BAT` | Environment variable setup |
| `SETDBG.BAT` | Debugger setup |

---

## DOSBox-X Configuration for Debugging

```ini
[cpu]
core=normal
cputype=386_slow
cycles=fixed 20000

[serial]
serial1=true active true port 3f8 irq 4
serial2=true active true port 2f8 irq 3
```

---

## DOSBox-X Debugger vs DOS DEBUG — CRITICAL DISTINCTION

DOSBox-X has **two** separate debugging mechanisms:

| | DOSBox-X Built-in Debugger | DOS DEBUG Program |
|---|---|---|
| **What** | Emulator-level debugger | Classic MS-DOS debugger (DEBUG.COM) |
| **Access** | `-break-start -debug` flags | Type `DEBUG` at DOS prompt |
| **Scope** | Inspect CPU/memory/ports/segments | Only DOS-visible memory |
| **Best for** | Hardware debugging, port I/O, ROM | In-DOS debugging, file I/O tracing |

**DOSBox-X built-in commands:** `r`, `u`, `d`, `bpx`, `g`, `t`, `p`, `q`, `mem`, `cpu`, `seg`, `stack`, `int`, `port`, `log`, `trace`, `tracefile`, `i`, `o`, `s`, `c`, `h`

**DOS DEBUG commands:** `r`, `u`, `d`, `e`, `bpx`, `g`, `t`, `p`, `q`

**Never confuse the two.** DOSBox-X built-in debugger has `mem`, `cpu`, `seg`, `stack`, `int`, `port` that DOS DEBUG does NOT have.

## Documentation Index

| File | Purpose |
|------|---|
| `docs/01-patches-and-execution-theory.md` | Complete patch reference, all 71 PCH variants, 16 V2D profiles, runtime outcomes |
| `docs/02-tool-instructions.md` | Tool-specific instructions for DOSBox-X, IDA Free, Ghidra, DOS DEBUG |
| `docs/03-dosbox-x-debugger-walkthrough.md` | DOSBox-X built-in debugger walkthrough |
| `docs/lastchat.md` | Complete project state snapshot (this is the master reference) |
| `stsds.md` | Project memory file for copilot instructions |
| `PATCH_MATRIX_RETHINK.md` | Patch matrix rethink with strategy |
| `demo/PCH_TEST_DIFFES.md` | PCH runtime outcome table |
| `demo/INT6_BEST_PRACTICE.md` | INT 6 debugging workflow |
| `demo/V2A_PROFILE_PLAN.md` | V2D demo run profile plan |
| `acs/RUNLOG.MD` | ACS run log with baseline contract |

## Remote Repository

**URL:** `https://github.com/cewatkins/stsordie.git`
**Branch:** `main`

## Historical Context

STS-12 was designed for a 16-channel serial expansion card (likely Digiboard/ARNET Multiport). The C457 segment (physical 0xC53xx) was the card's ROM BIOS. The same EXE binary runs 16-channel systems on original hardware. Demo mode exists but was unreachable from the shipped binary due to the hardcoded 0x0099 card type constant.
