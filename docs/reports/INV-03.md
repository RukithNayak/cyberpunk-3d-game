# INV-03 — Equipment, ammunition, and consumables

**Status:** Accepted, Stage 1.  
**Owner:** Main Agent.  
**Dependencies:** INV-02 and PLAYER-02 accepted.

## Changes

- Added `AmmoPouch` with family-keyed reserves, configurable per-family capacity, and atomic positive add/consume operations.
- Added `EquipmentService` for weapon equip/swap/unequip/drop, item-derived active weapon stats, and bounded reload transfers. Reload validates ownership/family/capacity, removes reserve rounds, commits the magazine through one inventory update, and restores reserves if that update rejects.
- Added `ConsumableService` using authored `ItemDefinition.consumable_heal_amount`. Healing rejects malformed positions, invalid/non-consumable items, full health and dead actors; a reentrancy guard prevents a health callback from using the same item twice.
- Added supporting `GridInventory` cell lookup and validated atomic multi-item update; `ItemDefinition` now validates an optional bounded heal amount. The INV-03 task recorded these support contracts before implementation.
- Registered focused `inventory_equipment` tests in the runner and integrated `all` suite.

Active weapon stats are published as a dictionary combining definition base stats with instance rolls and magazine/family metadata. PLAYER-04 firing/reload state-machine integration and INV-04 persistence remain separate tasks.

## Verification

| Command / check | Exit / observed result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_equipment` before implementation | 1; three expected failures because equipment, ammo, and consumable services were absent. |
| `godot --headless --path game --editor --import` | 0; registered all new global scripts and completed project import. |
| Final `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_equipment` | 0; 35 cases, 0 failures, no teardown leak warning. Covers family reserves, invalid/insufficient/wrong-family ammo, capacity, equip/swap/duplicate/drop, active stats, bounded reload, successful healing, reentrant use, full health and death. |
| Final `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_grid` | 0; 26 cases, 0 failures after extending GridInventory. |
| Final `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0; 412 cases, 0 failures. Existing integrated run prints one ObjectDB and one physics-body RID teardown warning at shutdown. |
| Godot MCP version and project info | Successful; Godot `4.7.2.stable.official.ed1daf0bf`, project path resolved to this repository's `game/`. |
| Final `git diff --check` | 0. |

An initial post-implementation test invocation before editor import printed class-cache parse errors and is not counted as a pass. The required import refreshed the registered class list; all final runs above executed the new tests. No visual test was applicable to these data services.

## Next

INV-04 is eligible after INV-03 and CORE-04, and is recommended next. PLAYER-04 also becomes eligible to consume these services.
