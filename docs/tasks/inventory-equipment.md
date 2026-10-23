# Inventory & Equipment Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Keep grid possessions, equipment, rarity rolls and ammunition transactional and persistent.

**Architecture:** Owns inventory data and item lifecycle; the grid UI observes services and cannot directly edit records. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 4](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

## Global constraints

- Source priority: detailed design is approved for Stage 0/1; proposal confirmed requirements remain binding. Where the design is more specific, use it: single-player, Godot 4.7.2 with typed GDScript, Blender 5.2 target, local Ollama HTTP, grid inventory, family-keyed ammo, regenerating hack energy, and brief interior fades. Verify installed tools rather than assuming availability.
- Preserve the larger seamless exterior city direction, selected detailed interiors, stylized detailed visuals, first-person gun combat and no vehicles. Two chunks are feasibility content, not the final city scope.
- Target environment is the user-reported M5 MacBook Air with 16 GB shared memory. Do not assert benchmarks or release platforms have been verified. No paid service, large model download, new dependency or publishing is authorized by these plans.
- Persistent IDs and domain data survive unload/save/restart; runtime Nodes remain transient. Generative output is untrusted, bounded and subordinate to deterministic gameplay authority.

## Execution and completion rules

- Read the linked source sections, this file and the prerequisite tasks only; mock adjacent services until integration tasks require them. Proposed implementation paths below do not exist yet.
- Each task is a single bounded deliverable intended for one focused worker. If a deferred expansion task is selected, first split its content batches into separately reviewable tickets; it is not permission for an open-ended production pass.
- For logic tasks, add the named regression cases, demonstrate failure for the new behavior, implement it, then run the focused suite. CORE-01 establishes the runner; use `godot --headless --path game --script res://tests/run_tests.gd -- --suite <suite>` with the module suite registered there. Blender/visual/performance tasks use the stated evidence rather than artificial unit tests.
- Check a task only after its implementation, acceptance criteria and test evidence pass. Record exact commands, results and visual/performance evidence alongside the task, plus any follow-up issue. Use a small focused change/commit; preserve unrelated work.
- All implementation boxes start unchecked. Checking off planning documentation does not indicate game implementation is complete. Deferred Stage 2–5 work is outside the currently approved Stage 0/1 scope.

## Review focus

- Save/load failures must preserve valid live and disk state (CORE-03/04); reward replays must not duplicate inventory (INV-04, NPC-04).
- Scene unload/death/cancel must invalidate late work and preserve UUID ownership (WORLD-02/03/05, AI-04, NPC-02).
- Interrupted reload/heal and repeated callbacks must conserve ammo/items and prevent attacks while dead (PLAYER-04, INV-03).
- Prompt injection, unseen facts and invalid/stale action parameters must never mutate progression (NPC-01/04/05).
- Concurrent inference, streaming and combat must remain responsive within explicitly ratified memory/frame budgets (WORLD-06); visual/playtest evidence is required in addition to headless checks.

## Task checklist

### INV-01: Define stable item instances and reproducible loot

- [ ] **INV-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/item_instance.gd`; `game/features/inventory/item_definition.gd`; `game/features/inventory/loot_table.gd`; `game/tests/inventory/test_items.gd`.

**Interfaces:** ItemInstance contains uuid, item_id, grid_position, dimensions and rarity_tier; add persisted rolled_stats, magazine_ammo and equipment state. AmmoPouch is keyed by weapon family.

- [ ] **Acceptance:** Separate weapon identity from rarity. Use seeded weighted tables with bounded rolls and one UUID per spawned instance; persist rolls instead of rerolling on load. Rarity tier names/weights/stat bounds are configurable pending balance review.

- [ ] **Test expectations:** Same seed gives identical definitions/rolls; invalid weights or dimensions are rejected. Round-trip UUID, rarity, rolls and magazine without generating new values.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### INV-02: Implement grid placement and pickup transactions

- [ ] **INV-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/grid_inventory.gd`; `game/tests/inventory/test_grid.gd`.

**Interfaces:** `try_add_item(item: ItemInstance) -> bool`; document move/remove operations with all-or-nothing semantics and inventory_changed events.

- [ ] **Acceptance:** Grid rejects overlaps, out-of-bounds placements and duplicate UUIDs. Full inventory leaves world loot intact. Failed movement/pickup preserves original placement; capacity is configured rather than inventing a fixed size.

- [ ] **Test expectations:** Test corners, multi-cell items, full grid, overlapping/negative coordinates and duplicate pickup. Assert world removal occurs only after successful insertion and failed moves lose no items.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### INV-03: Add equipment, ammo and consumable services

- [ ] **INV-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-02, PLAYER-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/equipment_service.gd`; `game/features/inventory/ammo_pouch.gd`; `game/features/inventory/consumable_service.gd`; `game/tests/inventory/test_equipment.gd`.

**Interfaces:** `consume_ammo(family: String, amount: int) -> bool`; `use_consumable(grid_pos: Vector2) -> void`; publish active weapon stats and magazine transfer operations for PLAYER-04.

- [ ] **Acceptance:** Equip/swap/drop updates one owned instance; reserves belong to a family, magazines to a weapon. Reload transfers are atomic and bounded. Consumable use is validated and committed once with a successful health effect; define full-HP rejection without item loss.

- [ ] **Test expectations:** Test insufficient/negative ammo, wrong family, overflow magazine transfers, duplicate equips, dropping equipped items, double-use callbacks and full-HP/dead-player healing.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### INV-04: Persist inventory and guard reward transactions

- [ ] **INV-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-03, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/inventory_snapshot.gd`; `game/features/inventory/item_grants.gd`; `game/tests/inventory/test_persistence.gd`.

**Interfaces:** Expose idempotent item grants keyed by an authoritative reward/transaction ID for NPC-04; use CORE-04 inventory snapshot adapter.

- [ ] **Acceptance:** Save/load preserves grid, equipped UUIDs, rolls, magazine and reserves. Reject corrupt references/duplicate IDs before hydration. Full-grid rewards retain an unclaimed entitlement for retry; repeated grants cannot duplicate items.

- [ ] **Test expectations:** Round-trip equip/drop/pickup across multiple saves; load corrupt grids and duplicated UUIDs without partial state. Retry a full-grid grant and replay its transaction after load; exactly one item is awarded.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### INV-05: Build the drag-and-drop inventory and loot fixture

- [ ] **INV-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/ui/inventory_ui.tscn`; `game/ui/inventory_ui.gd`; `game/tests/scenes/inventory_fixture.tscn`.

**Interfaces:** Consume inventory/equipment events; invoke validated data operations for pickup, inspect, drag, equip, drop and use.

- [ ] **Acceptance:** Grid UI previews valid/invalid placement, shows rarity/stats/ammo and explains rejected pickup. Data can run headlessly without UI. Closing/reopening or a scene transition cancels drag without losing an item.

- [ ] **Test expectations:** Playtest full-grid pickup, failed drag, equip swap and consumable use; compare UI with model after save/load and interrupted drag. Verify keyboard/menu focus and player input locking.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### INV-06: Expand balanced loot and merchant content

- [ ] **INV-06 — deliverable complete** (Stage 2–4 (deferred)).

**Dependencies / sequencing:** WORLD-06, NPC-04; reviewed rarity/economy scope. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/data/`; `game/ui/merchant_ui.tscn`; `docs/loot-balance.md`.

**Interfaces:** Use the existing transactional grant/equipment services; merchant transactions require authoritative stock, price and eligibility.

- [ ] **Acceptance:** Split reviewed family/tier/drop-table content and complete trade UI into individual tasks before execution; no arbitrary model-created stock, price or reward.

- [ ] **Test expectations:** Test bounded roll distribution with seeded samples and trade retries/capacity failures; playtest whether rarity preserves family identity and meaningful loadout choice.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
