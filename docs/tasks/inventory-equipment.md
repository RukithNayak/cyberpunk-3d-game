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
- Follow the fast prototype verification policy in [AGENTS.md](../../AGENTS.md): focused checks and a quick gameplay/asset smoke check; routine red-first testing, exhaustive edge cases and separate review are optional. Task test expectations guide risk coverage; deferred checks must be recorded honestly.
- Accept working task behavior under the fast prototype policy; record minor bugs and deferred checks without marking those checks passed. Crashes, save corruption, blocked progression and unauthorized model actions remain blockers. Keep a short report with exact commands/exits and preserve unrelated work.
- All implementation boxes start unchecked. Checking off planning documentation does not indicate game implementation is complete. Deferred Stage 2–5 work is outside the currently approved Stage 0/1 scope.

## Review focus

- Save/load failures must preserve valid live and disk state (CORE-03/04); reward replays must not duplicate inventory (INV-04, NPC-04).
- Scene unload/death/cancel must invalidate late work and preserve UUID ownership (WORLD-02/03/05, AI-04, NPC-02).
- Interrupted reload/heal and repeated callbacks must conserve ammo/items and prevent attacks while dead (PLAYER-04, INV-03).
- Prompt injection, unseen facts and invalid/stale action parameters must never mutate progression (NPC-01/04/05).
- Concurrent inference, streaming and combat must remain responsive within explicitly ratified memory/frame budgets (WORLD-06); visual/playtest evidence is required in addition to headless checks.

## Task checklist

### INV-01: Define stable item instances and reproducible loot

- [x] **INV-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/item_instance.gd`; `game/features/inventory/item_definition.gd`; `game/features/inventory/loot_table.gd`; `game/tests/inventory/test_items.gd`.

**Interfaces:** ItemInstance contains uuid, item_id, grid_position, dimensions and rarity_tier; add persisted rolled_stats, magazine_ammo and equipment state. AmmoPouch is keyed by weapon family.

- [x] **Acceptance:** ItemDefinition identity is independent of rarity. Configurable weighted tables use seeded bounded stat rolls and one fresh UUID per spawned instance; ItemInstance serializes rolls instead of rerolling on load. Tier names, weights and multipliers remain resource-configurable; no balance approval is implied.

- [x] **Test expectations:** Same seed repeats the selected item/rarity/roll values; invalid weights/dimensions reject. JSON round-trip retains UUID, rarity, rolls, equipment state and magazine without generating new values.

- [x] **Evidence recorded:** [INV-01 report](../reports/INV-01.md); focused24/24, integrated all351/351, import/project reference check/diff check exit0. Godot MCP confirmed runtime version and project metadata.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Engineering limits (16-cell item dimension, magazine capacity 128, per-entry weight 1,000,000 and roll multiplier cap 8) are guards, not approved content/balance values. See [report](../reports/INV-01.md).

### INV-02: Implement grid placement and pickup transactions

- [x] **INV-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/grid_inventory.gd`; `game/tests/inventory/test_grid.gd`.

**Interfaces:** `try_add_item(item: ItemInstance) -> bool`; document move/remove operations with all-or-nothing semantics and inventory_changed events.

- [x] **Acceptance:** Grid rejects overlaps, out-of-bounds placements and duplicate UUIDs. Full inventory leaves world loot intact. Failed movement/pickup preserves original placement; capacity is configured rather than inventing a fixed size.

- [x] **Test expectations:** Test corners, multi-cell items, full grid, overlapping/negative coordinates and duplicate pickup. Assert world removal occurs only after successful insertion and failed moves lose no items.

- [x] **Evidence recorded:** [INV-02 report](../reports/INV-02.md); focused26/26 and integrated all377/377, import and diff checks exit0. No visual evidence required for this data-only service.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Grid capacity is supplied at construction. Stored item Resources are deep copies; `inventory_changed` fires only after committed changes. Pickup accepts a transient world Node only for `queue_free()` after insertion and does not retain it. See [report](../reports/INV-02.md).

### INV-03: Add equipment, ammo and consumable services

