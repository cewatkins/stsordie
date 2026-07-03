#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

BASE = Path('STSorg.exe')
OUT = Path('.')


def w16(v: int) -> bytes:
    return bytes((v & 0xFF, (v >> 8) & 0xFF))


def apply_patch(buf: bytearray, offset: int, old: bytes, new: bytes, tag: str) -> None:
    cur = bytes(buf[offset:offset + len(old)])
    if cur != old:
        raise RuntimeError(f"{tag}: mismatch at {offset:#x}: expected {old.hex()} got {cur.hex()}")
    if len(old) != len(new):
        raise RuntimeError(f"{tag}: size mismatch at {offset:#x}")
    buf[offset:offset + len(new)] = new


def patch_selector_c5(buf: bytearray) -> None:
    # c7 46 f2 99 00 -> c7 46 f2 c5 00
    apply_patch(buf, 0x4EB96, bytes.fromhex('c746f29900'), bytes.fromhex('c746f2c500'), 'selector_c5')


def patch_safe_stubs(buf: bytearray) -> None:
    # Replace three far CALLs with RETF+NOP padding
    apply_patch(buf, 0x4EC5A, bytes.fromhex('9af0ff00f0'), bytes.fromhex('cb90909090'), 'romstub1')
    apply_patch(buf, 0x4EC5F, bytes.fromhex('9a000000c0'), bytes.fromhex('cb90909090'), 'romstub2')
    apply_patch(buf, 0x4EC64, bytes.fromhex('9a000000c8'), bytes.fromhex('cb90909090'), 'romstub3')

    # 19 placeholder near calls E8 00 00 -> C3 90 90
    off = 0x4EC78
    for i in range(19):
        apply_patch(buf, off + i * 3, bytes.fromhex('e80000'), bytes.fromhex('c39090'), f'stubtbl{i+1}')


def patch_nop_entry_call3(buf: bytearray) -> None:
    apply_patch(buf, 0x13D73, bytes.fromhex('9a8a004547'), bytes.fromhex('9090909090'), 'nop_call3')


def patch_nop_entry_call4(buf: bytearray) -> None:
    apply_patch(buf, 0x13D78, bytes.fromhex('9a0000e346'), bytes.fromhex('9090909090'), 'nop_call4')


def patch_skip_reboot_call(buf: bytearray) -> None:
    # In sub_4745:008A path: EB 07 at 0x4EC0A jumps to EC13 (call EC5A).
    # Change to EB 0A to jump directly to EC16 and return.
    apply_patch(buf, 0x4EC0A, bytes.fromhex('eb07'), bytes.fromhex('eb0a'), 'skip_ec5a_call')


def patch_force_c5_check_path(buf: bytearray) -> None:
    # cmp ax,0099 -> cmp ax,00c5 then jnz unchanged.
    apply_patch(buf, 0x4EB9E, bytes.fromhex('3d9900'), bytes.fromhex('3dc500'), 'cmp_c5')


def patch_jnz_to_jmp(buf: bytearray) -> None:
    apply_patch(buf, 0x4EBA1, bytes.fromhex('7569'), bytes.fromhex('eb69'), 'jnz_to_jmp')


def patch_csip_1978_retguard(buf: bytearray) -> None:
    # Captured CS:IP fault region:
    #   55 89 e5 81 ec 16 05 cc c2 b8 1c 02 f7 ...
    # Force an immediate return from this block to avoid the RET 1CB8 path.
    # Patch bytes 05 CC C2 B8 1C -> C3 90 90 90 90
    apply_patch(
        buf,
        0x44BC6,
        bytes.fromhex('05ccc2b81c'),
        bytes.fromhex('c390909090'),
        'csip_1978_retguard',
    )


def patch_csip_probe_cc(buf: bytearray) -> None:
    # Probe build: force INT3 at the same suspect site so runtime prints CS:IP.
    # c2 b8 1c -> cc 90 90
    apply_patch(
        buf,
        0x44BC8,
        bytes.fromhex('c2b81c'),
        bytes.fromhex('cc9090'),
        'csip_probe_cc',
    )


