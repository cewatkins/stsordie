#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import mkpatch as p

BASE = Path("STSorg.exe")
OUT = Path(".")

V2A_VARIANTS = [
    (f"V2A{i:02d}.EXE", ops, old_name)
    for i, (old_name, ops) in enumerate(p.VARIANTS, start=1)
]

PROFILES: dict[str, dict[str, object]] = {
    "demo-min": {
        "out": "V2DMIN.EXE",
        "ops": ["selector_c5"],
        "desc": "Force demo mode only; keep startup logic intact.",
    },
    "demo-noenv": {
        "out": "V2DNOEV.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4"],
        "desc": "Demo mode plus no-env entry bypass for COM3/COM4 style checks.",
    },
    "demo-noenv-skipreboot": {
        "out": "V2DNONR.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "skip_reboot_call"],
        "desc": "demo-noenv plus reboot-skip at startup branch.",
    },
    "demo-safe": {
        "out": "V2DSAFE.EXE",
        "ops": ["selector_c5", "safe_stubs"],
        "desc": "Demo mode with startup ROM/stub neutralization.",
    },
    "demo-900-target": {
        "out": "V2D900.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "midop_jmp_1c08"],
        "desc": "Target run beyond user#0 toward 900-check path without caller bypass stack edits.",
    },
    "demo-900-basejmp": {
        "out": "V2D90BJ.EXE",
        "ops": ["selector_c5", "midop_jmp_1c08"],
        "desc": "V2D900 without entry nops; preserves more original init while keeping 1C08 jump.",
    },
    "demo-900-j1992": {
        "out": "V2D9292.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "midop_jmp_1992"],
        "desc": "V2D900-style profile with midop jump to 1992 instead of epilogue jump.",
    },
    "demo-900-j19a0": {
        "out": "V2D92A0.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "midop_jmp_19a0"],
        "desc": "V2D900-style profile with midop jump directly to 19A0 path body.",
    },
    "demo-900-cb": {
        "out": "V2D90CB.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "midop_c2_to_cb"],
        "desc": "V2D900-style profile forcing RETF semantics at overlap byte C2.",
    },
    "demo-9292-jzsafe": {
        "out": "V2D92NS.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "midop_jmp_1992", "force_jz_not_taken"],
        "desc": "V2D9292 plus forced non-jump at 1998 to avoid 19A0 body path.",
    },
    "demo-9292-jztaken": {
        "out": "V2D92JT.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "midop_jmp_1992", "force_jz_taken"],
        "desc": "V2D9292 plus forced jump at 1998 for A/B confirmation of branch safety.",
    },
    "demo-9292-zf1": {
        "out": "V2D92ZF.EXE",
        "ops": ["selector_c5", "nop_call3", "nop_call4", "midop_jmp_1992", "force_zf1_no_memread"],
        "desc": "V2D9292 with ES:DI compare replaced by cmp al,al to avoid memory read side effects.",
    },
    "demo-dat-j1992": {
        "out": "V2DD992.EXE",
        "ops": ["selector_c5", "midop_jmp_1992"],
        "desc": "DAT-preserving profile: original init path retained, with 1978 landing redirected to 1992.",
    },
    "demo-dat-j1992-ns": {
        "out": "V2DD99N.EXE",
        "ops": ["selector_c5", "midop_jmp_1992", "force_jz_not_taken"],
        "desc": "DAT-preserving j1992 plus forced non-jump at 1998 to avoid 19A0 branch.",
    },
    "demo-dat-j1992-zf1": {
        "out": "V2DD99Z.EXE",
        "ops": ["selector_c5", "midop_jmp_1992", "force_zf1_no_memread"],
        "desc": "DAT-preserving j1992 plus no-memread cmp replacement around 1998 decision.",
    },
    "demo-dat-j19a0": {
        "out": "V2DD9A0.EXE",
        "ops": ["selector_c5", "midop_jmp_19a0"],
        "desc": "DAT-preserving profile that directly enters 19A0 path from overlap site.",
    },
}


def _digest(path: Path) -> str:
    return p.digest(path)