- [x] **INV-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-02, PLAYER-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/equipment_service.gd`; `game/features/inventory/ammo_pouch.gd`; `game/features/inventory/consumable_service.gd`; `game/features/inventory/item_definition.gd` (consumable metadata); `game/features/inventory/grid_inventory.gd` (atomic update and cell lookup support); `game/tests/inventory/test_equipment.gd`.

**Interfaces:** `consume_ammo(family: String, amount: int) -> bool`; equip/swap/drop and bounded magazine reload operations; publish active weapon stats for PLAYER-04; `use_consumable(grid_pos: Vector2) -> bool` reports whether the item was consumed and healing applied.

- [x] **Acceptance:** Equip/swap/drop updates one owned instance; reserves belong to a family, magazines to a weapon. Reload transfers are atomic and bounded. Consumables use an authored positive heal amount. Consumable use is validated and committed once with a successful health effect; full-HP/dead-player rejection preserves the item.

- [x] **Test expectations:** Test insufficient/negative ammo, wrong family, overflow magazine transfers, duplicate equips, dropping equipped items, double-use callbacks and full-HP/dead-player healing.

- [x] **Evidence recorded:** [INV-03 report](../reports/INV-03.md); focused35/35, grid26/26, integrated all412/412, import and diff checks exit0. Godot MCP confirms 4.7.2/project path.

Supporting contracts recorded before implementation (23 October 2026): `ItemDefinition.consumable_heal_amount` identifies med consumables; `GridInventory.try_update_items()` commits equipped-state/magazine updates atomically, and `get_item_at()` resolves selected grid cells. These support the existing equipment/reload/use acceptance and do not include INV-04 persistence or PLAYER-04 firing integration.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Active weapon stats are published as an item-derived dictionary for PLAYER-04 to adapt; firing/reload animation state and save/load remain in PLAYER-04 and INV-04.

### INV-04: Persist inventory and guard reward transactions

- [x] **INV-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-03, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/inventory_snapshot.gd`; `game/features/inventory/item_grants.gd`; `game/features/inventory/grid_inventory.gd` and `ammo_pouch.gd` (silent prepared replacement support); `game/tests/inventory/test_persistence.gd`; test-runner registration.

**Interfaces:** Expose idempotent item grants keyed by an authoritative reward/transaction ID for NPC-04; use CORE-04 inventory snapshot adapter.

- [x] **Acceptance:** Save/load preserves grid, equipped UUIDs, rolls, magazine and reserves. Reject corrupt references/duplicate IDs before hydration. Full-grid rewards retain an unclaimed entitlement for retry; repeated grants cannot duplicate items.

- [x] **Test expectations:** Round-trip equip/drop/pickup across multiple saves; load corrupt grids and duplicated UUIDs without partial state. Retry a full-grid grant and replay its transaction after load; exactly one item is awarded.

- [x] **Evidence recorded:** [INV-04 report](../reports/INV-04.md); focused persistence29/29, integrated all441/441, Godot import and `git diff --check` exit0. Godot MCP confirms 4.7.2 and project metadata. All-suite shutdown reports one ObjectDB and one physics RID leak; suite exits 0.

Supporting contracts recorded before implementation (23 October 2026): inventory hydration prepares validated grid items, reserves and grant-ledger data before a silent commit through the existing CORE-04 `SnapshotAdapters` domain callback. Grid/ammo owners expose prepared replacement APIs; grid provides a separate notification after cross-owner reward commits. Pending and claimed reward transaction records are included in the inventory snapshot. This does not modify `SnapshotAdapters` or add inventory persistence to the core adapter itself.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. [Report](../reports/INV-04.md). INV-05 is now dependency-eligible; PLAYER-04 and other Stage 1 tasks remain eligible under their task dependencies.

### INV-05: Build the drag-and-drop inventory and loot fixture

- [x] **INV-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** INV-04. Prerequisite IDs resolve through the master progress task index.

**Supporting UI scope recorded before implementation (23 October 2026):** Add the shared `game/ui/cyberpunk_theme.tres`, reusable low-intensity canvas shaders, project Theme assignment, fullscreen default and responsive amber/cyan inventory restyle. Preserve every existing INV-05 operation; expose fixture-only debug controls on F2 to keep the fullscreen visual unobstructed. When a configured `WeaponStateMachine` is present, route healing through its cancellable action hooks; retain the existing direct service path for data-only fixtures without a player action owner. The same Theme is consumed by PLAYER-05; no new gameplay data is introduced here.

