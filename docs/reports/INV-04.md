# INV-04 — Inventory persistence and reward transactions

**Status:** Accepted for Stage 1, 23 October 2026 (Asia/Kolkata).  
**Owner:** Main Agent.  
**Scope:** Data-only inventory snapshot preparation/commit through the existing CORE-04 domain callbacks, silent grid/ammo replacement, and idempotent reward transactions with persisted pending entitlements.

## Changes

- Added `InventorySnapshot` to capture, validate and prepare the configured grid, item definitions/UUIDs, equipment slots, ammo reserves, and grant ledger. It rejects malformed, duplicate, unknown-definition, overlapping and out-of-bounds records before a silent commit.
- Added `ItemGrants` with transaction-ID validation, pending full-grid entitlements, retry and replay idempotency. It commits inventory and ledger state before notifying listeners.
- Added data-only prepared replacement APIs to `GridInventory` and `AmmoPouch`. Existing CORE-04 `SnapshotAdapters` remains unchanged and receives the inventory domain via callbacks.
- Registered `inventory_persistence` and covered multiple save/load states, equip/drop/pickup, corrupt snapshots, full-grid retry, and replay before and after reload.

## Verification evidence

Commands were run from the repository root with Godot `4.7.2.stable.official.ed1daf0bf`:

| Command | Exit | Observed result |
|---|---:|---|
| `godot --headless --path game --editor --import` | 0 | Import completed. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_persistence` | 0 | `Suite inventory_persistence: 29 cases, 0 failures`. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | `Suite all: 441 cases, 0 failures`. Shutdown emitted one ObjectDB leak warning and one `P11GodotBody3D` RID leak error; these did not change the process exit or suite result. |
| `git diff --check` | 0 | No whitespace errors. |

Regression-first evidence: the focused suite was first run before adding the two INV-04 services; it exited 1 with two expected unavailable-service failures. After implementation, the same command passed all 29 checks.

Godot MCP calls `get_godot_version` and `get_project_info` both succeeded. They reported `4.7.2.stable.official.ed1daf0bf`, project path `/Users/rukithnayak/Documents/ChatGPT/Cyberpunk 3D Game/game`, 9 scenes, 47 scripts and 8 assets.

## Acceptance limits

No visual evidence is applicable to this data-only task. The all-suite shutdown leak warnings are recorded and remain to be investigated if they persist; focused persistence is warning-free. No changes were made to CORE-04 adapters or to Stage 2–5 scope.