def _parse_ranges(expr: str, max_index: int) -> list[int]:
    picked: set[int] = set()
    parts = [x.strip() for x in expr.split(",") if x.strip()]
    for part in parts:
        if "-" in part:
            a, b = part.split("-", 1)
            lo = int(a)
            hi = int(b)
            if lo > hi:
                lo, hi = hi, lo
            if lo < 1 or hi > max_index:
                raise ValueError(f"Range {part} is outside 1..{max_index}")
            for n in range(lo, hi + 1):
                picked.add(n)
        else:
            n = int(part)
            if n < 1 or n > max_index:
                raise ValueError(f"Index {n} is outside 1..{max_index}")
            picked.add(n)
    return sorted(picked)


def _build(selected_indexes: list[int], write_manifest: bool = True) -> None:
    if not BASE.exists():
        raise SystemExit(f"Missing baseline: {BASE}")

    base_bytes = BASE.read_bytes()
    selected = [V2A_VARIANTS[i - 1] for i in selected_indexes]

    manifest_lines: list[str] = []
    hash_lines: list[str] = []

    for v2a_name, ops, old_name in selected:
        buf = bytearray(base_bytes)
        for op in ops:
            p.ACTIONS[op](buf)
        out = OUT / v2a_name
        out.write_bytes(buf)
        manifest_lines.append(f"{v2a_name} (from {old_name}): {', '.join(ops)}")
        hash_lines.append(f"{_digest(out)}  {v2a_name}")

    if write_manifest:
        (OUT / "V2A_PATCHES.TXT").write_text("\n".join(manifest_lines) + "\n", encoding="ascii")
        (OUT / "V2A_PATCHES.SHA1").write_text("\n".join(hash_lines) + "\n", encoding="ascii")

    print("Generated V2A variants:")
    for v2a_name, _, old_name in selected:
        print(f"  {v2a_name}  (from {old_name})")
    if write_manifest:
        print("Wrote V2A_PATCHES.TXT and V2A_PATCHES.SHA1")


def _build_profile(profile_name: str, write_manifest: bool = True) -> None:
    if profile_name not in PROFILES:
        raise SystemExit(f"Unknown profile: {profile_name}")
    if not BASE.exists():
        raise SystemExit(f"Missing baseline: {BASE}")

    prof = PROFILES[profile_name]
    out_name = str(prof["out"])
    ops = list(prof["ops"])

    buf = bytearray(BASE.read_bytes())
    for op in ops:
        p.ACTIONS[op](buf)

    out = OUT / out_name
    out.write_bytes(buf)
    print(f"Generated profile {profile_name}: {out_name}")
    print(f"Actions: {', '.join(ops)}")

    if write_manifest:
        line = f"{profile_name}: {out_name}: {', '.join(ops)}"
        hash_line = f"{_digest(out)}  {out_name}"
        (OUT / "V2A_PROFILES.TXT").write_text(line + "\n", encoding="ascii")
        (OUT / "V2A_PROFILES.SHA1").write_text(hash_line + "\n", encoding="ascii")
        print("Wrote V2A_PROFILES.TXT and V2A_PROFILES.SHA1")


def _build_all_profiles() -> None:
    if not BASE.exists():
        raise SystemExit(f"Missing baseline: {BASE}")

    base_bytes = BASE.read_bytes()
    lines: list[str] = []
    hashes: list[str] = []

    for name in sorted(PROFILES.keys()):
        prof = PROFILES[name]
        out_name = str(prof["out"])
        ops = list(prof["ops"])
        buf = bytearray(base_bytes)
        for op in ops:
            p.ACTIONS[op](buf)
        out = OUT / out_name
        out.write_bytes(buf)
        lines.append(f"{name}: {out_name}: {', '.join(ops)}")
        hashes.append(f"{_digest(out)}  {out_name}")
        print(f"Generated profile {name}: {out_name}")

    (OUT / "V2A_PROFILES.TXT").write_text("\n".join(lines) + "\n", encoding="ascii")
    (OUT / "V2A_PROFILES.SHA1").write_text("\n".join(hashes) + "\n", encoding="ascii")
    print("Wrote V2A_PROFILES.TXT and V2A_PROFILES.SHA1")