**Files / ownership:** `game/ui/inventory_ui.tscn`; `game/ui/inventory_ui.gd`; `game/tests/scenes/inventory_fixture.tscn` and `.gd`. Supporting UI resources/configuration: `game/ui/cyberpunk_theme.tres`; `game/ui/{scanline,status_flicker}.gdshader`; `game/project.godot`; `game/tests/inventory/test_ui.gd`; `game/tests/run_tests.gd`.

**Interfaces:** Consume inventory/equipment events; invoke validated data operations for pickup, inspect, drag, equip, drop and use.

- [x] **Acceptance:** Grid UI previews valid/invalid placement, shows rarity/stats/ammo and explains rejected pickup. Data can run headlessly without UI. Closing/reopening or a scene transition cancels drag without losing an item.

- [x] **Test expectations:** Exercise full-grid pickup, failed drag, equip swap and consumable use; compare UI with model after SaveStore load and interrupted drag. Verify keyboard focus and player input locking through focused interaction checks.

- [x] **Evidence recorded:** [INV-05 report](../reports/INV-05.md); focused inventory_ui42/42 and integrated all483/483, import, project reference check and diff check exit0. Godot MCP fixture runtime has no errors. Initial screenshot/click-through was deferred; see the later visual revision evidence below (human click-through still unrun).

Supporting verification recorded 23 October 2026: add `game/tests/inventory/test_ui.gd` and register the `inventory_ui` suite in `game/tests/run_tests.gd` to verify UI actions preserve the INV-02/03/04 ownership contracts, failed pickup/placement feedback, cancellation, service-driven actions and refresh after snapshot hydration. This tests the existing INV-05 acceptance and does not expand product scope.

**User-directed visual revision recorded before implementation (23 October 2026):** The first INV-05/PLAYER-05 visual pass was rejected as too plain, boxy, dark and monotonous. Restyle within existing task ownership: use installed Avenir Next system fonts, brighter layered graphite surfaces, a wider equipment-card grid, an organized detail/action rail and stronger cyan/red accents inspired by the supplied references. Add UI checks for font, contrast and card sizing; preserve service behavior and use only authoritative data. See the [design revision](../superpowers/specs/2026-10-23-cyberpunk-ui-overhaul-design.md).

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. At initial acceptance, manual screenshot and free-play click-through were deferred because the configured Godot MCP exposed runtime output but no input/capture controls, and local `screencapture` could not create an image from the display. A later user-directed visual revision produced screenshots, linked below; human click-through remains unrun. Run `godot --path game game/tests/scenes/inventory_fixture.tscn` for the fixture; use its Fill Grid button to exercise rejection and retry.

Visual revision, 23 October 2026: After user rejection of the initial UI look, replaced the primary font with Avenir Next, raised panel contrast, enlarged equipment cards and organized the readout/actions rail. Regression checks: font/panel/card assertions failed before the revision (3 failures), then inventory_ui46/46 and player_hud9/9 passed; import and diff check exit0. Godot MCP fixture runtime errors empty. Fullscreen captures inspected: [inventory](../evidence/CYBERPUNK-UI-OVERHAUL/inventory-revised.png) and [HUD](../evidence/CYBERPUNK-UI-OVERHAUL/hud-revised.png). Human click-through remains unrun.

### INV-06: Expand balanced loot and merchant content

- [ ] **INV-06 — deliverable complete** (Stage 2–4 (deferred)).

**Dependencies / sequencing:** WORLD-06, NPC-04; reviewed rarity/economy scope. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/inventory/data/`; `game/ui/merchant_ui.tscn`; `docs/loot-balance.md`.

**Interfaces:** Use the existing transactional grant/equipment services; merchant transactions require authoritative stock, price and eligibility.

- [ ] **Acceptance:** Split reviewed family/tier/drop-table content and complete trade UI into individual tasks before execution; no arbitrary model-created stock, price or reward.

- [ ] **Test expectations:** Test bounded roll distribution with seeded samples and trade retries/capacity failures; playtest whether rarity preserves family identity and meaningful loadout choice.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
