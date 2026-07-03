# STS-12UC.EXE — Complete Patch Reference

**Target:** STS-12, a vintage DOS BBS host by Lightspeed Electronics (22 Glenside Road, South Orange, NJ 07079, (201)761-1793).
**Baseline SHA1:** `120f8d982a31de4bdd5292b65264491af0a2c11a`
**Goal:** Run demo mode in DOSBox-X/86Box without hardware card dependency, reach the 900-check stage, write populated `.DAT` files.

---

## 1. Binary Architecture

### 1.1 Entry Point

| Field | Value |
|-------|-------|
| File offset | `0x13D69` (seg000:C629) |
| Instruction | 23 CALL FAR instructions to internal segments (all relocated) |
| Call #1 | `4799:0000` → file `0x04F0D0` (Turbo Pascal runtime init) |
| Call #2 | `4759:0102` → file `0x04EDD2` (startup helper) |
| Call #3 | `4745:008A` → file `0x04EC1A` (demo/card init wrapper) |
| Call #4 | `46E3:0000` → file `0x04E570` |

### 1.2 The Reboot Mechanism

The program calls **24 hardcoded far addresses** into ROM — none in the relocation table, all absolute:

| Physical Address | What It Is |
|-----------------|------------|
| `F000:FFF0` | x86 CPU Reset Vector (reboots machine) |
| `C000:0000` | Video BIOS ROM |
| `C800:0000` | HDD Controller BIOS ROM |
| `C457:0Exx` (5 entries) | Expansion serial card ROM BIOS |
| `F07E:C402` | Specific BIOS entry point |
| `F946:8A00` | Above 1MB |

### 1.3 The Card Type Gate (Root Cause)

At file offset `0x04EB90`, the function decides the execution path:

```asm
; File offset 0x04EB90
MOV word [BP-0Eh], 0x0099    ; hardcoded card type constant
MOV AX, [BP-0Eh]             ; read it back
CMP AX, 0x0099h              ; compare with itself → always true
JNZ -> 0x04EC0C              ; NEVER TAKEN — falls through to reboot
```

Two card type codes:
- **`0x0099`** = 16-channel serial expansion card → ROM calls → reboot
- **`0x00C5`** = demo/standard mode → skip ROM calls → use COM1/COM2

The value `0x0099` was hardcoded at compile time for production card hardware. The `0x00C5` path exists but is unreachable because the constant is always `0x0099`.

### 1.4 Dispatch Stub Table

The `0x0099` init block patches stubs at runtime at seg041:00CA:

| Offset | Content | Purpose |
|--------|---------|---------|
| `0x04EC5A` | `9A F0 FF 00 F0` | CALL FAR F000:FFF0 (CPU reset) |
| `0x04EC5F` | `9A 00 00 00 C0` | CALL FAR C000:0000 (Video BIOS) |
| `0x04EC64` | `9A 00 00 00 C8` | CALL FAR C800:0000 (HDD BIOS) |
| `0x04EC78`–`0x04ECB1` | 19× `E8 00 00` | Channel dispatch stubs (NEAR CALL placeholders) |

The demo path (`0x00C5`) skips this entire patching block → stubs remain in factory state → INT6 when channels are used.

### 1.5 Environment Variables

Pascal shortstrings at file offset `0x01385A`:

| Variable | Purpose |
|----------|---------|
| `NOCOM1` | Disable/skip COM1 |
| `NOCOM2` | Disable/skip COM2 |
| `NOCOM3` | Disable/skip COM3 |
| `NOCOM4` | Disable/skip COM4 |
| `POLL` | Enable polling mode (COM3/COM4) |

### 1.6 Required Files

| File | Purpose |
|------|---------|
| `INFO1.TXT` – `INFO5.TXT` | Welcome/info screens |
| `CMD.TXT` | Command help text |
| `P####.DAT` | User/message database (page-numbered, e.g., P1000.DAT) |
| `STSCODE.BAT` | Written on shutdown with exit code |

---

