# Night Market Neighborhood Implementation Plan

> **For agentic workers:** use `superpowers:executing-plans` for the inline implementation. Keep Main Agent ownership of tracker, acceptance, shared contracts and integration; use bounded workers only for disjoint tasks when their outputs do not require simultaneous edits to the connected Blender scene.

**Goal:** Deliver a detailed, textured, playable 300 m × 300 m Night Market neighborhood as the first production-quality area in the larger seamless cyberpunk city.

**Architecture:** Author high-detail modular architecture, hero door, streetscape props and featured characters in Blender 5.2 using a new source file, Blender MCP, baked PBR materials and the documented GLB export pipeline. Integrate the asset kit into streamed Godot 4.7.2 scenes; compose existing inventory, hacking, NPC, combat, healing and persistence services without duplicating their authorities.

**Tech Stack:** Blender MCP / Python `bpy`, Godot 4.7.2 typed GDScript, glTF 2.0 GLB, existing test runner and world contracts.

**Spec:** `docs/superpowers/specs/2026-10-24-night-market-neighborhood-design.md`

## Global Constraints

- Keep the existing `feasibility.tscn` fixture and all current/uncommitted user files intact; never overwrite the live Blender default scene or source assets.
- Create new Blender sources under `art/source/environment/night_market/` and `art/source/characters/night_market/`; export to `game/assets/environment/night_market/` and `game/assets/characters/night_market/`.
- One Blender unit equals one meter. Use named collections, applied transforms, UV maps, Godot-compatible Principled materials and baked texture images. Keep render meshes separate from simple collision proxies.
- No downloaded models/textures, new dependencies, purchases, paid services, publishing, or release/signing setup.
- Do not claim full-world performance, visual, or human playtest acceptance from geometry QA or headless results. WORLD-06 remains in progress; preserve its open package and performance/headroom gates.
- Reuse current gameplay services, stable IDs and lifecycle contracts. Persistent data remains data-only. Validate authority and preconditions before gameplay commits.

## Review Focus

- Blender source, texture links and export must survive save/reopen and Godot reimport; check asset paths and byte sizes in ASSET-07/08.
- Door scale, detail and material readability at first-person distance; render Blender angle views and inspect the imported Godot scene in fullscreen.
- Collision proxies must leave intended market/alley routes walkable and block only intended barriers; check in-engine traversal and the focused neighborhood route.
- Chunk boundaries must preserve actor/loot/hack state and not leave AI without synchronized navigation; use existing lifecycle and navigation suites before content acceptance.
- Merchant content must not permit model-invented stock/prices or duplicate transactions; test unauthorized IDs, capacity rejection and retries in INV-07.
- Performance remains descriptive until WORLD-06 limits are ratified; report draw calls, texture memory, process memory, route frame intervals and any unavailable headroom measurement.

## Task 1: Record approved production scope

**Files:**
- Modify `docs/tasks/offline-asset-pipeline.md` — add ASSET-07/08/09 acceptance, ownership, dependencies and evidence checkboxes.
- Modify `docs/tasks/inventory-equipment.md` — add INV-07 for one bounded configured Night Market merchant.
- Modify `docs/tasks/hacking-subsystem.md` — add HACK-07 for the district's distinct integrated hack routes.
- Modify `docs/tasks/world-scene-manager.md` — add WORLD-08/09 neighborhood assembly and playtest gates; preserve WORLD-07 as later city expansion/release outline.
- Modify `docs/master-progress.md` — record explicit user approval to start Stage 2 content, active task, dependencies, and unchanged WORLD-06 gates.
- Add report stubs only where needed; do not mark any new task complete.

- [ ] Record each task's scope before implementation and verify each ID is unique.
- [ ] Set ASSET-07 as active first task. ASSET-07 can proceed independently while WORLD-06 packaging/headroom evidence is unresolved; WORLD-08 must report those gates separately.

## Task 2: ASSET-07 — hero service door and storefront section

**Files:**
- Create `art/source/environment/night_market/night_market_hero.blend` and reproducible source/export script(s).
- Create `game/assets/environment/night_market/night_market_hero.glb` and baked texture set(s).
- Create `docs/reports/ASSET-07.md` and visual/QA evidence.

- [ ] Use Blender MCP environment report first; confirm Blender version/renderer without altering its active default scene.
- [ ] Model a real-scale ~4 m wide storefront slice and a ~1 m × 2.1 m layered service door with visible frame, jamb, inset panels, hinge/handle, lock/keypad, emissive status element, decals and wear.
- [ ] Author 1K reusable tileable materials and 2K hero door textures (base color, tangent normal, roughness, metallic, AO and emissive as needed), bake procedural detail to images, and pack/map channels per the existing pipeline contract.
- [ ] Run Blender asset QA on all deliverable render/collision meshes; record dimensions, tri counts, material/image counts, map resolutions and QA warnings. Render and inspect multiple material and wireframe angles through Blender MCP.
- [ ] Export Godot GLB and reimport in Godot 4.7.2. Verify scale/orientation, material maps, door clear width/height, collision and first-person close-up appearance. Record exact commands/exits and image evidence. Fix real failures before ASSET-07 acceptance.

