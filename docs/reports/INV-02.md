# INV-02 — Grid placement and pickup transactions

**Status:** Accepted, Stage 1.  
**Owner:** Main Agent.  
**Dependency:** INV-01 accepted.

## Changes

- Added configured rectangular grid dimensions and data-only item ownership in `GridInventory`.
- Added overlap, bounds and duplicate-UUID rejection. Inventory stores deep copies so callers cannot change owned placement/data through a shared Resource reference.
- Added all-or-nothing movement and removal, with `inventory_changed` emitted only after successful commits.
- Added pickup transaction accepting a transient world Node. Failed insertion leaves that node in the world; successful insertion queues it for deletion. No Node is retained in inventory state.
- Registered focused `inventory_grid` tests and included them in `all`.

## Verification

| Command / check | Exit / observed result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_grid` before implementation | 1; expected missing `grid_inventory.gd` regression. |
| Final `godot --headless --path game --editor --import` | 0; registered `GridInventory` and initialized project. |
| Final `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_grid` | 0; 26 cases, 0 failures. Covers corner/multi-cell placement, overlap/bounds/negative/duplicate rejection, full inventory, failed move preservation, successful movement/removal, event behavior, and pickup/world-drop ownership. |
| Final `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0; 377 cases, 0 failures. Existing suite printed one ObjectDB and one physics-body RID teardown warning at shutdown. |
| Godot MCP version and project info | Successful; Godot `4.7.2.stable.official.ed1daf0bf`, project path resolved to this repository's `game/`. |
| Final `git diff --check` | 0. |

A test-only cleanup initially called `free()` on a world-drop Node already queued by `queue_free()` and Godot exited with signal 11 (134). The fixture cleanup was corrected; the final focused and integrated runs exit 0. This did not require a gameplay code change. No visual check was applicable to this data-only service. Inventory serialization/persistence and UI are not part of INV-02.

## Next

INV-03 is eligible after INV-02 and PLAYER-02. It adds equipment, ammo and consumable services.
