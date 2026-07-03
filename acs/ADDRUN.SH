#!/usr/bin/env bash
# ADDRUN.SH - append a run result row to RUNLOG.MD
# Usage: ./ADDRUN.SH VARIANT.EXE "user N" "empty|populated" "INT6|reboot|freeze|pass" "CS:IP|-" "notes"
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$DIR/RUNLOG.MD"

VARIANT="${1:-}"
USERNUM="${2:-}"
DATSTAT="${3:-}"
OUTCOME="${4:-}"
CSIP="${5:--}"
NOTES="${6:-}"

if [[ -z "$VARIANT" ]]; then
    echo "Usage: $0 VARIANT.EXE 'user N' 'empty|populated' 'INT6|reboot|freeze|pass' 'CS:IP|-' 'notes'"
    exit 1
fi

DATE=$(date +%Y-%m-%d)
ROW="| $DATE | $VARIANT | $USERNUM | $DATSTAT | $OUTCOME | $CSIP | $NOTES |"

# Append before the retire/archive rules section
sed -i "/^## Retire \/ Archive Rules/i $ROW" "$LOG"
echo "Appended: $ROW"
