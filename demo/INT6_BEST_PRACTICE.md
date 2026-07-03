# INT 6 Best-Practice Workflow (STS-12)

This is the shortest reliable loop for post-check freezes with repeated INT 6.

## 1) Freeze the baseline

- Keep one untouched executable as baseline:
  - `STSorg.exe`
- Build test candidates from baseline only.
- Do not stack unknown patches from previous runs.

## 2) Run with deterministic CPU settings

Use a 386+ model and a non-dynamic core while fault-hunting.

Recommended for DOSBox-X:

- `core=normal`
- `cputype=386_slow`
- `cycles=fixed 20000`

Reason: dynamic core can obscure exact fault location in logs.

## 3) Capture the FIRST fault site

You need one exact first-fault address, not repeated log spam.

Capture from debugger:

- `CS:IP` at the first INT 6
- Program load segment (`load_seg` / PSP+10h)

If debugger gives only one of these, capture the missing value too.

## 4) Map fault address to file offset

Use mapper script in this folder:

- Pre-reloc address mode:
  - `./mz_map.py STSorg.exe --preloc 4745:008A`
- Runtime mode:
  - `./mz_map.py STSorg.exe --runtime CS:IP --load-seg XXXX`

This gives exact file offset for byte-level patching.

## 5) Patch minimally

Patch only one proven instruction path per round.

Priority order:

1. Patch one branch or one call that reaches the fault.
2. Re-test.
3. Capture first-fault again.
4. Repeat.

Do not apply broad speculative NOP sweeps unless narrow patches fail repeatedly.

## 6) Keep patch log

For each patch record:

- file offset
- old bytes
- new bytes
- reason
- observed runtime effect

This prevents circular debugging and lets you bisect regressions.

## 7) Current candidates in this folder

- `STSorg.exe`: clean baseline
- `stsdemo.exe`: selector-only demo patch (`0099 -> 00C5`)
- `stsdemo_safe.exe`: selector + neutralized startup stub cluster

If `stsdemo_safe.exe` still faults, capture first `CS:IP` and map it with `mz_map.py`.