## 2. All Patch Families — Complete Reference

### 2.1 Patch Action Reference

| Patch Name | File Offset | Before | After | Theory / Meaning |
|------------|-------------|--------|-------|-----------------|
| **selector_c5** | `0x04EB96` | `C7 46 F2 99 00` | `C7 46 F2 C5 00` | Forces AX=00C5 at the card type gate. Makes the startup routine take the demo path instead of the card ROM path. **This is the single most critical patch.** |
| **safe_stubs** | `0x04EC5A`–`0x04ECB4` | 3× CALL FAR + 19× CALL NEAR | 3× RETF+NOP + 19× RET+NOP | Neutralizes the dispatch stub cluster. Without this, the demo path leaves stubs in factory state (CALL FAR to ROM + CALL NEAR +0 chains) → INT6. |
| **nop_call3** | `0x13D73` | `9A 8A 00 45 47` | `90 90 90 90 90` | NOPs entry call #3 (demo/card init wrapper). Skips the card init entirely. Improves startup speed but weakens initialization fidelity. |
| **nop_call4** | `0x13D78` | `9A 00 00 E3 46` | `90 90 90 90 90` | NOPs entry call #4. Same effect as nop_call3. |
| **skip_reboot_call** | `0x04EC0A` | `EB 07` | `EB 0A` | In the demo path, changes a short JMP to skip past the EC5A call. Jumps to EC16 (return) instead of EC13 (call EC5A). |
| **cmp_c5** | `0x04EB9E` | `3D 99 00` | `3D C5 00` | Changes the comparison from `CMP AX,0099h` to `CMP AX,00C5h`. Alternative to selector_c5 — makes the check pass without modifying the stored value. |
| **jnz_to_jmp** | `0x04EBA1` | `75 69` | `EB 69` | Changes JNZ to unconditional JMP at the card type gate. Forces the card path regardless of AX value. |
| **csip_1978_retguard** | `0x44BC6` | `05 CC C2 B8 1C` | `C3 90 90 90 90` | Forces an immediate return from the suspect fault region at CS:IP 49B9:1978. Prevents RET 1CB8 path. |
| **csip_probe_cc** | `0x44BC8` | `C2 B8 1C` | `CC 90 90` | Forces INT3 (software breakpoint) at the same suspect site. Used for runtime probing — debugger breaks here. |
| **force_jz_taken** | `0x44BE4` | `74 06` | `EB 06` | At 49B9:1998 branch control: forces the JZ condition to always jump to 19A0. |
| **force_jz_not_taken** | `0x44BE4` | `74 06` | `90 90` | At 49B9:1998 branch control: NOPs the JZ, forces fall-through to 199A. |
| **force_zf1_no_memread** | `0x44BE4` area | (varies) | (varies) | Removes ES:DI memory read side effects at the decision point. Prevents reading uninitialized memory. |
| **midop_jmp_1992** | `0x44BE4` area | (varies) | (varies) | Redirects execution to overlap byte target at 1992. Most progress-preserving midop patch. |
| **midop_jmp_19a0** | `0x44BE4` area | (varies) | (varies) | Redirects execution to overlap byte target at 19A0. Triggers ROM write errors in DOSBox-X. |
| **midop_jmp_1c08** | `0x44BE4` area | (varies) | (varies) | Redirects execution to overlap byte target at 1C08. Alternate midop landing. |
| **midop_c2_to_cb** | `0x44BE4` area | (varies) | (varies) | Changes RETF semantics at overlap byte. RETF instead of jump. |
| **bypass_call_0ee8** | (varies) | (varies) | (varies) | Caller bypass into 1970 region. Destabilizes later control flow. |
| **bypass_call_2b82** | (varies) | (varies) | (varies) | Caller bypass into 1970 region. Destabilizes later control flow. |
| **bypass_call_2bb2** | (varies) | (varies) | (varies) | Caller bypass into 1970 region. Destabilizes later control flow. |

### 2.2 Patch Theory — Three-Layer Model

