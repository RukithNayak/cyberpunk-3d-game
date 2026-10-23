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

### ASSET-01: Verify Blender execution and asset conventions

- [x] **ASSET-01 — deliverable complete** (Stage 0).

**Dependencies / sequencing:** None; coordinate toolchain record with CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `docs/asset-pipeline.md`; `tools/blender/check_environment.py`; `art/reference/`; `docs/asset-provenance.md`.

**Interfaces:** Record actual executable/version and compatibility with Blender 5.2; define meter scale, pivots, naming, texture color spaces and source/export folders.

- [x] **Acceptance:** Run a minimal headless scene/export check. Distinguish detailed-design installation claim from currently verified availability; flag missing/incompatible Blender as a local blocker. Define license/source/generation records and binary storage policy before adding large files.

- [x] **Test expectations:** Record successful script exit and a small valid GLB, or reproducible missing-runtime evidence. Inspect conventions against Godot import. No installation, paid tool, account change or bulk download is implied.

- [x] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

Accepted 23 October 2026 (Asia/Kolkata), gpt-6-luna medium / Main Agent review; working tree. [Report and commands](../reports/ASSET-01-worker.md); [contact sheet](../evidence/ASSET-01-review.png). Blender export/QA and structural Godot import exit 0 with approved native access.

### ASSET-02: Author the reference modular piece and close-up prop

- [x] **ASSET-02 — deliverable complete** (Stage 0).

**Dependencies / sequencing:** ASSET-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `art/reference/wall_doorway.blend`; `art/reference/mechanical_prop.blend`; `tools/blender/build_reference.py`; `docs/art-reference.md`.

**Interfaces:** Exportable evaluated meshes, UVs, material slots and simplified collision proxies; retain source scripts/seeds and generation records.

- [x] **Acceptance:** Create an actual wall/doorway and close-up mechanical prop with stylized cyberpunk silhouettes/materials. Review at player eye height; define provisional dimensions, palette, texel density and triangle/texture budgets from this reference, without mass-producing city assets.

- [x] **Test expectations:** Run Blender asset QA for normals, degenerate/non-manifold geometry, coplanar overlaps and detached parts. Inspect contact sheets, UVs, scale/pivots and collisions; record intentional exceptions.

- [x] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

Accepted 23 October 2026 (Asia/Kolkata), reference_assets gpt-6-luna medium; Main Agent reproduced all four QA checks (exit 0) and reviewed eye/material/random/wire/UV/collision evidence. [Report](../reports/ASSET-02-worker.md), [reference/evidence](../art-reference.md). Wall 1,428 render/48 collision tris; prop 4,600/24. Intentional cap n-gons and opposite-facing closed assembly contacts accepted; palette/budgets provisional. Working tree codex/stage-0-readiness.

### ASSET-03: Build repeatable baking/export and Godot round-trip

- [ ] **ASSET-03 — deliverable complete** (Stage 0).

**Dependencies / sequencing:** ASSET-02, CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `tools/blender/export_modular_kit.py`; `game/assets/reference/`; `game/tests/scenes/asset_roundtrip.tscn`; `docs/asset-roundtrip.md`.

**Interfaces:** `export_modular_kit.py` produces GLBs, baked PBR maps and metadata with source/version/settings; evaluated geometry replaces nonportable Geometry Nodes graphs.

- [ ] **Acceptance:** Normalize UVs/transforms and bake procedural appearance into image-backed materials. Godot import preserves orientation, scale, material response and collision intent. Repeat export is deterministic within documented tolerances and does not overwrite editable sources.

- [ ] **Test expectations:** Export both references twice, compare mesh/material metadata and open the in-engine fixture. Verify sRGB/non-color maps, packed channel conventions, normals, dimensions and collision from first-person distance; capture visual evidence.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### ASSET-04: Measure repeated asset use and set initial budgets

- [ ] **ASSET-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** ASSET-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/tests/scenes/asset_stress.tscn`; `benchmarks/assets/`; `docs/asset-budgets.md`.

**Interfaces:** Provide measured triangle/material/texture/draw-call and memory budgets consumed by WORLD-06; budgets are evidence-backed configuration, not invented source requirements.

- [ ] **Acceptance:** Profile repeated reference modules and props at a recorded count/renderer/resolution. Review instancing, simplified collision and LOD choices. Record candidate renderer and asset limits for the combined test; final selection depends on WORLD-06.

- [ ] **Test expectations:** Compare isolated versus repeated use and inspect LOD/collision artifacts. Record frame-time and memory evidence; document unacceptable results and required reductions before bulk export.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### ASSET-05: Validate a humanoid rig and first-person animation reference

- [ ] **ASSET-05 — deliverable complete** (Stage 2 (deferred)).

**Dependencies / sequencing:** WORLD-06; acceptable free third-party source/license confirmed. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `art/characters/reference/`; `art/weapons/reference/`; `game/assets/characters/reference/`; `docs/animation-roundtrip.md`.

**Interfaces:** Free skeletal sources permitted by the detailed design (such as Mixamo) require provenance/license records; integrate Godot AnimationTree with AI/player states.

- [ ] **Acceptance:** Produce one reviewed goon rig and first-person weapon/arms reference. Verify bind pose, skeleton/clip naming and animation export before scaling content; mechanical/hard-surface assets remain authored in Blender.

- [ ] **Test expectations:** Inspect shoulder/elbow/hand deformation, locomotion/aim/death and reload interruption in Godot. Check retarget scale/orientation, material fidelity, collision and state transitions; a still render alone cannot pass.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### ASSET-06: Scale modular production and release provenance

- [ ] **ASSET-06 — deliverable complete** (Stage 3–5 (deferred)).

**Dependencies / sequencing:** ASSET-05; approved district/content scope and measured budgets. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `art/kits/`; `tools/blender/batch_export.py`; `game/assets/kits/`; `docs/asset-manifest.md`.

**Interfaces:** Use the same brief/source/QA/export metadata contracts; runtime weather and lighting use engine-native implementations.

- [ ] **Acceptance:** Split each approved kit, landmark, weapon and character set into small asset tickets with budgets and QA. Batch exports report failures without silently skipping assets; final credits and licenses cover every shipped source. Optional weather/day-night/face systems require separate scope approval.

- [ ] **Test expectations:** Re-run geometry/export QA per asset, representative repeated-use profiling per kit and final manifest/license completeness checks. Review district coherence, readable landmarks and actual accessible routes in-engine.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
