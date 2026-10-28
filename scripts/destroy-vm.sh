#!/usr/bin/env bash
set -euo pipefail

# --- Trap Errors for Clean Failure ---
trap 'echo "Error: Destruction failed at line $LINENO. Check logs." >&2' ERR

CONFIG_FILE="config/lab.yaml"
DRY_RUN=false
VM_NAME=""
LOG_FILE="runs.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)   VM_NAME="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$VM_NAME" ]]; then
  echo "Error: --name is required" >&2
  exit 1
fi

# --- Token Check ---
if [[ -z "${PVE_TOKEN:-}" ]]; then
  echo "Error: PVE_TOKEN environment variable not set." >&2
  echo "Run: export PVE_TOKEN='fake-token'" >&2
  exit 1
fi
AUTH_HEADER="Authorization: PVEAPIToken=${PVE_TOKEN}"

# Read config
PVE_HOST=$(grep "host:" "$CONFIG_FILE" | awk -F'"' '{print $2}')
PVE_NODE=$(grep "node:" "$CONFIG_FILE" | awk -F'"' '{print $2}')

# --- Logging Helper ---
log_run() {
  local action="$1" result="$2" duration="$3"
  echo "$(date -Iseconds) | user=$(whoami) | vm=${VM_NAME} | action=${action} | result=${result} | duration=${duration}s" >> "$LOG_FILE"
}

START_TIME=$(date +%s)

# Idempotency Check
VM_ID=$(curl -s -H "$AUTH_HEADER" "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu" | jq -r --arg n "$VM_NAME" '.data[]? | select(.name == $n) | .vmid')

if [[ -z "$VM_ID" ]]; then
  echo "VM '${VM_NAME}' not found — nothing to destroy."
  END_TIME=$(date +%s)
  log_run "destroy" "skipped_missing" "$((END_TIME - START_TIME))"
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN ==="
  echo "Would delete VM '${VM_NAME}' (ID: ${VM_ID})"
  END_TIME=$(date +%s)
  log_run "destroy" "dry_run" "$((END_TIME - START_TIME))"
  exit 0
fi

# Real action
echo "Deleting VM '${VM_NAME}' (ID: ${VM_ID})..."
curl -s -X DELETE -H "$AUTH_HEADER" \
  "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu/${VM_ID}?purge=1" > /dev/null

echo "VM '${VM_NAME}' deleted."
END_TIME=$(date +%s)
log_run "destroy" "success" "$((END_TIME - START_TIME))"