## Task 3: ASSET-08 — modular architecture and streetscape kit

**Files:**
- Extend the new Night Market Blender source and export collections under `art/source/environment/night_market/` and `game/assets/environment/night_market/`.
- Create asset manifest/budget observations and `docs/reports/ASSET-08.md`.

- [ ] Create modular wall/facade bays, shop corner, upper storeys, shutters/windows, roofline, awning, stair/fire-escape pieces, market stall, signage and street-utility props with authored variants.
- [ ] Bake and reuse cohesive material sets; ensure UV scale and wear detail match the ASSET-07 hero slice.
- [ ] Run Blender QA and multi-angle inspections on the batch; export/reimport all assets in Godot and verify GLB dimensions/materials/proxies.
- [ ] Measure representative repeated-use draw calls, triangles, texture sizes/memory and route frame observations. Treat as candidates until integrated limits are ratified.

## Task 4: ASSET-09 — featured characters

**Files:**
- Create `art/source/characters/night_market/` and `game/assets/characters/night_market/` for custom Mara and security guard models/rigs; update the relevant animation-roundtrip task/report as required by the approved scope.

- [ ] Reconcile the exact character animation/export interface with deferred ASSET-05 before modeling; record the supporting scope/task change first.
- [ ] Model custom, recognizable market-contact and security silhouettes in Blender; create rigs and the basic idle/walk/interaction or combat motion needed by their existing Godot states. Do not use downloaded models.
- [ ] Run character geometry/weight QA, inspect representative deformations, export/reimport, and verify orientation, scale, material texture fidelity and state animations in Godot.

## Task 5: INV-07 — one configured merchant

**Files:**
- Use existing inventory and merchant interfaces; add only task-owned stock resource/UI or test fixture files under inventory module paths.

- [ ] Define a small authored stock list, price bounds, ownership and eligibility for the Night Market merchant. No generated item IDs, prices or rewards.
- [ ] Use a regression for successful purchase, stale/repeated transaction, insufficient currency/capacity and missing-stock rejection; run the focused suite and check the dialogue-to-trade route.
- [ ] Record exact focused suite output and keep broad rarity/economy balancing inside the existing later INV-06 decision.

## Task 6: HACK-07 — district hacking routes

**Files:**
- Add district-owned targets/fixtures under `game/world/districts/night_market/` and any explicitly assigned hacking test files.

- [ ] Compose existing hacking services into a camera-surveilled market approach, detailed service-door shortcut, walkable bypass and at least one utility/security target with a distinct consequence.
- [ ] Preserve the no-hack/resource-depleted route and persistent entity lifecycle. Add no new hacking capability unless it is separately recorded first.
- [ ] Verify target visibility, distance, line of sight, route reachability, effect consequence and save/unload/reload behavior with focused fixture checks.

## Task 7: WORLD-08 — streamed neighborhood assembly

**Files:**
- Create `game/world/districts/night_market/` scenes/manifests and a standalone neighborhood entry scene; do not change project main scene without separate approval.
- Use `game/assets/environment/night_market/`, `game/assets/characters/night_market/` and existing services.

- [ ] Assemble a connected 3 × 3 block grid with plaza, central market, repair row, security crossing, service alley, two route loops, three authored interiors and readable vertical landmarks.
- [ ] Place the configured vendor, Mara/mission contact, combat encounter, distinct hack scenarios, loot/medical supply and checkpoint so each is reachable by alternate paths.
- [ ] Use existing chunk lifecycle/navigation and interior transition contracts. Check crossings/backtracking, NPC/loot/door persistence, route and interior transitions, mouse-look, and the save/load loop.
- [ ] Run Godot import, focused world and relevant inventory/hacking/character tests; launch the world via Godot MCP and inspect a fullscreen capture. Record errors/warnings honestly.
- [ ] Measure the world at the approved fullscreen renderer: route frame intervals, draw calls, texture/process memory, chunk activation/hitches and model-load behavior where available. Do not claim pass/fail for unratified limits or packaged Mac evidence.

## Task 8: WORLD-09 — playtest and polish

**Files:**
- Update only Night Market scenes/assets and task/report evidence allocated after WORLD-08 review.

- [ ] Review accessible routes, landmark readability, collision clearances, and texture/model quality at first-person distance.
- [ ] Record human playtest notes for market navigation, dialogue/trade, combat/flank, hacking/bypass, pickups, interiors and save/reload. Fix blocking issues and regressions.
- [ ] Document remaining performance, packaging, human-visual and future-city work. Keep the large city expansion as separately tracked WORLD-07+ tasks.

## Execution notes

- Each Blender task uses the same connected MCP scene sequentially; never run two workers against that live scene at once. Asset generation should use named collections and preserve source files.
- Do not batch-create the full city. First get the hero door/storefront accepted, then scale the kit and build the neighborhood from proven assets.
- Stop and record any new task if scope expands beyond these accepted IDs. Do not weaken their acceptance criteria to force a pass.
