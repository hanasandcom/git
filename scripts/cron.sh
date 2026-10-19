#!/usr/bin/env bash
set -euo pipefail

GIT_DIR="${GIT_DIR:-/home/hanasand/git}"
SYNC_LOG="${SYNC_LOG:-$GIT_DIR/standby-sync.log}"
DOCTOR_LOG="${DOCTOR_LOG:-$GIT_DIR/forgejo-doctor.log}"
LOCK="${LOCK:-/tmp/forgejo-standby-sync.lock}"
SYNC_SCHEDULE="${SYNC_SCHEDULE:-*/15 * * * *}"
DOCTOR_SCHEDULE="${DOCTOR_SCHEDULE:-17 * * * *}"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

crontab -l 2>/dev/null \
    | grep -vE 'sync-to-ovh\.sh|scripts/sync\.sh' \
    | grep -vE 'forgejo-doctor\.sh|scripts/doctor\.sh' >"$tmp" || true

printf '%s\n' "$SYNC_SCHEDULE cd $GIT_DIR && LOCK=$LOCK LOG=$SYNC_LOG bash scripts/sync.sh" >>"$tmp"
printf '%s\n' "$DOCTOR_SCHEDULE cd $GIT_DIR && LOG_FILE=$DOCTOR_LOG FIX=1 bash scripts/doctor.sh" >>"$tmp"

crontab "$tmp"
crontab -l
