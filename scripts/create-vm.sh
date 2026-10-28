#!/usr/bin/env bash
set -euo pipefail

# --- Trap Errors for Clean Failure ---
trap 'echo "Error: Creation failed at line $LINENO. Check logs." >&2' ERR

CONFIG_FILE="config/lab.yaml"
DRY_RUN=false
VM_NAME=""
VM_ID="100"
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

# --- Token Check (No secrets in repo) ---
if [[ -z "${PVE_TOKEN:-}" ]]; then
  echo "Error: PVE_TOKEN environment variable not set." >&2
  echo "Run: export PVE_TOKEN='fake-token'" >&2
  exit 1
fi
AUTH_HEADER="Authorization: PVEAPIToken=${PVE_TOKEN}"

# Read config
PVE_HOST=$(grep "host:" "$CONFIG_FILE" | awk -F'"' '{print $2}')
PVE_NODE=$(grep "node:" "$CONFIG_FILE" | awk -F'"' '{print $2}')
TEMPLATE_ID=$(grep "template_id:" "$CONFIG_FILE" | awk -F' ' '{print $2}')

# --- Logging Helper ---
log_run() {
  local action="$1" result="$2" duration="$3"
  echo "$(date -Iseconds) | user=$(whoami) | vm=${VM_NAME} | action=${action} | result=${result} | duration=${duration}s" >> "$LOG_FILE"
}

START_TIME=$(date +%s)

# Idempotency Check
EXISTING=$(curl -s -H "$AUTH_HEADER" "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu" | jq -r --arg n "$VM_NAME" '.data[]? | select(.name == $n) | .vmid')

if [[ -n "$EXISTING" ]]; then
  echo "VM '${VM_NAME}' already exists — nothing to do."
  END_TIME=$(date +%s)
  log_run "create" "skipped_exists" "$((END_TIME - START_TIME))"
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN ==="
  echo "Would clone template ${TEMPLATE_ID} → VM '${VM_NAME}' (ID: ${VM_ID})"
  END_TIME=$(date +%s)
  log_run "create" "dry_run" "$((END_TIME - START_TIME))"
  exit 0
fi

# Real action
echo "Cloning template ${TEMPLATE_ID} → VM '${VM_NAME}' (ID: ${VM_ID})..."
curl -s -X POST -H "$AUTH_HEADER" \
  "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu/${TEMPLATE_ID}/clone" \
  -d "newid=${VM_ID}" \
  -d "name=${VM_NAME}" > /dev/null

echo "VM '${VM_NAME}' created with ID ${VM_ID}."
END_TIME=$(date +%s)
log_run "create" "success" "$((END_TIME - START_TIME))"
