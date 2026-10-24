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

- [x] **ASSET-03 — deliverable complete** (Stage 0).

**Dependencies / sequencing:** ASSET-02, CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `tools/blender/export_modular_kit.py`; `game/assets/reference/`; `game/tests/scenes/asset_roundtrip.tscn`; `game/tests/scenes/asset_roundtrip.gd` (fixture smoke assertions); `docs/asset-roundtrip.md`.

**Interfaces:** `export_modular_kit.py` produces GLBs, baked PBR maps and metadata with source/version/settings; evaluated geometry replaces nonportable Geometry Nodes graphs.

**Supporting scope recorded by Main Agent, 23 October 2026:** Add a fixture script to assert the imported asset hierarchy, material texture bindings, dimensions and collision proxy presence. This makes the existing Godot round-trip acceptance executable and stays within ASSET-03; no shared test-runner registration is needed.

- [x] **Acceptance:** Normalize UVs/transforms and bake procedural appearance into image-backed materials. Godot import preserves orientation, scale, material response and collision intent. Repeat export is deterministic within documented tolerances and does not overwrite editable sources.

- [x] **Test expectations:** Export both references twice, compare mesh/material metadata and open the in-engine fixture. Verify sRGB/non-color maps, packed channel conventions, normals, dimensions and collision from first-person distance; capture visual evidence.

- [x] **Evidence recorded:** Repeat exports were byte-identical for GLBs and maps; manifest hashes/headers/maps/UV metadata, Godot import and fixture exit 0. [Report](../reports/ASSET-03.md), [instructions](../asset-roundtrip.md), [fixture capture](../evidence/ASSET-03/asset_roundtrip.png).

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Fixture validates imported normals, 0–1 UVs, unit object scale, base-color/ORM channels, orientation, dimensions and first-person wall/doorway collision. Exact commands, limitations and source preservation are recorded in the report.

### ASSET-04: Measure repeated asset use and set initial budgets

