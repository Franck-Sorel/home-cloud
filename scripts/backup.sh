#!/usr/bin/env bash
# backup.sh — trigger a Velero backup schedule and verify completion.
#
# Usage:   ./scripts/backup.sh [schedule-name]
#   backup.sh                    # runs the `daily-backup` schedule
#   backup.sh my-schedule        # runs a custom schedule
#
# Doc:     docs/06-testing/04-backup-restore.md
#
set -euo pipefail

VELERO="${VELERO:-velero}"
SCHEDULE="${1:-daily-backup}"

fail() { echo "✘ $*" >&2; exit 1; }
ok()   { echo "✔ $*"; }

command -v "${VELERO}" >/dev/null || fail "velero CLI not found"

backup="${SCHEDULE}-manual-$(date +%Y%m%d-%H%M%S)"

echo "→ Creating backup '${backup}' from schedule '${SCHEDULE}'"
"${VELERO}" backup create "${backup}" --from-schedule "${SCHEDULE}"

echo "→ Watching backup..."
for _ in $(seq 1 60); do
  status=$("${VELERO}" backup get "${backup}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  case "$status" in
    Completed)  ok "backup ${backup} completed"; exit 0 ;;
    Failed|PartiallyFailed) fail "backup ${backup} ${status}" ;;
  esac
  sleep 5
done
fail "backup ${backup} timed out"