def patch_force_jz_taken(buf: bytearray) -> None:
    # 49B9:1998 branch control: 74 06 -> EB 06 (always jump to 19A0)
    apply_patch(buf, 0x44BE4, bytes.fromhex('7406'), bytes.fromhex('eb06'), 'force_jz_taken')


def patch_force_jz_not_taken(buf: bytearray) -> None:
    # 49B9:1998 branch control: 74 06 -> 90 90 (fall through to 199A)
    apply_patch(buf, 0x44BE4, bytes.fromhex('7406'), bytes.fromhex('9090'), 'force_jz_not_taken')


def patch_force_zf1_no_memread(buf: bytearray) -> None:
    # Replace cmp byte ptr es:[di+0140],00 with cmp al,al + NOPs.
    # This forces ZF=1 while avoiding the ES:DI memory read.
    apply_patch(
        buf,
        0x44BDE,
        bytes.fromhex('2680bd400100'),
        bytes.fromhex('38c090909090'),
        'force_zf1_no_memread',
    )


def patch_force_zf0_no_memread(buf: bytearray) -> None:
    # Replace cmp byte ptr es:[di+0140],00 with or al,01 + NOPs.
    # This forces ZF=0 while avoiding the ES:DI memory read.
    apply_patch(
        buf,
        0x44BDE,
        bytes.fromhex('2680bd400100'),
        bytes.fromhex('0c0190909090'),
        'force_zf0_no_memread',
    )


def patch_probe_path_a_cc(buf: bytearray) -> None:
    # Probe fall-through path block at 49B9:199A-ish: C6 46 FE 2A
    apply_patch(buf, 0x44BE6, bytes.fromhex('c646fe2a'), bytes.fromhex('cc909090'), 'probe_path_a_cc')


def patch_probe_path_b_cc(buf: bytearray) -> None:
    # Probe jump-target path block at 49B9:19A0-ish: C6 46 FE 23
    apply_patch(buf, 0x44BEC, bytes.fromhex('c646fe23'), bytes.fromhex('cc909090'), 'probe_path_b_cc')


def patch_midop_c2_to_c3(buf: bytearray) -> None:
    # Fault hot spot seen at 49B9:1978 when entered mid-stream.
    # C2 -> C3 keeps overlap impact minimal and avoids RET imm16 behavior.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2'), bytes.fromhex('c3'), 'midop_c2_to_c3')


def patch_midop_c2b81c_to_nop3(buf: bytearray) -> None:
    # Fully neutralize the mid-stream RET/imm sequence at 49B9:1978.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('909090'), 'midop_nop3')


def patch_midop_c2_to_cb(buf: bytearray) -> None:
    # Keep mid-entry behavior as a far return instead of near RET imm16.
    # This avoids the large SP adjustment and tends to preserve CS:IP sanity.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2'), bytes.fromhex('cb'), 'midop_c2_to_cb')


def patch_midop_c2b81c_to_cb9090(buf: bytearray) -> None:
    # Force the overlap sequence to RETF + padding for deterministic unwind.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('cb9090'), 'midop_cb9090')


def patch_midop_jmp_197f(buf: bytearray) -> None:
    # Redirect mid-entry at 49B9:1978 to 49B9:197F (MOV DI,AX) to re-enter
    # a coherent instruction stream instead of executing overlap bytes.
    # EB 05 from 197A lands at 197F.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('eb0590'), 'midop_jmp_197f')


def patch_midop_jmp_1985(buf: bytearray) -> None:
    # Redirect mid-entry at 49B9:1978 to 49B9:1985 (MOV [BP-16],DI).
    # EB 0B from 197A lands at 1985.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('eb0b90'), 'midop_jmp_1985')


def patch_midop_jmp_1992(buf: bytearray) -> None:
    # Jump from 1978 into the stable local block at 1992.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('eb1890'), 'midop_jmp_1992')


