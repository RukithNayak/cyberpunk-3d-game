## Task
- ID and title: ASSET-02 — Author the reference modular piece and close-up prop
- Status: complete, accepted by Main Agent
- Worker/model/reasoning: reference_assets / gpt-6-luna / medium (explicit dispatch settings recorded by Main Agent)
- Branch/commit or working-tree change reference: shared working tree; no commit created

## Files changed
- `art/reference/wall_doorway.blend` — editable 4 m wall module with a continuous shell and traversable 1.5 × 2.25 m doorway.
- `art/reference/mechanical_prop.blend` — editable utility junction assembly with a visible cable connector.
- `tools/blender/build_reference.py` — repeatable fixed-coordinate Blender 5.2.3 source generator, named component instances, materials, UVs, collision proxies, metrics and player-height renders.
- `docs/art-reference.md` — provisional visual language, measured dimensions/counts, follow-on budgets and evidence index.
- `docs/asset-provenance.md` — appended two asset records with origin, source hashes, tool versions, bounds, pivots and QA evidence.
- `docs/evidence/ASSET-02/` — build metrics; four QA JSON reports and `run_qa.py`; player-eye, material, random-color and wireframe review sheets; collision sheets; representative UV layout captures.

## Tests run
- Passed, repository root: `python3 -c 'import ast,pathlib; ast.parse(pathlib.Path("tools/blender/build_reference.py").read_text()); print("syntax: PASS")'` — exit 0. QA wrapper syntax was also parsed successfully.
- Passed, repository root: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/blender/build_reference.py` — exit 0, Blender 5.2.3 LTS. Wrote two editable sources and two 1,280 × 900 player-eye renders at Z = 1.65 m. The builder reported 17 wall mesh objects / 1,476 evaluated triangles total (render 1,428, collision 48), 32 prop mesh objects / 4,624 triangles total (render 4,600, collision 24); each has seven unique material slots and UV maps on all mesh objects.
- Passed, repository root: `/Applications/Blender.app/Contents/MacOS/Blender -b art/reference/wall_doorway.blend --python-exit-code 1 --python docs/evidence/ASSET-02/run_qa.py -- --role render --out docs/evidence/ASSET-02/wall_qa.json` — exit 0; 13 objects, 1,428 tris, zero errors/floating parts/z-fighting; 13 accepted warnings.
- Passed, repository root: `/Applications/Blender.app/Contents/MacOS/Blender -b art/reference/wall_doorway.blend --python-exit-code 1 --python docs/evidence/ASSET-02/run_qa.py -- --role collision --out docs/evidence/ASSET-02/wall_collision_qa.json` — exit 0; 4 objects, 48 tris, zero errors/floating parts/z-fighting; four accepted contact warnings.
- Passed, repository root: `/Applications/Blender.app/Contents/MacOS/Blender -b art/reference/mechanical_prop.blend --python-exit-code 1 --python docs/evidence/ASSET-02/run_qa.py -- --role render --out docs/evidence/ASSET-02/prop_qa.json` — exit 0; 30 objects, 4,600 tris, zero errors/floating parts/z-fighting; 23 accepted warnings.
- Passed, repository root: `/Applications/Blender.app/Contents/MacOS/Blender -b art/reference/mechanical_prop.blend --python-exit-code 1 --python docs/evidence/ASSET-02/run_qa.py -- --role collision --out docs/evidence/ASSET-02/prop_collision_qa.json` — exit 0; 2 objects, 24 tris, zero errors, warnings, floating parts or z-fighting.
- Passed visual review: Blender asset QA `review_shots.py` produced material, random-per-object and wireframe sheets for both assets, plus separate collision sheets. I inspected the player-eye renders, all material/random/wireframe sheets, collision sheets, and the wall/chassis UV layouts. The opening remains visibly clear; the proxies approximate the wall piers/header and prop chassis/cable.
- Not run: GLB export, texture baking, Godot import or in-engine visual acceptance; ASSET-03 owns those checks.

## Results
- Editable source and procedural-generation acceptance: met. Sources use meter units and fixed coordinates. Asset instances use explicit names (no Blender `.001` suffixes), `asset_role` metadata, material slots and individual 0–1 UV maps. No image textures or third-party assets are used.
- Geometry QA acceptance: all four game-profile checks pass. There are no non-manifold edges, degenerate faces, zero-area UV faces, missing UVs, detached parts, inverted islands, same-facing z-fighting pairs or unapplied scale findings. Full findings are under `docs/evidence/ASSET-02/`.
- Accepted wall render warnings: three cylinder collar caps retain planar end-cap n-gons. Remaining warnings are opposite-facing back-to-back contacts where the threshold meets the wall shell, trim frame meets the shell, and the service inset/lights sit into the plate. They are closed components intentionally embedded to form the assembly; random/wire sheets show no detached details. Wall collision warnings are expected shared faces where the two piers meet the header and threshold.
- Accepted prop render warnings: nine components (four fasteners, gauge bezel/face/hub, cable gland and conduit) have planar cylinder cap n-gons. Other warnings are opposite-facing back-to-back contacts between gauge layers/ticks and vent slots/block; these are intentional closed components seated through the neighboring front surfaces. The random/wire sheets show the gauge marks, service door, vents and cable attached and readable. Prop collision proxies are clean with no warnings.
- Measured bounds and pivots: wall render bounds 4.0 × 0.487 × 3.4 m, shell 4.0 × 0.3 × 3.4 m, pivot at lower southwest `(0,0,0)`; opening 1.5 × 2.25 m. Prop render bounds 0.92 × 0.605 × 1.28 m, chassis 0.92 × 0.34 × 1.28 m, bottom-center pivot `(0,0,0)`. Wall collision bounds are 4.0 × 0.3 × 3.4 m; prop collision bounds 0.92 × 0.67 × 1.28 m.
- Provisional budgets derived from these meshes: wall ≤2,000 render / ≤100 collision tris; junction ≤5,000 render / ≤100 collision tris. Texture proposal is ≤2 1,024² base-color/ORM maps per asset, with an optional 1,024² normal map; 512 px/m is suggested for a 2 m atlas tile. The sources have no maps and their per-object UVs are not packed or normalized to that target. The palette and budgets are engineering proposals pending human art review.
- Final artifact hashes: `wall_doorway.blend` 119,703 bytes, SHA-256 `265d4f7578be7172a3bfa64404017967a85b60098bb0b62d801b9937e9c76450`; `mechanical_prop.blend` 147,213 bytes, SHA-256 `fc078fdf5732cf76b605642eec47396609f6ac7194372e05c37a7e44153cf1f2`; `build_reference.py` SHA-256 `7324fca2681ca3ff7b7c32f6ee4c7262b24beb64a1940554aad0d52c92e008fd`.

## Risks
- Back-to-back assembly contacts are intentional but increase hidden-face triangle count; a future export-specific pass may remove hidden faces while preserving editable sources. Material settings are procedural only; map baking and engine appearance remain unverified.
- No GLB export or Godot import was produced because ASSET-03 owns that scope.

## Follow-up tasks
- Main Agent: review the proposal and accept/return ASSET-02; update tracker/task status. No tracker or task checkboxes were edited by this worker.
- ASSET-03: export evaluated meshes, validate GLBs and import into Godot; establish material/texture handling and check engine-side scale/orientation.

## Main Agent acceptance — 23 October 2026 (Asia/Kolkata)

Inspected player-eye/material/random/wire sheets and source generator. Reproduced all four QA commands (same report commands with output paths under /private/tmp), each exit 0, with identical triangle and accepted warning categories. Verified final source/generator hashes against the report. Flat cap n-gons and hidden opposite-facing closed assembly contacts are accepted for editable references; no same-facing z-fighting or floating components. Production art ratification and engine appearance are not claimed.
