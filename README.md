# Sandbox Provisioning Script (Practice)

## Current Status
- `create-vm.sh` implemented with `--dry-run` and idempotency.
- Uses a mock PVE API (`mock_pve.py`) for local testing.

## How to run
1. Start mock API: `python3 mock_pve.py &`
2. Dry run: `./scripts/create-vm.sh --name test --dry-run`
3. Real run: `./scripts/create-vm.sh --name test`
