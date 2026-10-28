#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config/lab.yaml"
DRY_RUN=false
VM_NAME=""

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

# Read config
PVE_HOST=$(grep "host:" "$CONFIG_FILE" | awk -F'"' '{print $2}')
PVE_NODE=$(grep "node:" "$CONFIG_FILE" | awk -F'"' '{print $2}')
AUTH_HEADER="Authorization: PVEAPIToken=fake-token"

# --- Idempotency Check: Does the VM actually exist? ---
VM_ID=$(curl -s -H "$AUTH_HEADER" "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu" | jq -r --arg n "$VM_NAME" '.data[]? | select(.name == $n) | .vmid')

# If VM_ID is empty, the VM doesn't exist. We're done.
if [[ -z "$VM_ID" ]]; then
  echo "VM '${VM_NAME}' not found — nothing to destroy."
  exit 0
fi

# --- Dry Run ---
if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN ==="
  echo "Would delete VM '${VM_NAME}' (ID: ${VM_ID})"
  echo "API: DELETE ${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu/${VM_ID}"
  exit 0
fi

# --- Real Action ---
echo "Deleting VM '${VM_NAME}' (ID: ${VM_ID})..."
curl -s -X DELETE -H "$AUTH_HEADER" \
  "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu/${VM_ID}?purge=1" > /dev/null

echo "VM '${VM_NAME}' deleted."
