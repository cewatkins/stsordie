# STS-12UC.EXE Project Documentation

## Documentation Index

| File | Purpose |
|------|---|
| [01-patches-and-execution-theory.md](01-patches-and-execution-theory.md) | Complete patch reference — all 71 PCH variants, 16 V2D profiles, runtime outcomes, patch theory, three-layer execution model |
| [02-tool-instructions.md](02-tool-instructions.md) | Tool-specific instructions — DOSBox-X config, IDA Free, Ghidra, DOS DEBUG, patch application, debugging workflow |
| [03-dosbox-x-debugger-walkthrough.md](03-dosbox-x-debugger-walkthrough.md) | DOSBox-X built-in debugger walkthrough — step-by-step tracing from start to patch points |
| [lastchat.md](lastchat.md) | Complete project state snapshot — everything needed to restart the project from scratch |

## Quick Start

1. Read `lastchat.md` for complete project state
2. Read `01-patches-and-execution-theory.md` for patch reference
3. Read `03-dosbox-x-debugger-walkthrough.md` for debugging procedures
4. Read `02-tool-instructions.md` for tool setup

## Current Status

**BLOCKED:** No patched variant reaches past user #4 with populated `.DAT` files.

**Active Candidates:**
1. V2D9292.EXE — user #4, INT6
2. V2D900.EXE — user #4, INT6
3. STSorg.exe — original baseline, writes populated DATs

**Next:** Two branches only — fidelity-first (A) and progress-first (B).