def patch_midop_jmp_1998(buf: bytearray) -> None:
    # Jump directly to cmp/jz decision point at 1998.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('eb1e90'), 'midop_jmp_1998')


def patch_midop_jmp_19a0(buf: bytearray) -> None:
    # Jump directly to the jz target body at 19A0.
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('eb2690'), 'midop_jmp_19a0')


def patch_midop_jmp_epilogue(buf: bytearray) -> None:
    # Convert overlap bytes at 1978 into near jump to 1C08 (mov sp,bp).
    # E9 8D 02 : from 197B -> 1C08
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('e98d02'), 'midop_jmp_1c08')


def patch_midop_jmp_retf(buf: bytearray) -> None:
    # Convert overlap bytes at 1978 into near jump to 1C0B (retf 0002).
    # E9 90 02 : from 197B -> 1C0B
    apply_patch(buf, 0x44BC8, bytes.fromhex('c2b81c'), bytes.fromhex('e99002'), 'midop_jmp_1c0b')


def patch_probe_1a05_cc(buf: bytearray) -> None:
    # Milestone probe near 1A05 in the account formatter path.
    apply_patch(buf, 0x44C55, bytes.fromhex('26'), bytes.fromhex('cc'), 'probe_1a05')


def patch_probe_1b5e_cc(buf: bytearray) -> None:
    # Milestone probe at 1B5E in the late formatting/output path.
    apply_patch(buf, 0x44DAE, bytes.fromhex('8b'), bytes.fromhex('cc'), 'probe_1b5e')


def patch_probe_1c03_cc(buf: bytearray) -> None:
    # Milestone probe at 1C03 just before a far call and epilogue.
    apply_patch(buf, 0x44E53, bytes.fromhex('9a'), bytes.fromhex('cc'), 'probe_1c03')


def patch_bypass_call_0ee8(buf: bytearray) -> None:
    # 0000:0EE8 call 1970 -> add sp,4 (consume pushed arg+cs like retf 2 path)
    apply_patch(buf, 0x44138, bytes.fromhex('e8850a'), bytes.fromhex('83c404'), 'bypass_call_0ee8')


def patch_bypass_call_2b82(buf: bytearray) -> None:
    # 0000:2B82 call 1970 -> add sp,4
    apply_patch(buf, 0x45DD2, bytes.fromhex('e8ebed'), bytes.fromhex('83c404'), 'bypass_call_2b82')


def patch_bypass_call_2bb2(buf: bytearray) -> None:
    # 0000:2BB2 call 1970 -> add sp,4
    apply_patch(buf, 0x45E02, bytes.fromhex('e8bbed'), bytes.fromhex('83c404'), 'bypass_call_2bb2')


