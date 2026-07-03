# PCH Test Differences And Patch Matrix

## Runtime Outcome Summary (known so far)

| Variant | Outcome | Notes |
|---|---|---|
| PCH52 | account0-stop | Previously observed, no immediate INT6 |
| PCH53 | account0-stop | Previously observed, no immediate INT6 |
| PCH54 | INT6 | Previously observed |
| PCH55 | INT6 | Previously observed |
| PCH56 | account0-stop | Previously observed, no immediate INT6 |
| PCH57 | account0-stop | Previously observed, no immediate INT6 |
| PCH58 | account0-stop | Best prior midop-only behavior |
| PCH60 | INT6 | Previously observed |
| PCH68 | INT6 | Latest user report |
| PCH69 | account0-stop | Latest user report |
| PCH70 | INT6 | Latest user report |
| PCH71 | INT6 | Latest user report |

## Full Patch Matrix (PCH -> patch set)

| Variant | Patch Set |
|---|---|
| PCH01.EXE | selector_c5 |
| PCH02.EXE | selector_c5, safe_stubs |
| PCH03.EXE | selector_c5, nop_call3 |
| PCH04.EXE | selector_c5, safe_stubs, nop_call3 |
| PCH05.EXE | selector_c5, nop_call3, nop_call4 |
| PCH06.EXE | selector_c5, safe_stubs, nop_call3, nop_call4 |
| PCH07.EXE | skip_reboot_call |
| PCH08.EXE | skip_reboot_call, safe_stubs |
| PCH09.EXE | cmp_c5, skip_reboot_call |
| PCH10.EXE | jnz_to_jmp, safe_stubs |
| PCH11.EXE | selector_c5, skip_reboot_call |
| PCH12.EXE | selector_c5, skip_reboot_call, safe_stubs |
| PCH13.EXE | selector_c5, cmp_c5, skip_reboot_call |
| PCH14.EXE | selector_c5, cmp_c5, skip_reboot_call, safe_stubs |
| PCH15.EXE | nop_call3 |
| PCH16.EXE | nop_call3, safe_stubs |
| PCH17.EXE | nop_call4 |
| PCH18.EXE | skip_reboot_call, nop_call3 |
| PCH19.EXE | skip_reboot_call, safe_stubs, nop_call3 |
| PCH20.EXE | selector_c5, jnz_to_jmp, safe_stubs |
| PCH21.EXE | csip_1978_retguard |
| PCH22.EXE | selector_c5, csip_1978_retguard |
| PCH23.EXE | selector_c5, safe_stubs, csip_1978_retguard |
| PCH24.EXE | skip_reboot_call, csip_1978_retguard |
| PCH25.EXE | skip_reboot_call, safe_stubs, csip_1978_retguard |
| PCH26.EXE | selector_c5, jnz_to_jmp, safe_stubs, csip_1978_retguard |
| PCH27.EXE | selector_c5, safe_stubs, csip_probe_cc |
| PCH28.EXE | skip_reboot_call, safe_stubs, csip_probe_cc |
| PCH29.EXE | selector_c5, jnz_to_jmp, safe_stubs, csip_probe_cc |
| PCH30.EXE | selector_c5, safe_stubs, force_jz_taken |
| PCH31.EXE | selector_c5, safe_stubs, force_jz_not_taken |
| PCH32.EXE | selector_c5, safe_stubs, force_zf1_no_memread |
| PCH33.EXE | selector_c5, safe_stubs, force_zf0_no_memread |
| PCH34.EXE | skip_reboot_call, safe_stubs, force_zf1_no_memread |
| PCH35.EXE | skip_reboot_call, safe_stubs, force_zf0_no_memread |
| PCH36.EXE | selector_c5, safe_stubs, probe_path_a_cc |
| PCH37.EXE | selector_c5, safe_stubs, probe_path_b_cc |
| PCH38.EXE | skip_reboot_call, safe_stubs, probe_path_a_cc |
| PCH39.EXE | skip_reboot_call, safe_stubs, probe_path_b_cc |
| PCH40.EXE | selector_c5, safe_stubs, midop_c2_to_c3 |
| PCH41.EXE | skip_reboot_call, safe_stubs, midop_c2_to_c3 |
| PCH42.EXE | selector_c5, safe_stubs, midop_nop3 |
| PCH43.EXE | skip_reboot_call, safe_stubs, midop_nop3 |
| PCH44.EXE | selector_c5, safe_stubs, midop_c2_to_cb |
| PCH45.EXE | skip_reboot_call, safe_stubs, midop_c2_to_cb |
| PCH46.EXE | selector_c5, safe_stubs, midop_cb9090 |
| PCH47.EXE | skip_reboot_call, safe_stubs, midop_cb9090 |
| PCH48.EXE | selector_c5, safe_stubs, midop_jmp_197f |
| PCH49.EXE | skip_reboot_call, safe_stubs, midop_jmp_197f |
| PCH50.EXE | selector_c5, safe_stubs, midop_jmp_1985 |
| PCH51.EXE | skip_reboot_call, safe_stubs, midop_jmp_1985 |
| PCH52.EXE | selector_c5, safe_stubs, midop_jmp_1992 |
| PCH53.EXE | skip_reboot_call, safe_stubs, midop_jmp_1992 |
| PCH54.EXE | selector_c5, safe_stubs, midop_jmp_1998 |
| PCH55.EXE | skip_reboot_call, safe_stubs, midop_jmp_1998 |
| PCH56.EXE | selector_c5, safe_stubs, midop_jmp_19a0 |
| PCH57.EXE | skip_reboot_call, safe_stubs, midop_jmp_19a0 |
| PCH58.EXE | selector_c5, safe_stubs, midop_jmp_1c08 |
| PCH59.EXE | skip_reboot_call, safe_stubs, midop_jmp_1c08 |
| PCH60.EXE | selector_c5, safe_stubs, midop_jmp_1c0b |
| PCH61.EXE | skip_reboot_call, safe_stubs, midop_jmp_1c0b |
| PCH62.EXE | selector_c5, safe_stubs, midop_jmp_1c08, probe_1a05 |
| PCH63.EXE | selector_c5, safe_stubs, midop_jmp_1c08, probe_1b5e |
| PCH64.EXE | selector_c5, safe_stubs, midop_jmp_1c08, probe_1c03 |
| PCH65.EXE | skip_reboot_call, safe_stubs, midop_jmp_1c08, probe_1c03 |
| PCH66.EXE | selector_c5, safe_stubs, bypass_call_2b82 |
| PCH67.EXE | selector_c5, safe_stubs, bypass_call_2bb2 |
| PCH68.EXE | selector_c5, safe_stubs, bypass_call_2b82, bypass_call_2bb2 |
| PCH69.EXE | selector_c5, safe_stubs, midop_jmp_1c08, bypass_call_2b82, bypass_call_2bb2 |
| PCH70.EXE | selector_c5, safe_stubs, bypass_call_0ee8, bypass_call_2b82, bypass_call_2bb2 |
| PCH71.EXE | skip_reboot_call, safe_stubs, bypass_call_0ee8, bypass_call_2b82, bypass_call_2bb2 |
