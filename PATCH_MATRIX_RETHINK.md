# Patch Matrix Rethink (~/sb + ~/sb/demo)

## 1) Ground Truth Baselines

| Artifact | SHA1 | Notes |
|---|---|---|
| STS12UC.EXE.bak (root) | 120f8d982a31de4bdd5292b65264491af0a2c11a | Original baseline |
| STSorg.exe (demo) | 120f8d982a31de4bdd5292b65264491af0a2c11a | Byte-identical to baseline |
| STS12UC.EXE.bak (demo) | 120f8d982a31de4bdd5292b65264491af0a2c11a | Byte-identical to baseline |

Conclusion: all patching branches from one true baseline (`120f8d...c11a`).

---

## 2) Root Folder Patch Artifacts (Legacy Branch)

Source logic: `sts_patch.pl` options (`--demo`, `--safe-stubs`, `--bypass`, `--fail-cmp`, `--infinite`).

| Artifact | SHA1 | Inferred Patch Intent |
|---|---|---|
| STS12UC.EXE | 6a9e04326e4fa36481d049e11e31e8e89301992b | Manually patched state (unknown exact combo from current snapshot) |
| STS12UC.EXE.bypass | d9967dd2eb1076662535543715de51c9c517edaa | Branch-forcing/bypass experiment lineage |
| STS12UC.EXE.bypass2 | f90f7e08778e1a30560ea89d157a0b99a87f3829 | Bypass variant lineage |
| STS12UC.EXE.demo | 18a5285059734d7aaaf43ba1e95ae228aea7badf | Demo-force lineage |
| STS12UC.EXE.demo-test | 18a5285059734d7aaaf43ba1e95ae228aea7badf | Identical to `.demo` |

Risk: legacy root artifacts are not self-describing. Only hashes distinguish exact states.

---

## 3) Demo Folder Patch Families (Generated Branches)

### 3.1 PCH matrix (`mkpatch.py`, `PATCHES.TXT`)
- Range: `PCH01..PCH71`
- Major families:
  - selector/demo force: `selector_c5`
  - startup stub neutralization: `safe_stubs`
  - entry call bypass: `nop_call3`, `nop_call4`
  - reboot edge bypass: `skip_reboot_call`
  - overlap/midop control around `49B9:1978`: `midop_*`
  - caller bypasses into `1970`: `bypass_call_*`
  - probes: `probe_*`, `csip_probe_cc`

Historical signal from `PCH_TEST_DIFFS.md`:
- Midop `1992`/`19a0` families reached `account0-stop` in some variants.
- Caller-bypass stack variants (68/70/71) often INT6.

### 3.2 V2A full remap (`V2A01..V2A71`)
- Name-only remap of PCH families.
- Same behavior class as corresponding PCH.

### 3.3 V2D profile branch (`V2A_PROFILES.TXT`)
- Goal: practical test profiles with 8.3-safe names.
- Includes targeted families:
  - `V2D900`, `V2D9292`, `V2D92A0`, `V2D90CB`
  - safety and branch controls: `V2D92NS`, `V2D92JT`, `V2D92ZF`
  - DAT-preserving profiles: `V2DD992`, `V2DD99N`, `V2DD99Z`, `V2DD9A0`

---

## 4) Current Runtime Outcome Matrix (User-reported)

| Variant | Reached | Outcome | DAT Files |
|---|---|---|---|
| Original baseline (`STS12UC.EXE.bak` / `STSorg.exe`) | Beyond user #4, further process | Reboots/fails later (after checks like CMD.TXT path) | Populated (non-zero) |
| V2D900.EXE | user #4 | INT6 | Not like original (insufficient/empty compared to original) |
| V2D9292.EXE | user #4 | INT6 | Not like original |
| V2D90BJ.EXE | user #0 | Stops/regresses | Not useful |
| V2D90CB.EXE | early/user<4 | INT6 | Not useful |
| V2D92A0.EXE | divergent path | DOSBox-X ROM write errors (`F000`/`lin=fda..`) | Unsafe branch |
| V2DD992.EXE | user #0 | Stops/regresses | Not useful |
| V2DD99N.EXE | user #0 | Stops/regresses | Not useful |
| V2DD99Z.EXE | not past user #0 | Regresses | Not useful |
| V2DD9A0.EXE | not past user #0 | Regresses | Not useful |

Observed hard constraint: no patched profile currently passes user #4; only original reliably writes populated `.DAT` files.

---

## 5) Patch-Logic Review Findings

1. Entry bypasses (`nop_call3`/`nop_call4`) improve startup speed but correlate with weaker initialization fidelity (not matching original DAT behavior).
2. `19A0`-leaning branches can trigger invalid memory/ROM write behavior in DOSBox-X logs.
3. Caller bypass patches (`bypass_call_0ee8/2b82/2bb2`) tend to destabilize later control flow and increase INT6 risk.
4. The most progress-preserving patched lineage is still `midop_jmp_1992` / `midop_jmp_1c08`, but both stall at user #4.

---

## 6) Rethink Strategy (Reset Plan)

1. Freeze all profiles that include `bypass_call_*`.
2. Freeze all profiles that include direct `midop_jmp_19a0` due ROM-write evidence.
3. Keep only two active branches for next cycle:
   - Branch A (fidelity-first): demo force + minimal overlap control, no entry bypass, no safe-stubs.
   - Branch B (progress-first): V2D9292 lineage with one-at-a-time branch control toggles only.
4. Add explicit `.DAT` validation checkpoint after each run (non-zero count and sample file sizes) before deciding next patch.
5. Treat original baseline behavior as reference contract: "must write populated DATs before user#4+ stage".

---

## 7) Active Candidate Set (for clean restart)

| Priority | Variant | Why keep |
|---|---|---|
| 1 | V2D9292.EXE | Best proven progress (user #4) without ROM-write spam |
| 2 | V2D900.EXE | Also reaches user #4; alternate midop landing |
| 3 | Original baseline (STSorg.exe) | Behavioral reference for DAT population and later-stage flow |

All other current V2D/V2DD variants should be considered archived unless new evidence contradicts this matrix.