VARIANTS = [
    ('PCH01.EXE', ['selector_c5']),
    ('PCH02.EXE', ['selector_c5', 'safe_stubs']),
    ('PCH03.EXE', ['selector_c5', 'nop_call3']),
    ('PCH04.EXE', ['selector_c5', 'safe_stubs', 'nop_call3']),
    ('PCH05.EXE', ['selector_c5', 'nop_call3', 'nop_call4']),
    ('PCH06.EXE', ['selector_c5', 'safe_stubs', 'nop_call3', 'nop_call4']),
    ('PCH07.EXE', ['skip_reboot_call']),
    ('PCH08.EXE', ['skip_reboot_call', 'safe_stubs']),
    ('PCH09.EXE', ['cmp_c5', 'skip_reboot_call']),
    ('PCH10.EXE', ['jnz_to_jmp', 'safe_stubs']),
    ('PCH11.EXE', ['selector_c5', 'skip_reboot_call']),
    ('PCH12.EXE', ['selector_c5', 'skip_reboot_call', 'safe_stubs']),
    ('PCH13.EXE', ['selector_c5', 'cmp_c5', 'skip_reboot_call']),
    ('PCH14.EXE', ['selector_c5', 'cmp_c5', 'skip_reboot_call', 'safe_stubs']),
    ('PCH15.EXE', ['nop_call3']),
    ('PCH16.EXE', ['nop_call3', 'safe_stubs']),
    ('PCH17.EXE', ['nop_call4']),
    ('PCH18.EXE', ['skip_reboot_call', 'nop_call3']),
    ('PCH19.EXE', ['skip_reboot_call', 'safe_stubs', 'nop_call3']),
    ('PCH20.EXE', ['selector_c5', 'jnz_to_jmp', 'safe_stubs']),
    ('PCH21.EXE', ['csip_1978_retguard']),
    ('PCH22.EXE', ['selector_c5', 'csip_1978_retguard']),
    ('PCH23.EXE', ['selector_c5', 'safe_stubs', 'csip_1978_retguard']),
    ('PCH24.EXE', ['skip_reboot_call', 'csip_1978_retguard']),
    ('PCH25.EXE', ['skip_reboot_call', 'safe_stubs', 'csip_1978_retguard']),
    ('PCH26.EXE', ['selector_c5', 'jnz_to_jmp', 'safe_stubs', 'csip_1978_retguard']),
    ('PCH27.EXE', ['selector_c5', 'safe_stubs', 'csip_probe_cc']),
    ('PCH28.EXE', ['skip_reboot_call', 'safe_stubs', 'csip_probe_cc']),
    ('PCH29.EXE', ['selector_c5', 'jnz_to_jmp', 'safe_stubs', 'csip_probe_cc']),
    ('PCH30.EXE', ['selector_c5', 'safe_stubs', 'force_jz_taken']),
    ('PCH31.EXE', ['selector_c5', 'safe_stubs', 'force_jz_not_taken']),
    ('PCH32.EXE', ['selector_c5', 'safe_stubs', 'force_zf1_no_memread']),
    ('PCH33.EXE', ['selector_c5', 'safe_stubs', 'force_zf0_no_memread']),
    ('PCH34.EXE', ['skip_reboot_call', 'safe_stubs', 'force_zf1_no_memread']),
    ('PCH35.EXE', ['skip_reboot_call', 'safe_stubs', 'force_zf0_no_memread']),
    ('PCH36.EXE', ['selector_c5', 'safe_stubs', 'probe_path_a_cc']),
    ('PCH37.EXE', ['selector_c5', 'safe_stubs', 'probe_path_b_cc']),
    ('PCH38.EXE', ['skip_reboot_call', 'safe_stubs', 'probe_path_a_cc']),
    ('PCH39.EXE', ['skip_reboot_call', 'safe_stubs', 'probe_path_b_cc']),
    ('PCH40.EXE', ['selector_c5', 'safe_stubs', 'midop_c2_to_c3']),
    ('PCH41.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_c2_to_c3']),
    ('PCH42.EXE', ['selector_c5', 'safe_stubs', 'midop_nop3']),
    ('PCH43.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_nop3']),
    ('PCH44.EXE', ['selector_c5', 'safe_stubs', 'midop_c2_to_cb']),
    ('PCH45.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_c2_to_cb']),
    ('PCH46.EXE', ['selector_c5', 'safe_stubs', 'midop_cb9090']),
    ('PCH47.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_cb9090']),
    ('PCH48.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_197f']),
    ('PCH49.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_197f']),
    ('PCH50.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1985']),
    ('PCH51.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_1985']),
    ('PCH52.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1992']),
    ('PCH53.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_1992']),
    ('PCH54.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1998']),
    ('PCH55.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_1998']),
    ('PCH56.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_19a0']),
    ('PCH57.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_19a0']),
    ('PCH58.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1c08']),
    ('PCH59.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_1c08']),
    ('PCH60.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1c0b']),
    ('PCH61.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_1c0b']),
    ('PCH62.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1c08', 'probe_1a05']),
    ('PCH63.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1c08', 'probe_1b5e']),
    ('PCH64.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1c08', 'probe_1c03']),
    ('PCH65.EXE', ['skip_reboot_call', 'safe_stubs', 'midop_jmp_1c08', 'probe_1c03']),
    ('PCH66.EXE', ['selector_c5', 'safe_stubs', 'bypass_call_2b82']),
    ('PCH67.EXE', ['selector_c5', 'safe_stubs', 'bypass_call_2bb2']),
    ('PCH68.EXE', ['selector_c5', 'safe_stubs', 'bypass_call_2b82', 'bypass_call_2bb2']),
    ('PCH69.EXE', ['selector_c5', 'safe_stubs', 'midop_jmp_1c08', 'bypass_call_2b82', 'bypass_call_2bb2']),
    ('PCH70.EXE', ['selector_c5', 'safe_stubs', 'bypass_call_0ee8', 'bypass_call_2b82', 'bypass_call_2bb2']),
    ('PCH71.EXE', ['skip_reboot_call', 'safe_stubs', 'bypass_call_0ee8', 'bypass_call_2b82', 'bypass_call_2bb2']),
]

