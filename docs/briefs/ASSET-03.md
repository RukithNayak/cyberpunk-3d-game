# Offline Asset Pipeline Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Produce actual editable 3D sources and verified engine exports before bulk content generation.

**Architecture:** Owns Blender scripts, source provenance, geometry/material QA and export metadata; runtime modules own imported behavior and collision interactions. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 8](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

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

### ASSET-03: Build repeatable baking/export and Godot round-trip

- [ ] **ASSET-03 — deliverable complete** (Stage 0).

**Dependencies / sequencing:** ASSET-02, CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `tools/blender/export_modular_kit.py`; `game/assets/reference/`; `game/tests/scenes/asset_roundtrip.tscn`; `docs/asset-roundtrip.md`.

**Interfaces:** `export_modular_kit.py` produces GLBs, baked PBR maps and metadata with source/version/settings; evaluated geometry replaces nonportable Geometry Nodes graphs.

- [ ] **Acceptance:** Normalize UVs/transforms and bake procedural appearance into image-backed materials. Godot import preserves orientation, scale, material response and collision intent. Repeat export is deterministic within documented tolerances and does not overwrite editable sources.

- [ ] **Test expectations:** Export both references twice, compare mesh/material metadata and open the in-engine fixture. Verify sRGB/non-color maps, packed channel conventions, normals, dimensions and collision from first-person distance; capture visual evidence.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