The patches operate across three layers of the execution flow:

```
Layer 1: Entry Point (0x13D69)
  └── 23 CALL FAR instructions to internal segments
  └── Call #3 → demo/card init wrapper (0x04EC1A)
  └── Patch targets: nop_call3, nop_call4

Layer 2: Card Type Gate (0x04EB90)
  └── MOV [BP-0Eh], 0x0099 → CMP AX, 0x0099 → JNZ
  └── If AX==0x0099: card path → ROM calls → reboot
  └── If AX==0x00C5: demo path → skip ROM → COM1/COM2
  └── Patch targets: selector_c5, cmp_c5, jnz_to_jmp

Layer 3: Dispatch Stub Table (0x04EC5A–0x04ECB4)
  └── 3× CALL FAR to ROM (F000:FFF0, C000:0000, C800:0000)
  └── 19× CALL NEAR +0 (channel dispatch placeholders)
  └── Patch targets: safe_stubs, skip_reboot_call
```

**Execution theory:**

1. **Entry** → 23 CALL FAR chain (Turbo Pascal init → demo/card init → ...)
2. **Card type gate** → decides card path (reboot) or demo path (COM1/COM2)
3. **Stub table** → if card path, patches stubs with card handler addresses; if demo path, stubs stay in factory state
4. **Channel operations** → calls through stub table → if demo path + no safe_stubs → INT6
5. **Midop region** → control flow around 49B9:1978 — branch control, overlap bytes
6. **User login** → progression through user accounts, writes .DAT files

### 2.3 Legacy Patch Artifacts (Root Folder)

| Artifact | SHA1 | Patch Intent |
|----------|------|-------------|
| `STS12UC.EXE` | `6a9e0432...` | Manually patched state (unknown exact combo) |
| `STS12UC.EXE.bypass` | `d9967dd2...` | Branch-forcing/bypass experiment |
| `STS12UC.EXE.bypass2` | `f90f7e08...` | Bypass variant lineage |
| `STS12UC.EXE.demo` | `18a52850...` | Demo-force lineage |
| `STS12UC.EXE.demo-test` | `18a52850...` | Identical to `.demo` |

---

## 3. Patch Variant Matrices

### 3.1 PCH Matrix (71 Variants)

Generated by `demo/mkpatch.py` from `STSorg.exe` baseline.

