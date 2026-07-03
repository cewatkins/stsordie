# ACS Run Log

Active candidate set. Append one row per run.
All EXE filenames: 8-char basename, .EXE extension only.

## Baseline Contract

| Artifact | SHA1 | Notes |
|---|---|---|
| STSORG.EXE | 120f8d982a31de4bdd5292b65264491af0a2c11a | Original, patched with selector_c5 only |
| V2D900.EXE | ae4a2ebda69207ef4840c3bda884e328fc3f67bf | selector_c5 + nop_call3 + nop_call4 + midop_jmp_1c08 |
| V2D9292.EXE | 958cdf84d09ac5103d11a30fd85dc984da69f961 | selector_c5 + nop_call3 + nop_call4 + midop_jmp_1992 |

## DAT Reference (from original unpatched baseline)

Populate this section from one clean STSORG.EXE run before any patched run.
Record file names and sizes after run completes (or stops):

| DAT File | Expected Size | Notes |
|---|---|---|
| P1000.DAT | ? | (fill in from STSORG run) |
| P1100.DAT | ? | |
| P1200.DAT | ? | |
| P1300.DAT | ? | |
| P1500.DAT | ? | |

## Run Results

| Date | Variant | Farthest User | DAT Status | Outcome | First Fault CS:IP | Notes |
|---|---|---|---|---|---|---|
| 2026-07-02 | V2D900.EXE | user #4 | empty/zero | INT6 | - | established baseline progress |
| 2026-07-02 | V2D9292.EXE | user #4 | empty/zero | INT6 | - | same progress, different midop landing |
| 2026-07-02 | V2DD992.EXE | user #0 | - | stops | - | entry preservation regressed |
| 2026-07-02 | V2DD99N.EXE | user #0 | - | stops | - | regressed |
| 2026-07-02 | V2DD99Z.EXE | user #0 | - | stops | - | regressed |
| 2026-07-02 | V2DD9A0.EXE | user #0 | - | stops | - | regressed |

## How to Add a Run Entry

```
./ADDRUN.SH  FILENAME.EXE  "user N"  "empty|populated"  "INT6|reboot|freeze|pass"  "CS:IP or -"  "notes"
```

Or append a row manually in the table above.

## Retire / Archive Rules

1. Any profile that regresses to user #0 → archived, do not re-test.
2. Any profile that generates ROM-write spam (lin=fda..) → archived immediately.
3. A profile passes to the next stage only if: farthest user > 4 AND DAT files populated.