- [x] **ASSET-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** ASSET-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/tests/scenes/asset_stress.tscn`; `game/tests/scenes/asset_stress.gd` (runtime sample driver); `benchmarks/assets/`; `docs/asset-budgets.md`.

**Interfaces:** Provide measured triangle/material/texture/draw-call and memory budgets consumed by WORLD-06; budgets are evidence-backed configuration, not invented source requirements.

**Supporting scope recorded by Main Agent, 23 October 2026:** Add a fixture-owned GDScript sample driver that creates repeatable counts of the existing ASSET-03 visual/collision scenes, samples Godot performance monitors, checks collision proxy counts, and writes benchmark JSON/capture under the listed `benchmarks/assets/` path. It implements this task's prescribed scene profile; it does not create or cap production city content.

- [x] **Acceptance:** Profiled repeated reference modules and props at recorded counts, `gl_compatibility`, and fullscreen resolution. Reviewed shared material/texture resources and draw-call scaling, four/two-shape simple collision proxies, and Godot import LOD generation. Recorded a candidate fullscreen renderer/segment baseline for WORLD-06; final selection remains WORLD-06's responsibility. LOD transitions themselves were not distance-forced or visually assessed.

- [x] **Test expectations:** Compared isolated and repeated references, checked proxy counts, inspected LOD import settings, and recorded frame-time/memory evidence. No unacceptable blocker was found in this small sample; linear draw-call scaling warrants batching/culling/LOD evaluation as the world grows.

- [x] **Evidence recorded:** [ASSET-04 report](../reports/ASSET-04.md), [candidate budget notes](../asset-budgets.md), [raw fullscreen profile](../../benchmarks/assets/asset_stress.json), and [fixture capture](../../benchmarks/assets/asset_stress.png).

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Godot import and fullscreen MCP fixture completed without runtime errors; dummy-renderer invocation explicitly skipped visual metrics. This sample establishes comparison values only and does not cap the large continuous cyberpunk city; WORLD-06 must measure the integrated world before ratifying budgets.

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

### ASSET-07: Model and texture the Night Market hero door/storefront

- [x] **ASSET-07 — deliverable complete** (Stage 2; specifically approved 24 October 2026).

**Dependencies / sequencing:** ASSET-03, ASSET-04, approved Night Market neighborhood design. This asset task may proceed independently while WORLD-06's packaging evidence remains open; do not claim integrated neighborhood budget acceptance.

**Files / ownership:** `art/source/environment/night_market/night_market_hero.blend`; reproducible Blender MCP/export script under `tools/blender/`; `game/assets/environment/night_market/night_market_hero.glb` and baked maps; fullscreen inspection fixture `game/tests/scenes/night_market_asset_preview.tscn`; import verification helper `tools/godot/verify_asset07_import.gd`; `docs/reports/ASSET-07.md`; `docs/evidence/ASSET-07/`.

**Interfaces:** Godot GLB, meter-scale geometry, explicit render/collision pieces and baked Godot-compatible PBR images. Use asset pipeline names, pivots and map-channel rules.

**Supporting scope recorded before implementation:** Preserve Blender's active default scene. Create a new project source file. Model a roughly 4 m wide storefront section and a layered 1 m × 2.1 m service door with a frame/jamb, inset metal panels, handle/hinges/lock, security keypad, indicator lights, labels and visible edge wear. Author reusable 1K tileable material sets and 2K hero textures; bake base color, tangent normal, roughness, metallic, AO and emissive maps when appropriate. The door stays a model/asset task; no gameplay logic or service ownership changes.

- [x] **Acceptance:** Blender 5.2 source is editable and reproducible, with applied scale/rotation, valid UVs, connected PBR image nodes, separate low-cost collision proxy and reviewed multi-angle material/wireframe views. Godot 4.7.2 imports the GLB at correct first-person scale/orientation with textures and collision intact. Door close-up reads as layered, textured hardware, not a flat slab.
- [x] **Test expectations:** Run asset QA, save/reopen source, export/reimport in Godot, and inspect a fullscreen close-range fixture. Record actual dimensions, triangles, object/material/image counts, texture resolutions, file sizes and all QA warnings. Do not accept a render alone.
- [x] **Evidence recorded:** [ASSET-07 report](../reports/ASSET-07.md), [Blender material](../evidence/ASSET-07/review_material.png), [Blender wireframe](../evidence/ASSET-07/review_wire.png), [Godot fullscreen](../evidence/ASSET-07/godot_fullscreen_preview.png).

**Supporting scope recorded before fixture implementation (24 October 2026):** Add a disposable fullscreen close-range Godot scene for inspecting the exported storefront at first-person scale with a 1.7 m reference capsule and fixed camera. This implements the existing acceptance check and does not add gameplay or change the main scene.

**Supporting scope recorded before import-check implementation (24 October 2026):** Add a one-shot typed GDScript verifier that instantiates the preview scene, checks imported render bounds, counts render meshes and collision shapes, and exits nonzero if dimensions or the `-colonly` facade sections do not survive Godot import. It is a task verification helper, not a new gameplay/test-runner suite.

### ASSET-08: Produce the modular Night Market architecture/streetscape kit

- [ ] **ASSET-08 — deliverable complete** (Stage 2; specifically approved 24 October 2026).

**Dependencies / sequencing:** ASSET-07; approved neighborhood design; measured candidate budgets from ASSET-04.

**Files / ownership:** `art/source/environment/night_market/`; `tools/blender/`; `game/assets/environment/night_market/`; `docs/asset-manifest.md`; `docs/reports/ASSET-08.md`; `docs/evidence/ASSET-08/`.

**Interfaces:** Reuse ASSET-07 material, naming, UV, pivot, collision, and Godot export conventions. Share materials/textures where appropriate; do not collapse the source objects into a monolithic mesh.

**Supporting scope recorded before implementation (24 October 2026):** The user authorized reuse of assets from the MIT-licensed Hiraeth010/neon-district repository at source commit 6bea17fd7ad6467664382e14887fc89d1886448a to accelerate the Night Market. Use its editable Blender-authored city architecture, Lantern Market block assemblies and selected authored props; exclude user-reference campaign imagery. Preserve the required upstream MIT license and third-party notices with the imported deliverables, record source paths and hashes in the asset manifest, and convert to local Godot GLBs without adding a runtime dependency on the upstream project. Crop a 300 m × 300 m district slice consistent with the approved neighborhood footprint.

- [ ] **Acceptance:** Deliver reviewed modular façade bays, corner/upper-floor/roof variations, shutters/windows, awnings, fire-escape/stair pieces, market stall, and street-utility/sign/lighting props with coherent textured variants. All exported GLBs import at measured scale with correct map assignments and collision separation.
- [ ] **Test expectations:** Blender QA and multi-angle wire/material review for every module family; Godot asset fixture checks dimensions/material maps/collision; representative repeated-use scene records draw calls, triangles, texture memory and fullscreen frame observations. Budgets remain candidate values until integrated limits are ratified.
- [ ] **Evidence recorded:** Add source/export hashes where useful, measured asset facts, warning dispositions, commands/results, captures and report link.

### ASSET-09: Model and rig the featured Night Market characters

- [ ] **ASSET-09 — deliverable complete** (Stage 2; specifically approved 24 October 2026).

**Dependencies / sequencing:** ASSET-03 round-trip conventions and approved neighborhood design. **Dependency reconciliation recorded before implementation (24 October 2026):** ASSET-05 remains deferred and its free-source/first-person arms premise is not a prerequisite for this expressly approved custom Night Market character task. ASSET-09 uses new Blender-authored character assets, their own game-ready rigs, and the existing Godot glTF import contract; it does not import third-party models or complete the separate ASSET-05 work.

**Files / ownership:** `art/source/characters/night_market/`; `tools/blender/`; `game/assets/characters/night_market/`; character-specific Godot fixtures/tests; `docs/reports/ASSET-09.md`; `docs/evidence/ASSET-09/`.

**Interfaces:** Existing Mara and tactical-agent identity/behavior services remain authoritative. Character meshes and animations are transient presentation. Use Godot-compatible skinned glTF and the accepted animation contract.

- [ ] **Acceptance:** Create custom, textured, properly scaled Mara and one security guard, with rigs and the basic authored motion set used by their existing interaction/combat states. No downloaded models. Imported skin/materials/animations maintain scale, orientation and rig compatibility.
- [ ] **Test expectations:** Validate weights/topology, inspect idle/walk/interaction/combat poses and visible deformations, round-trip through Blender and Godot, and run a real character scene. Record mesh tris, texture maps, rig/clip details and visual evidence.
- [ ] **Evidence recorded:** Add exact tool/export/test results, captures and report link.

**Implementation note (24 October 2026):** Blender-authored Mara (7,752 tris, 1.72 m) and market security (6,856 tris, 1.91 m) now export with 12 materials, UVs, 512 px fabric maps, rigs and five clips each; runtime startup imports cleanly. Asset QA reports `pass:false` for overlapping layered costume panels and small detached detail islands. Weight, UV bounds/overlap, degenerate topology and transforms passed. Full pose deformation and fullscreen visual review remain unrun. See [ASSET-09 report](../reports/ASSET-09.md).

### ASSET-10: Replace Night Market vendor and passerby blockouts

- [ ] **ASSET-10 — deliverable complete** (Stage 2; specifically authorized by the user request on 24 October 2026).

**Dependencies / sequencing:** ASSET-09, ASSET-03 and approved Night Market neighborhood design.

**Files / ownership:** `art/source/characters/night_market/crowd/`; `game/assets/characters/night_market/crowd/`; `game/world/districts/night_market/night_market_runtime.gd`; focused fixture/evidence; `docs/reports/ASSET-10.md`.

**Supporting scope recorded before implementation:** Replace the current generic vendor and passerby capsule mannequins with two distinct, detailed, cyberpunk market character models. Keep their existing movement, interaction and damage/death behavior. Reuse the authored Night Market texture style and export contract. No downloaded models, new gameplay behaviors or crowd expansion.

- [ ] **Acceptance:** Both visible civilian roles have distinct, readable silhouettes, layered clothing, face/hair/accessory detail, cohesive PBR materials, and correct game scale. Existing scene interaction/movement/death remains connected.
- [ ] **Test expectations:** Review Blender multi-angle material/wire views, geometry/UV/transform QA, Godot import and focused live-scene view. Record counts, texture details, warnings, and evidence.
- [ ] **Evidence recorded:** Add exact tool/export/test results, captures and report link.

**Implementation note (24 October 2026):** Vendor (6,748 tris, 1.69 m) and courier (6,660 tris, 1.76 m) GLBs, civilian runtime hookups and Blender evidence exist in the preserved working tree. This work began in the same builder pass as ASSET-09; per the dependency above, do not accept or advance ASSET-10 until ASSET-09 is accepted. Asset QA reports `pass:false` for costume/accessory overlaps and small detached islands; UV bounds/overlap, weights, degenerate topology and transforms passed. Full pose deformation and fullscreen review remain unrun. See [ASSET-10 report](../reports/ASSET-10.md).
