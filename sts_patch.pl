#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use File::Copy;

# Default options
my $file     = 'STS12UC.EXE';
my $backup   = 1;
my $demo     = 0;
my $safe_stubs = 0;
my $demo_safe = 0;
my $bypass   = 0;
my $fail_cmp = 0;
my $infinite = 0;
my $help     = 0;

# Parse options
GetOptions(
    'file=s'     => \$file,       # Target executable
    'backup!'    => \$backup,     # Create a backup (.bak) by default
    'demo'       => \$demo,       # Correct patch: force AX to 00C5 so startup returns without ROM calls
    'safe-stubs' => \$safe_stubs, # Neutralize reboot/card dispatch stub cluster at 0x4ec5a..0x4ecb4
    'demo-safe'  => \$demo_safe,  # Convenience: apply both --demo and --safe-stubs
    'bypass'     => \$bypass,     # Method A: Force JMP past reboot cluster
    'fail-cmp'   => \$fail_cmp,   # Method B: Force comparison to fail (sets to 0000)
    'infinite'   => \$infinite,   # Entrypoint debug trick: Spin with EB FE
    'help|h'     => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print <<EOF;
STS12UC.EXE Multi-Option Patcher
Usage: perl patch_sts.pl [options]

Options:
  --file <path>    Path to the executable (default: STS12UC.EXE)
  --nobackup       Skip creating a backup file
    --demo           Change startup selector at 0x04eb99 from 0x0099 to 0x00c5
    --safe-stubs     Neutralize reboot/card stubs at 0x04ec5a..0x04ecb4
    --demo-safe      Apply both --demo and --safe-stubs
  --bypass         Force short JMP at 0x04eba1 to bypass reboot cluster entirely
  --fail-cmp       Change stack immediate value at 0x04eb99 from 0x99 to 0x00
  --infinite       Patch entry point (0x13d69) to infinite spin (EB FE) for debugging
  --help, -h       Show this help menu
EOF
    exit;
}

unless (-e $file) {
    die "Error: Target file '$file' not found.\n";
}

# Create backup if requested
if ($backup) {
    my $bak_file = $file . ".bak";
    unless (-e $bak_file) {
        copy($file, $bak_file) or die "Failed to create backup file: $!\n";
        print "[*] Backup created: $bak_file\n";
    }
}

# Open file for read/write binary operations
open(my $fh, '+<:raw', $file) or die "Cannot open '$file' for modifying: $!\n";

if ($demo_safe) {
    $demo = 1;
    $safe_stubs = 1;
}

if ($demo) {
    print "[+] Applying Demo Mode Patch...\n";
    # File offset: 0x04eb99
    # Original: 99 00 (MOV WORD PTR [BP-0Eh], 0099h)
    # Patch to: C5 00 (MOV WORD PTR [BP-0Eh], 00C5h)
    # This makes the startup routine take the AX == 00C5h return path at 0x04ec0c
    # instead of falling through into the ROM reboot cluster at 0x04ec5a.
    seek($fh, 0x04eb99, 0) or die "Seek failed: $!\n";
    print $fh pack('C2', 0xC5, 0x00);
    print "[✓] Demo selector changed to 0x00C5 at 0x04eb99.\n";
}

if ($safe_stubs) {
    print "[+] Applying Safe Stub Patch...\n";

    # 0x04ec5a..0x04ec68: hardcoded far calls into ROM/card vectors.
    # Replace each 5-byte CALL FAR with RETF + NOP padding.
    my @far_stub_offsets = (0x04ec5a, 0x04ec5f, 0x04ec64);
    for my $off (@far_stub_offsets) {
        seek($fh, $off, 0) or die "Seek failed: $!\n";
        print $fh pack('C5', 0xCB, 0x90, 0x90, 0x90, 0x90);
    }

    # 0x04ec78..0x04ecb1: 19 x "E8 00 00" near-call placeholders.
    # Replace each with RET + NOP NOP so accidental dispatch becomes no-op.
    for my $off (0x04ec78 .. 0x04ecb1) {
        next unless (($off - 0x04ec78) % 3) == 0;
        seek($fh, $off, 0) or die "Seek failed: $!\n";
        print $fh pack('C3', 0xC3, 0x90, 0x90);
    }

    print "[✓] Stub cluster neutralized at 0x04ec5a..0x04ecb4.\n";
}

if ($bypass) {
    print "[+] Applying Bypass Patch (Method A)...\n";
    # File offset: 0x04eba1
    # Original: 75 69 (JNZ -> 0x04ec0c)
    # Patch to: EB 69 (JMP SHORT -> 0x04ec0c)
    # NOTE: This is kept for experimentation only. It still leaves AX=0099h,
    # so execution continues into the ROM reboot cluster at 0x04ec5a.
    seek($fh, 0x04eba1, 0) or die "Seek failed: $!\n";
    print $fh pack('C', 0xEB); 
    print "[✓] Forced branch jump applied at 0x04eba1.\n";
}

if ($fail_cmp) {
    print "[+] Applying Comparison Failure Patch (Method B)...\n";
    # File offset: 0x04eb99
    # Original: 99 00 (MOV WORD PTR [BP-0Eh], 0099h)
    # Patch to: 00 00 (MOV WORD PTR [BP-0Eh], 0000h)
    # NOTE: This is kept for experimentation only. AX=0000h still fails the
    # 0x00C5 check at 0x04ec0c and falls into the ROM reboot cluster.
    seek($fh, 0x04eb99, 0) or die "Seek failed: $!\n";
    print $fh pack('C2', 0x00, 0x00);
    print "[✓] Immediate hardcoded stack value set to 0x0000 at 0x04eb99.\n";
}

if ($infinite) {
    print "[+] Applying Entry Point Infinite Spin Patch...\n";
    # File offset: 0x013d69 (seg000:C629)
    # Patch to: EB FE (JMP $)
    seek($fh, 0x013d69, 0) or die "Seek failed: $!\n";
    print $fh pack('C2', 0xEB, 0xFE);
    print "[✓] Debug spin loop applied at entry point 0x013d69.\n";
}

close($fh);
print "[*] Patching operations completed successfully.\n";