| Variant | Patch Set | Outcome |
|---------|-----------|---------|
| PCH01 | `selector_c5` | — |
| PCH02 | `selector_c5, safe_stubs` | — |
| PCH03 | `selector_c5, nop_call3` | — |
| PCH04 | `selector_c5, safe_stubs, nop_call3` | — |
| PCH05 | `selector_c5, nop_call3, nop_call4` | — |
| PCH06 | `selector_c5, safe_stubs, nop_call3, nop_call4` | — |
| PCH07 | `skip_reboot_call` | — |
| PCH08 | `skip_reboot_call, safe_stubs` | — |
| PCH09 | `cmp_c5, skip_reboot_call` | — |
| PCH10 | `jnz_to_jmp, safe_stubs` | — |
| PCH11 | `selector_c5, skip_reboot_call` | — |
| PCH12 | `selector_c5, skip_reboot_call, safe_stubs` | — |
| PCH13 | `selector_c5, cmp_c5, skip_reboot_call` | — |
| PCH14 | `selector_c5, cmp_c5, skip_reboot_call, safe_stubs` | — |
| PCH15 | `nop_call3` | — |
| PCH16 | `nop_call3, safe_stubs` | — |
| PCH17 | `nop_call4` | — |
| PCH18 | `skip_reboot_call, nop_call3` | — |
| PCH19 | `skip_reboot_call, safe_stubs, nop_call3` | — |
| PCH20 | `selector_c5, jnz_to_jmp, safe_stubs` | — |
| PCH21 | `csip_1978_retguard` | — |
| PCH22 | `selector_c5, csip_1978_retguard` | — |
| PCH23 | `selector_c5, safe_stubs, csip_1978_retguard` | — |
| PCH24 | `skip_reboot_call, csip_1978_retguard` | — |
| PCH25 | `skip_reboot_call, safe_stubs, csip_1978_retguard` | — |
| PCH26 | `selector_c5, jnz_to_jmp, safe_stubs, csip_1978_retguard` | — |
| PCH27 | `selector_c5, safe_stubs, csip_probe_cc` | — |
| PCH28 | `skip_reboot_call, safe_stubs, csip_probe_cc` | — |
| PCH29 | `selector_c5, jnz_to_jmp, safe_stubs, csip_probe_cc` | — |
| PCH30 | `selector_c5, safe_stubs, force_jz_taken` | — |
| PCH31 | `selector_c5, safe_stubs, force_jz_not_taken` | — |
| PCH32 | `selector_c5, safe_stubs, force_zf1_no_memread` | — |
| PCH33 | `selector_c5, safe_stubs, force_zf0_no_memread` | — |
| PCH34 | `skip_reboot_call, safe_stubs, force_zf1_no_memread` | — |
| PCH35 | `skip_reboot_call, safe_stubs, force_zf0_no_memread` | — |
| PCH36 | `selector_c5, safe_stubs, probe_path_a_cc` | — |
| PCH37 | `selector_c5, safe_stubs, probe_path_b_cc` | — |
| PCH38 | `skip_reboot_call, safe_stubs, probe_path_a_cc` | — |
| PCH39 | `skip_reboot_call, safe_stubs, probe_path_b_cc` | — |
| PCH40 | `selector_c5, safe_stubs, midop_c2_to_c3` | — |
| PCH41 | `skip_reboot_call, safe_stubs, midop_c2_to_c3` | — |
| PCH42 | `selector_c5, safe_stubs, midop_nop3` | — |
| PCH43 | `skip_reboot_call, safe_stubs, midop_nop3` | — |
| PCH44 | `selector_c5, safe_stubs, midop_c2_to_cb` | — |
| PCH45 | `skip_reboot_call, safe_stubs, midop_c2_to_cb` | — |
| PCH46 | `selector_c5, safe_stubs, midop_cb9090` | — |
| PCH47 | `skip_reboot_call, safe_stubs, midop_cb9090` | — |
| PCH48 | `selector_c5, safe_stubs, midop_jmp_197f` | — |
| PCH49 | `skip_reboot_call, safe_stubs, midop_jmp_197f` | — |
| PCH50 | `selector_c5, safe_stubs, midop_jmp_1985` | — |
| PCH51 | `skip_reboot_call, safe_stubs, midop_jmp_1985` | — |
| **PCH52** | `selector_c5, safe_stubs, midop_jmp_1992` | **account0-stop** (no INT6) |
| **PCH53** | `skip_reboot_call, safe_stubs, midop_jmp_1992` | **account0-stop** (no INT6) |
| PCH54 | `selector_c5, safe_stubs, midop_jmp_1998` | INT6 |
| PCH55 | `skip_reboot_call, safe_stubs, midop_jmp_1998` | INT6 |
| PCH56 | `selector_c5, safe_stubs, midop_jmp_19a0` | account0-stop |
| PCH57 | `skip_reboot_call, safe_stubs, midop_jmp_19a0` | account0-stop |
| **PCH58** | `selector_c5, safe_stubs, midop_jmp_1c08` | **account0-stop** (best midop-only) |
| PCH59 | `skip_reboot_call, safe_stubs, midop_jmp_1c08` | — |
| PCH60 | `selector_c5, safe_stubs, midop_jmp_1c0b` | INT6 |
| PCH61 | `skip_reboot_call, safe_stubs, midop_jmp_1c0b` | — |
| PCH62 | `selector_c5, safe_stubs, midop_jmp_1c08, probe_1a05` | — |
| PCH63 | `selector_c5, safe_stubs, midop_jmp_1c08, probe_1b5e` | — |
| PCH64 | `selector_c5, safe_stubs, midop_jmp_1c08, probe_1c03` | — |
| PCH65 | `skip_reboot_call, safe_stubs, midop_jmp_1c08, probe_1c03` | — |
| PCH66 | `selector_c5, safe_stubs, bypass_call_2b82` | — |
| PCH67 | `selector_c5, safe_stubs, bypass_call_2bb2` | — |
| PCH68 | `selector_c5, safe_stubs, bypass_call_2b82, bypass_call_2bb2` | INT6 |
| PCH69 | `selector_c5, safe_stubs, midop_jmp_1c08, bypass_call_2b82, bypass_call_2bb2` | account0-stop |
| PCH70 | `selector_c5, safe_stubs, bypass_call_0ee8, bypass_call_2b82, bypass_call_2bb2` | INT6 |
| PCH71 | `skip_reboot_call, safe_stubs, bypass_call_0ee8, bypass_call_2b82, bypass_call_2bb2` | INT6 |

