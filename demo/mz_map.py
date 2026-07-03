#!/usr/bin/env python3
"""Map 16-bit MZ addresses to file offsets for patching/debugging.

Usage examples:
  ./mz_map.py STSorg.exe --preloc 4745:008A
  ./mz_map.py STSorg.exe --runtime 6A10:1F20 --load-seg 26F0
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path


def parse_segoff(text: str) -> tuple[int, int]:
    if ":" not in text:
        raise ValueError(f"Expected SEG:OFF, got: {text}")
    seg_s, off_s = text.split(":", 1)
    return int(seg_s, 16), int(off_s, 16)


def read_mz_header(path: Path) -> dict[str, int]:
    data = path.read_bytes()
    if len(data) < 0x20:
        raise ValueError("File too small for MZ header")
    if data[:2] != b"MZ":
        raise ValueError("Not an MZ executable")

    e_cparhdr = struct.unpack_from("<H", data, 0x08)[0]
    e_ip = struct.unpack_from("<H", data, 0x14)[0]
    e_cs = struct.unpack_from("<H", data, 0x16)[0]

    return {
        "header_bytes": e_cparhdr * 16,
        "entry_cs": e_cs,
        "entry_ip": e_ip,
        "file_size": len(data),
    }


def preloc_to_file(seg: int, off: int, header_bytes: int) -> int:
    return header_bytes + (seg << 4) + off


def runtime_to_file(cs: int, ip: int, load_seg: int, header_bytes: int) -> int:
    preloc_seg = (cs - load_seg) & 0xFFFF
    return preloc_to_file(preloc_seg, ip, header_bytes)


def main() -> int:
    parser = argparse.ArgumentParser(description="MZ segment:offset mapper")
    parser.add_argument("exe", help="Path to MZ executable")

    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preloc", help="Pre-relocation SEG:OFF (e.g. 4745:008A)")
    mode.add_argument(
        "--runtime",
        help="Runtime CS:IP (from debugger) with --load-seg",
    )

    parser.add_argument(
        "--load-seg",
        help="Program load segment in hex, required with --runtime",
    )

    args = parser.parse_args()

    path = Path(args.exe)
    hdr = read_mz_header(path)

    print(f"file        : {path}")
    print(f"size        : {hdr['file_size']} bytes")
    print(f"header      : {hdr['header_bytes']} bytes")
    print(f"entry preloc: {hdr['entry_cs']:04X}:{hdr['entry_ip']:04X}")

    if args.preloc:
        seg, off = parse_segoff(args.preloc)
        file_off = preloc_to_file(seg, off, hdr["header_bytes"])
        print(f"mode        : preloc")
        print(f"input       : {seg:04X}:{off:04X}")
        print(f"file offset : 0x{file_off:06X} ({file_off})")
        return 0

    if not args.load_seg:
        print("error: --runtime requires --load-seg", file=sys.stderr)
        return 2

    cs, ip = parse_segoff(args.runtime)
    load_seg = int(args.load_seg, 16)
    preloc_seg = (cs - load_seg) & 0xFFFF
    file_off = runtime_to_file(cs, ip, load_seg, hdr["header_bytes"])

    print("mode        : runtime")
    print(f"runtime CS:IP: {cs:04X}:{ip:04X}")
    print(f"load seg    : {load_seg:04X}")
    print(f"preloc      : {preloc_seg:04X}:{ip:04X}")
    print(f"file offset : 0x{file_off:06X} ({file_off})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
