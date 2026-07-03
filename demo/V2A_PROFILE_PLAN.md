# V2A Demo Run Profiles

Goal: run in demo mode without relying on environment variables, and push execution to the 900-check stage (where prior baseline behavior froze/rebooted after showing the 1! state).

## Why prior attempts stalled at user#0

The user#0 stall and early INT6 behavior correlates with intrusive control-flow edits (midop and caller-bypass family in late PCH variants). These are useful for fault isolation but can stop normal progression before the 900-check region.

Observed update: `V2D900.EXE` reaches user #4 without environment variables, then INT6.

Observed update: `V2D92A0.EXE` triggers DOSBox-X ROM write errors (writes to F000 region), indicating unsafe branch/path state.

Observed update: only original binary currently writes populated `.DAT` files; patched profiles must preserve original init paths to keep data writes.

## Profile strategy

Use smaller, login-faithful demo forcing first, then escalate only if needed.

1. demo-min
- Output: V2DMIN.EXE
- Actions: selector_c5
- Intent: force demo mode only; keep runtime logic closest to original.

2. demo-noenv
- Output: V2DNOEV.EXE
- Actions: selector_c5, nop_call3, nop_call4
- Intent: avoid dependence on COM3/COM4-style env gating while keeping startup mostly intact.

3. demo-noenv-skipreboot
- Output: V2DNONR.EXE
- Actions: selector_c5, nop_call3, nop_call4, skip_reboot_call
- Intent: same as demo-noenv but avoids one reboot branch in startup flow.

4. demo-900-target
- Output: V2D900.EXE
- Actions: selector_c5, nop_call3, nop_call4, midop_jmp_1c08
- Intent: attempt to get beyond user#0 while avoiding heavy caller bypass stack edits.

5. demo-safe
- Output: V2DSAFE.EXE
- Actions: selector_c5, safe_stubs
- Intent: fallback when startup ROM/stub paths are unstable.

6. demo-900-basejmp
- Output: V2D90BJ.EXE
- Actions: selector_c5, midop_jmp_1c08
- Intent: keep 1C08 jump but preserve entry calls to retain more original `.DAT` initialization.

7. demo-900-j1992
- Output: V2D9292.EXE
- Actions: selector_c5, nop_call3, nop_call4, midop_jmp_1992
- Intent: V2D900 lineage with less abrupt midop landing.

8. demo-900-j19a0
- Output: V2D92A0.EXE
- Actions: selector_c5, nop_call3, nop_call4, midop_jmp_19a0
- Intent: V2D900 lineage using target body entry at 19A0.

9. demo-900-cb
- Output: V2D90CB.EXE
- Actions: selector_c5, nop_call3, nop_call4, midop_c2_to_cb
- Intent: V2D900 lineage with RETF semantics instead of jump at overlap byte.

10. demo-9292-jzsafe
- Output: V2D92NS.EXE
- Actions: selector_c5, nop_call3, nop_call4, midop_jmp_1992, force_jz_not_taken
- Intent: keep V2D9292 path but force away from 19A0 body branch.

11. demo-9292-jztaken
- Output: V2D92JT.EXE
- Actions: selector_c5, nop_call3, nop_call4, midop_jmp_1992, force_jz_taken
- Intent: A/B compare against jzsafe.

12. demo-9292-zf1
- Output: V2D92ZF.EXE
- Actions: selector_c5, nop_call3, nop_call4, midop_jmp_1992, force_zf1_no_memread
- Intent: remove ES:DI compare memory read side effects in this branch window.

13. demo-dat-j1992
- Output: V2DD992.EXE
- Actions: selector_c5, midop_jmp_1992
- Intent: preserve init/data-write path while addressing overlap entry point.

14. demo-dat-j1992-ns
- Output: V2DD99N.EXE
- Actions: selector_c5, midop_jmp_1992, force_jz_not_taken
- Intent: DAT-preserving path that avoids 19A0 branch.

15. demo-dat-j1992-zf1
- Output: V2DD99Z.EXE
- Actions: selector_c5, midop_jmp_1992, force_zf1_no_memread
- Intent: DAT-preserving path with no ES:DI memread side effect at decision point.

16. demo-dat-j19a0
- Output: V2DD9A0.EXE
- Actions: selector_c5, midop_jmp_19a0
- Intent: DAT-preserving direct 19A0 entry (keep as low-priority control due prior ROM-write behavior on similar path).

## Run order for now

1. V2DD992.EXE
2. V2DD99N.EXE
3. V2DD99Z.EXE
4. V2DD9A0.EXE

## Result capture format

Record one line per run:
- variant
- outcome (PASS, account0-stop, 900-message, INT6, reboot, freeze)
- if stopped in debugger: CS:IP
- screen marker: whether 1! appears

## Generated profile manifests

- V2A_PROFILES.TXT
- V2A_PROFILES.SHA1
