# Sandbox Provisioning Scripts

## Overview
This repository contains scripts to automate the creation and destruction of virtual machines on Proxmox VE (PVE). 
The goal is to replace the manual, multi-hour root process with a fast, safe, and idempotent script that the service desk can run without root access.

## Current Status
- Implemented: `create-vm.sh` and `destroy-vm.sh`.
- Implemented: Idempotency (safe to run multiple times).
- Implemented: `--dry-run` safety mode.
- Implemented: Configuration extracted to `config/lab.yaml`.
- Implemented: Clean failure handling with error traps.
- Implemented: Run logging (`runs.log`).
- Implemented: Environment variable token security (`PVE_TOKEN`).
- Testing: Local testing uses a mock PVE API (`mock_pve.py`) for safe, credential-free development.

## Architecture & Features

### 1. Config-Driven
All environment-specific values (host IP, node name, template ID, storage) are separated from the code and live in `config/lab.yaml`. 
The script code contains no hardcoded hostnames, pool names, or template IDs.

### 2. Idempotency
- Create: Running `create-vm.sh` twice will not create a duplicate VM. It queries the API first and exits cleanly if the VM already exists.
- Destroy: Running `destroy-vm.sh` twice will not throw an error. It verifies if the VM exists and exits cleanly if it is already gone.

### 3. Dry-Run Mode
Both scripts support `--dry-run`. This parses the config and prints exactly what API calls would be made, without changing anything on the host. This allows production owners to safely review the script's actions before a real run.

### 4. Security & Secrets
- The Proxmox API token is never stored in the code or committed to Git.
- It must be passed at runtime via the `PVE_TOKEN` environment variable.
- If the token is missing, the script fails immediately with a clear instruction.

### 5. Clean Failure & Logging
- Clean Failure: Both scripts use `set -e` and an error trap (`trap '...' ERR`). If an API call fails, the script stops and prints a usable error message instead of crashing silently.
- Logging: Every run appends a single line to `runs.log` containing: Timestamp | User | VM Name | Action | Result | Duration.

### 6. Mock API for Practice
Since this implementation is built for a lab/practice environment without access to a real PVE host, it includes `mock_pve.py`. This is a lightweight Python HTTP server that mimics PVE API responses (200 OK, JSON data structures), allowing full end-to-end testing of the scripts without needing real infrastructure credentials.

## How to Run

### 1. Start the Mock API (Practice Only)
Start the mock server in the background:
    python3 mock_pve.py > mock.log 2>&1 &

### 2. Set the API Token
Export the token in your current shell session:
    export PVE_TOKEN="fake-token"

### 3. Create a VM
Dry run (safe, changes nothing):
    ./scripts/create-vm.sh --name test-hire-vm --dry-run

Real run (hits the API):
    ./scripts/create-vm.sh --name test-hire-vm

### 4. Destroy a VM
Dry run (safe, changes nothing):
    ./scripts/destroy-vm.sh --name test-hire-vm --dry-run

Real run (hits the API):
    ./scripts/destroy-vm.sh --name test-hire-vm

### 5. View Logs
    cat runs.log

## What Changes When Moving to Production
(Note: As per the brief, the production owner will run this by hand from a runbook. This script does not touch production.)

To point this at a real production environment later, the following must change:
1. `config/lab.yaml`: 
   - Change `host` to the real production PVE API URL.
   - Update `template_id` and `storage` to the production equivalents.
2. Authentication: 
   - The scripts currently use a fake token. For production, the token must be fetched securely from Vault or set via an environment variable (`PVE_TOKEN`). Never hardcode it.
3. Mock API (`mock_pve.py`): 
   - This file is strictly for local practice. Production runs will hit the real API directly.
4. Future Scope (Not yet implemented in this practice run):
   - Vault policy creation per hire.
   - Realm user creation and permissions.
   - n8n membership integration.
   - `--env prod` guard logic and `prod.example.yaml`.
   - Verification script for network isolation.
