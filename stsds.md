# STS-12UC.EXE Reverse Engineering — Project Status & Memory (stsds.md)

**Generated:** 2026-07-03
**Purpose:** Consolidated project memory — all findings, patch history, runtime outcomes, and current status from the full conversation history (claude0.ph through claude5.ph, claudetalk, all .md files).

---

## 1. Project Summary

**Target:** `STS12UC.EXE` — STS-12, a vintage DOS BBS host by Lightspeed Electronics.
**Baseline SHA1:** `120f8d982a31de4bdd5292b65264491af0a2c11a`
**Goal:** Run demo mode in DOSBox-X/86Box without hardware card, reach 900-check stage, write populated `.DAT` files.

---

## 2. Root Cause — Why It Reboots

The binary has **24 hardcoded far calls** into specific ROM addresses (not in the relocation table):

| Physical Address | What It Is |
|-----------------|------------|
| F000:FFF0 | x86 CPU Reset Vector |
| C000:0000 | Video BIOS ROM |
| C800:0000 | HDD Controller BIOS ROM |
| C457:0Exx (5 entries) | Expansion serial card ROM BIOS |
| F07E:C402 | Specific BIOS entry point |
| F946:8A00 | Above 1MB |

The **card type gate** at file offset `0x04EB90` decides the path:
```asm
MOV word [BP-0Eh], 0x0099    ; hardcoded card type
CMP AX, 0x0099h               ; always true
JNZ -> 0x04EC0C               ; NEVER TAKEN — falls through to reboot
```

- **0x0099** = 16-channel serial card → ROM calls → reboot
- **0x00C5** = demo/standard mode → skip ROM → COM1/COM2

**The fix:** Patch byte at `0x04EB99` from `99` to `C5`.

---

## 3. Why INT 6 Happens After the Fix

The 0x0099 init block also patches a **dispatch stub table** at runtime (seg041:00CA):
- 3x CALL FAR to ROM (F000:FFF0, C000:0000, C800:0000)
- 19x CALL NEAR placeholder stubs (E8 00 00)

Demo path (0x00C5) skips this → stubs stay in factory state → INT6 when channels are used.

**19 patches applied:**
| # | Offset | Before | After | Purpose |
|--|--------|--------|-------|-----|
| 1 | 0x04EB99 | 99 | C5 | Take demo path |
| 2 | 0x04EC5A | 9A F0 FF 00 F0 | CB 90 90 90 90 | F000:FFF0 → RETF |
| 3 | 0x04EC5F | 9A 00 00 00 C0 | CB 90 90 90 90 | C000:0000 → RETF |
| 4 | 0x04EC64 | 9A 00 00 00 C8 | CB 90 90 90 90 | C800:0000 → RETF |
| 5–19 | 0x04EC78–0x04ECB1 | E8 00 00 | C3 90 90 | 19 dispatch stubs → RET |

---

## 4. Patch Families (mkpatch.py — 71 variants)

| Family | Description |
|--------|------------|
| `selector_c5` | Force AX=00C5 at 0x04EB96 |
| `safe_stubs` | Neutralize ROM stub cluster at 0x04EC5A–0x04ECB4 |
| `nop_call3/4` | NOP entry calls at 0x13D73/0x13D78 |
| `skip_reboot_call` | Jump past EC5A at 0x04EC0A |
| `midop_*` | Overlap control around 49B9:1978 (jmp to 1992/19a0/1c08/etc.) |
| `bypass_call_*` | Caller bypasses (DESTROYED — causes INT6) |
| `force_jz_taken/not_taken` | Branch control at 0x44BE4 |
| `force_zf1_no_memread` | Remove ES:DI memread side effect |

---

## 5. Runtime Outcome Matrix

### Active Candidates
| Priority | Variant | Reached | Outcome |
|------|--------|---------|-----|
| 1 | V2D9292.EXE | user #4 | INT6 |
| 2 | V2D900.EXE | user #4 | INT6 |
| 3 | STSorg.exe (original) | beyond user #4 | Reboots later, writes populated DATs |

### Archived
| Variant | Outcome | Reason |
|---------|-----|--------|
| V2D90BJ.EXE | user #0 stop | Regressed |
| V2D90CB.EXE | early INT6 | Unsafe |
| V2D92A0.EXE | ROM write errors (F000) | Unsafe |
| V2DD992/99N/99Z/9A0 | user #0 stop | Regressed |
| All bypass_call_* | INT6 | Destabilizes flow |
| All midop_jmp_19a0 | ROM write errors | Unsafe |

