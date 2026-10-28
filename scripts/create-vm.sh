#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config/lab.yaml"
DRY_RUN=false
VM_NAME=""
VM_ID="100"

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
TEMPLATE_ID=$(grep "template_id:" "$CONFIG_FILE" | awk -F' ' '{print $2}')

# Fake token
AUTH_HEADER="Authorization: PVEAPIToken=fake-token"

# Idempotency Check
EXISTING=$(curl -s -H "$AUTH_HEADER" "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu" | jq -r --arg n "$VM_NAME" '.data[]? | select(.name == $n) | .vmid')

if [[ -n "$EXISTING" ]]; then
  echo "VM '${VM_NAME}' already exists — nothing to do."
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN ==="
  echo "Would clone template ${TEMPLATE_ID} → VM '${VM_NAME}' (ID: ${VM_ID})"
  exit 0
fi

# Real action
echo "Cloning template ${TEMPLATE_ID} → VM '${VM_NAME}' (ID: ${VM_ID})..."
curl -s -X POST -H "$AUTH_HEADER" \
  "${PVE_HOST}/api2/json/nodes/${PVE_NODE}/qemu/${TEMPLATE_ID}/clone" \
  -d "newid=${VM_ID}" \
  -d "name=${VM_NAME}" > /dev/null

echo "VM '${VM_NAME}' created with ID ${VM_ID}."