### 3.2 V2A Profile Matrix (16 Profiles)

Generated by `demo/mkpatch_v2a.py` — 8.3-safe names, practical test profiles.

| Profile | Output | Patch Set | Intent |
|---------|--------|-----------|--------|
| demo-min | V2DMIN.EXE | `selector_c5` | Force demo mode only; closest to original |
| demo-noenv | V2DNOEV.EXE | `selector_c5, nop_call3, nop_call4` | Avoid COM3/COM4 env gating |
| demo-noenv-skipreboot | V2DNONR.EXE | `selector_c5, nop_call3, nop_call4, skip_reboot_call` | Same + avoid reboot branch |
| demo-900-target | V2D900.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_1c08` | Beyond user#0, no caller bypass |
| demo-safe | V2DSAFE.EXE | `selector_c5, safe_stubs` | Fallback for unstable stub paths |
| demo-900-basejmp | V2D90BJ.EXE | `selector_c5, midop_jmp_1c08` | Preserve entry calls for DAT init |
| demo-900-j1992 | V2D9292.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_1992` | V2D900 lineage, less abrupt landing |
| demo-900-j19a0 | V2D92A0.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_19a0` | V2D900 lineage, 19A0 entry |
| demo-900-cb | V2D90CB.EXE | `selector_c5, nop_call3, nop_call4, midop_c2_to_cb` | RETF semantics at overlap |
| demo-9292-jzsafe | V2D92NS.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_1992, force_jz_not_taken` | Force away from 19A0 branch |
| demo-9292-jztaken | V2D92JT.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_1992, force_jz_taken` | A/B compare against jzsafe |
| demo-9292-zf1 | V2D92ZF.EXE | `selector_c5, nop_call3, nop_call4, midop_jmp_1992, force_zf1_no_memread` | Remove ES:DI memread side effects |
| demo-dat-j1992 | V2DD992.EXE | `selector_c5, midop_jmp_1992` | Preserve init/data-write path |
| demo-dat-j1992-ns | V2DD99N.EXE | `selector_c5, midop_jmp_1992, force_jz_not_taken` | DAT-preserving, avoid 19A0 |
| demo-dat-j1992-zf1 | V2DD99Z.EXE | `selector_c5, midop_jmp_1992, force_zf1_no_memread` | DAT-preserving, no ES:DI memread |
| demo-dat-j19a0 | V2DD9A0.EXE | `selector_c5, midop_jmp_19a0` | DAT-preserving, direct 19A0 entry |

### 3.3 V2A Name Remap (71 Variants)

`V2A01.EXE`–`V2A71.EXE` — name-only remap of PCH families. Same behavior class as corresponding PCH.

---

## 4. Runtime Outcome Matrix

### 4.1 Active Candidates (Priority Order)

| Priority | Variant | Reached | Outcome | DAT Files |
|----------|---------|---------|---------|-----------|
| 1 | **V2D9292.EXE** | user #4 | INT6 | Not like original |
| 2 | **V2D900.EXE** | user #4 | INT6 | Not like original |
| 3 | **STSorg.exe** (original) | beyond user #4 | Reboots later | **Populated (non-zero)** |

### 4.2 Archived / Frozen

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

### 4.3 PCH Historical Outcomes

| Outcome | Variants |
|---------|----------|
| account0-stop (no INT6) | PCH52, PCH53, PCH56, PCH57, PCH58, PCH69 |
| INT6 | PCH54, PCH55, PCH60, PCH68, PCH70, PCH71 |
| Best midop-only | PCH58 |

---

## 5. Hard Constraints & Lessons Learned

1. **No patched profile passes user #4** — only original baseline writes populated `.DAT` files.
2. **Entry bypasses (nop_call3/nop_call4)** improve startup speed but weaken initialization fidelity.
3. **19A0-leaning branches** trigger invalid memory/ROM writes in DOSBox-X.
4. **Caller bypass patches** destabilize later control flow, increase INT6 risk.
5. **Midop_jmp_1992 / midop_jmp_1c08** are the most progress-preserving but stall at user #4.
6. **Original baseline** reboots/fails later (after checks like CMD.TXT path) but reliably writes populated `.DAT` files.
7. **Demo mode is built-in** — the EXE is already the demo build (2-line cap, passwords disabled). The 00C5 selector just makes it reachable.
8. **All patching must start from STSorg.exe** — never stack patches from previous runs.

---

## 6. Key File Offsets Reference

| Offset | Content |
|--------|---------|
| `0x013D69` | Entry point (23 CALL FAR instructions) |
| `0x013D73` | Entry call #3 (4745:008A) |
| `0x013D78` | Entry call #4 (46E3:0000) |
| `0x01385A` | Environment variable strings |
| `0x04EB90` | Card type gate function |
| `0x04EB96` | selector_c5 patch target (`C7 46 F2 99 00`) |
| `0x04EB99` | selector_c5 byte target (99 → C5) |
| `0x04EBA1` | jnz_to_jmp patch target (75 → EB) |
| `0x04EC0A` | skip_reboot_call patch target (EB 07 → EB 0A) |
| `0x04EC1A` | demo/card init wrapper |
| `0x04EC5A` | ROM stub 1 (F000:FFF0) |
| `0x04EC5F` | ROM stub 2 (C000:0000) |
| `0x04EC64` | ROM stub 3 (C800:0000) |
| `0x04EC78` | Dispatch stub table start (19× E8 00 00) |
| `0x04ECB1` | Dispatch stub table end |
| `0x44BE4` | force_jz_taken/not_taken target |
| `0x44BC6` | csip_1978_retguard target |

---

## 7. Tools & Scripts

| Tool | Purpose |
|------|---------|
| `sts_patch.pl` | Perl patcher (legacy): `--demo`, `--safe-stubs`, `--bypass`, `--fail-cmp`, `--infinite` |
| `demo/mkpatch.py` | Python patch generator (PCH01–PCH71) |
| `demo/mkpatch_v2a.py` | V2A name remap |
| `demo/mz_map.py` | MZ SEG:OFF → file offset mapper |
| `acs/ADDRUN.SH` | Run result logger |
| `SETCO.BAT` | Environment variable setup |
| `SETDBG.BAT` | DOS DEBUG setup |

---

## 8. Retire / Archive Rules

1. Any profile regressing to user #0 → archived, do not re-test.
2. Any profile generating ROM-write spam → archived immediately.
3. A profile passes only if: farthest user > 4 AND DAT files populated.

---

## 9. Current Status (2026-07-03)

**BLOCKED:** No patched variant reaches past user #4 with populated `.DAT` files.

**Next cycle — two branches only:**
- **Branch A (fidelity-first):** demo force + minimal overlap control, no entry bypass, no safe-stubs.
- **Branch B (progress-first):** V2D9292 lineage with one-at-a-time branch control toggles.

**Reference contract:** Original baseline behavior = "must write populated DATs before user#4+ stage."