### PCH Historical
| Outcome | Variants |
|---------|-----|
| account0-stop | PCH52, PCH53, PCH56–PCH58 |
| INT6 | PCH54, PCH55, PCH60, PCH68–PCH71 |

---

## 6. Hard Constraints & Lessons

1. **No patched variant passes user #4** — only original writes populated `.DAT` files.
2. **Entry bypasses** weaken initialization fidelity.
3. **19A0 branches** trigger ROM writes in DOSBox-X.
4. **Caller bypass patches** destabilize control flow.
5. **Midop_jmp_1992/1c08** are most progress-preserving but stall at user #4.
6. **Demo mode is built-in** — EXE is already demo build (2-line cap, passwords disabled).
7. **Environment variables:** NOCOM1–4, POLL (Pascal shortstrings at 0x01385A).

---

## 7. Current Status

**BLOCKED:** No patched variant reaches past user #4 with populated `.DAT` files.

**Next cycle — two branches only:**
- **Branch A (fidelity-first):** demo force + minimal overlap control, no entry bypass, no safe-stubs.
- **Branch B (progress-first):** V2D9292 lineage with one-at-a-time branch control toggles.

**Reference contract:** Original baseline = "must write populated DATs before user#4+ stage."

---

## 8. Key File Offsets

| Offset | Content |
|--------|-----|
| 0x013D69 | Entry point (23 CALL FAR) |
| 0x04EB90 | Card type gate function |
| 0x04EB99 | selector_c5 target (99→C5) |
| 0x04EBA1 | jnz_to_jmp target (75→EB) |
| 0x04EC0A | skip_reboot_call target |
| 0x04EC5A | ROM stub 1 |
| 0x04EC5F | ROM stub 2 |
| 0x04EC64 | ROM stub 3 |
| 0x04EC78 | Dispatch stub table start |
| 0x44BE4 | force_jz target |
| 0x44BC6 | csip_1978_retguard target |

---

## 9. Tools

| Tool | Purpose |
|------|-----|
| `sts_patch.pl` | Perl patcher (legacy) |
| `demo/mkpatch.py` | Python patch generator (PCH01–PCH71) |
| `demo/mkpatch_v2a.py` | V2A name remap |
| `demo/mz_map.py` | MZ SEG:OFF → file offset mapper |
| `acs/ADDRUN.SH` | Run result logger |

---

## 10. DOSBox-X Debug Config

```ini
[cpu]
core=normal
cputype=386_slow
cycles=fixed 20000
```

---

## 11. Workspace Structure

```
~/sb/
├── STS12UC.EXE.bak          # Original baseline
├── sts_patch.pl             # Perl patcher
├── SETCO.BAT                # Env var setup
├── log.txt                  # DOSBox-X log
├── claude0.ph – claude5.ph  # Session logs
├── claudetalk               # Full transcript
├── demo/
│   ├── STSorg.exe           # Clean baseline
│   ├── stsdemo.exe          # selector_c5 only
│   ├── stsdemo_safe.exe     # selector_c5 + safe_stubs
│   ├── mkpatch.py           # Patch generator
│   ├── mkpatch_v2a.py       # V2A remap
│   ├── mz_map.py            # Address mapper
│   ├── PATCHES.TXT          # PCH manifest
│   ├── V2A_PROFILES.TXT     # V2D manifest
│   ├── PCH_TEST_DIFFS.md    # PCH outcomes
│   ├── INT6_BEST_PRACTICE.md # Debug workflow
│   ├── V2A_PROFILE_PLAN.md  # V2D plan
│   ├── PCH01.EXE–PCH71.EXE  # 71 variants
│   ├── V2A01.EXE–V2A71.EXE  # V2A variants
│   ├── V2D*.EXE             # 16 V2D profiles
│   ├── V2DD*.EXE            # 4 DAT-preserving
│   └── P*.DAT               # Generated data files
├── acs/RUNLOG.MD            # ACS run log
├── acs/ADDRUN.SH            # Run logger
└── sts-patch-rethink/       # Parallel branch
```

---

## 12. Retire / Archive Rules

1. Profile regresses to user #0 → archived.
2. Profile generates ROM-write spam → archived immediately.
3. Pass criteria: farthest user > 4 AND DAT files populated.
