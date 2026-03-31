#!/bin/bash
if [[ "${1:-}" == "-a" || "${1:-}" == "--author" ]]; then
  echo "Author: FoxSecIntel"
  echo "Repository: https://github.com/FoxSecIntel/filemonitor
  echo "Tool: filemonitor.sh"
  exit 0
fi

set -euo pipefail

__r17q_blob="wqhWaWN0b3J5IGlzIG5vdCB3aW5uaW5nIGZvciBvdXJzZWx2ZXMsIGJ1dCBmb3Igb3RoZXJzLiAtIFRoZSBNYW5kYWxvcmlhbsKoCg=="
if [[ "${1:-}" == "m" || "${1:-}" == "-m" ]]; then
  echo "$__r17q_blob" | base64 --decode
  exit 0
fi


usage() {
  cat <<'EOF'
Usage:
  filemonitor.sh [options]

Options:
  -f FILES        Comma-separated file list (default: /etc/passwd,/etc/hosts)
  -i SECONDS      Check interval in seconds (default: 60)
  -e EMAIL        Email recipient for alerts (optional)
  -l LOG_FILE     Log file path (default: /var/log/file-monitor.log)
  -s STATE_DIR    State directory for hashes (default: /var/lib/filemonitor)
  --once          Run one check pass and exit
  --init          Initialize baseline and exit
  -h, --help      Show help

Examples:
  ./filemonitor.sh --once
  ./filemonitor.sh -f /etc/passwd,/etc/shadow -i 30
  ./filemonitor.sh -e you@example.com -l /tmp/filemonitor.log
EOF
}

FILES=("/etc/passwd" "/etc/hosts")
CHECK_INTERVAL=60
EMAIL_ADDRESS=""
LOG_FILE="/var/log/file-monitor.log"
STATE_DIR="/var/lib/filemonitor"
RUN_ONCE=false
INIT_ONLY=false

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for -f"; exit 1; }
      IFS=',' read -r -a FILES <<< "$1"
      shift
      ;;
    -i)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for -i"; exit 1; }
      CHECK_INTERVAL="$1"
      [[ "$CHECK_INTERVAL" =~ ^[0-9]+$ ]] || { echo "Interval must be numeric"; exit 1; }
      shift
      ;;
    -e)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for -e"; exit 1; }
      EMAIL_ADDRESS="$1"
      shift
      ;;
    -l)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for -l"; exit 1; }
      LOG_FILE="$1"
      shift
      ;;
    -s)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for -s"; exit 1; }
      STATE_DIR="$1"
      shift
      ;;
    --once) RUN_ONCE=true; shift ;;
    --init) INIT_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

mkdir -p "$STATE_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

log_msg() {
  local message="$1"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" | tee -a "$LOG_FILE" >/dev/null
}

send_email() {
  local subject="$1"
  local message="$2"
  [[ -n "$EMAIL_ADDRESS" ]] || return 0

  if command -v mail >/dev/null 2>&1; then
    printf '%s\n' "$message" | mail -s "$subject" "$EMAIL_ADDRESS" || true
  else
    log_msg "WARN: 'mail' not installed; cannot send email alert to $EMAIL_ADDRESS"
  fi
}

state_file_for() {
  local f="$1"
  local safe
  safe="$(printf '%s' "$f" | sed 's#[^A-Za-z0-9._-]#_#g')"
  printf '%s/%s.sha256\n' "$STATE_DIR" "$safe"
}

hash_file() {
  local f="$1"
  sha256sum "$f" | awk '{print $1}'
}

check_pass() {
  for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      log_msg "WARN: file missing: $file"
      continue
    fi

    local_state="$(state_file_for "$file")"
    current_hash="$(hash_file "$file")"

    if [[ ! -f "$local_state" ]]; then
      printf '%s\n' "$current_hash" > "$local_state"
      log_msg "INFO: baseline initialized for $file"
      continue
    fi

    previous_hash="$(cat "$local_state")"
    if [[ "$current_hash" != "$previous_hash" ]]; then
      msg="ALERT: $file changed on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
      log_msg "$msg"
      send_email "[filemonitor] $file changed" "$msg"
      printf '%s\n' "$current_hash" > "$local_state"
    fi
  done
}

if $INIT_ONLY; then
  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || { log_msg "WARN: cannot init missing file $f"; continue; }
    printf '%s\n' "$(hash_file "$f")" > "$(state_file_for "$f")"
    log_msg "INFO: initialized baseline for $f"
  done
  exit 0
fi

trap 'log_msg "INFO: received signal, stopping filemonitor"; exit 0' SIGINT SIGTERM

if $RUN_ONCE; then
  check_pass
  exit 0
fi

log_msg "INFO: filemonitor started (interval=${CHECK_INTERVAL}s, files=${#FILES[@]})"
while true; do
  check_pass
  sleep "$CHECK_INTERVAL"
done