def _print_profiles() -> None:
    print("Available V2A profiles:")
    for name in sorted(PROFILES.keys()):
        prof = PROFILES[name]
        out_name = str(prof["out"])
        ops = list(prof["ops"])
        desc = str(prof["desc"])
        print(f"- {name}: {out_name}")
        print(f"  {desc}")
        print(f"  ops: {', '.join(ops)}")


def _print_presets() -> None:
    print("Available preset combinations (mapped from PCHxx):")
    for i, (v2a_name, ops, old_name) in enumerate(V2A_VARIANTS, start=1):
        print(f"{i:02d}. {v2a_name} <- {old_name}: {', '.join(ops)}")


def _interactive() -> None:
    max_index = len(V2A_VARIANTS)
    while True:
        print()
        print("V2A patch builder")
        print("1) Build all presets (V2A01..V2A71)")
        print("2) Build selected presets by number/range")
        print("3) Build one custom variant from patch actions")
        print("4) List presets")
        print("5) List profiles")
        print("6) Build one profile")
        print("7) Build all profiles")
        print("8) Quit")
        choice = input("Choose [1-8]: ").strip()

        if choice == "1":
            _build(list(range(1, max_index + 1)))
        elif choice == "2":
            spec = input("Enter preset indexes/ranges (example: 68-71,58): ").strip()
            try:
                picks = _parse_ranges(spec, max_index)
            except ValueError as e:
                print(f"Error: {e}")
                continue
            _build(picks)
        elif choice == "3":
            action_names = sorted(p.ACTIONS.keys())
            print("Available actions:")
            for i, name in enumerate(action_names, start=1):
                print(f"{i:02d}. {name}")
            spec = input("Enter action indexes/ranges (example: 1,4,8-10): ").strip()
            try:
                picks = _parse_ranges(spec, len(action_names))
            except ValueError as e:
                print(f"Error: {e}")
                continue

            chosen = [action_names[i - 1] for i in picks]
            base = BASE.read_bytes()
            buf = bytearray(base)
            for action in chosen:
                p.ACTIONS[action](buf)

            out_name = input("Output file name [V2ACUS1.EXE]: ").strip().upper() or "V2ACUS1.EXE"
            out = OUT / out_name
            out.write_bytes(buf)
            print(f"Wrote {out_name} with actions: {', '.join(chosen)}")
        elif choice == "4":
            _print_presets()
        elif choice == "5":
            _print_profiles()
        elif choice == "6":
            _print_profiles()
            name = input("Enter profile name: ").strip()
            try:
                _build_profile(name)
            except SystemExit as e:
                print(e)
        elif choice == "7":
            _build_all_profiles()
        elif choice == "8":
            return
        else:
            print("Invalid choice.")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build V2A patch variants from STSorg.exe using existing patch combinations."
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Build all preset variants (V2A01..V2A71)",
    )
    parser.add_argument(
        "--variants",
        metavar="LIST",
        help="Preset indexes/ranges to build, e.g. 68-71,58",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List all preset combinations",
    )
    parser.add_argument(
        "--profile-list",
        action="store_true",
        help="List named V2A profiles",
    )
    parser.add_argument(
        "--profile",
        metavar="NAME",
        help="Build one named profile, e.g. demo-900-target",
    )
    parser.add_argument(
        "--profiles-all",
        action="store_true",
        help="Build all named V2A profiles",
    )

    args = parser.parse_args()
    max_index = len(V2A_VARIANTS)

    if args.list:
        _print_presets()
        return 0

    if args.profile_list:
        _print_profiles()
        return 0

    if args.all:
        _build(list(range(1, max_index + 1)))
        return 0

    if args.variants:
        picks = _parse_ranges(args.variants, max_index)
        _build(picks)
        return 0

    if args.profile:
        _build_profile(args.profile)
        return 0

    if args.profiles_all:
        _build_all_profiles()
        return 0

    _interactive()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