ACTIONS = {
    'selector_c5': patch_selector_c5,
    'safe_stubs': patch_safe_stubs,
    'nop_call3': patch_nop_entry_call3,
    'nop_call4': patch_nop_entry_call4,
    'skip_reboot_call': patch_skip_reboot_call,
    'cmp_c5': patch_force_c5_check_path,
    'jnz_to_jmp': patch_jnz_to_jmp,
    'csip_1978_retguard': patch_csip_1978_retguard,
    'csip_probe_cc': patch_csip_probe_cc,
    'force_jz_taken': patch_force_jz_taken,
    'force_jz_not_taken': patch_force_jz_not_taken,
    'force_zf1_no_memread': patch_force_zf1_no_memread,
    'force_zf0_no_memread': patch_force_zf0_no_memread,
    'probe_path_a_cc': patch_probe_path_a_cc,
    'probe_path_b_cc': patch_probe_path_b_cc,
    'midop_c2_to_c3': patch_midop_c2_to_c3,
    'midop_nop3': patch_midop_c2b81c_to_nop3,
    'midop_c2_to_cb': patch_midop_c2_to_cb,
    'midop_cb9090': patch_midop_c2b81c_to_cb9090,
    'midop_jmp_197f': patch_midop_jmp_197f,
    'midop_jmp_1985': patch_midop_jmp_1985,
    'midop_jmp_1992': patch_midop_jmp_1992,
    'midop_jmp_1998': patch_midop_jmp_1998,
    'midop_jmp_19a0': patch_midop_jmp_19a0,
    'midop_jmp_1c08': patch_midop_jmp_epilogue,
    'midop_jmp_1c0b': patch_midop_jmp_retf,
    'probe_1a05': patch_probe_1a05_cc,
    'probe_1b5e': patch_probe_1b5e_cc,
    'probe_1c03': patch_probe_1c03_cc,
    'bypass_call_0ee8': patch_bypass_call_0ee8,
    'bypass_call_2b82': patch_bypass_call_2b82,
    'bypass_call_2bb2': patch_bypass_call_2bb2,
}


def digest(path: Path) -> str:
    return hashlib.sha1(path.read_bytes()).hexdigest()


def main() -> int:
    if not BASE.exists():
        raise SystemExit(f"Missing baseline: {BASE}")

    base_bytes = BASE.read_bytes()
    manifest_lines = []

    for name, ops in VARIANTS:
        buf = bytearray(base_bytes)
        for op in ops:
            ACTIONS[op](buf)
        out = OUT / name
        out.write_bytes(buf)
        manifest_lines.append(f"{name}: {', '.join(ops)}")

    man = OUT / 'PATCHES.TXT'
    man.write_text('\n'.join(manifest_lines) + '\n', encoding='ascii')

    # include hashes for reproducibility
    h = OUT / 'PATCHES.SHA1'
    lines = [f"{digest(OUT / name)}  {name}" for name, _ in VARIANTS]
    h.write_text('\n'.join(lines) + '\n', encoding='ascii')

    print('Generated variants:')
    for name, _ in VARIANTS:
        print(' ', name)
    print('Wrote PATCHES.TXT and PATCHES.SHA1')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
