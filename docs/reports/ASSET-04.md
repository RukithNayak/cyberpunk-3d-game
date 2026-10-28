# ASSET-04 — repeated asset profiling

## Status

Accepted by Main Agent, 23 October 2026 (Asia/Kolkata), for its scoped Stage 1 calibration deliverable. The profile measures the two existing ASSET-03 references only. It does not constrain the user's requested large, continuous cyberpunk city. Final renderer/production limits remain for WORLD-06.

## Changes

- Added a fullscreen Godot fixture that instantiates 1+1, 5+2, and 20+8 wall/prop visual and collision references, samples runtime render/frame/memory monitors, verifies proxy counts, and writes JSON plus a screenshot under `benchmarks/assets/`.
- Added [`asset-budgets.md`](../asset-budgets.md) with the observed values, candidate calibration, resource-sharing and draw-call implications, collision/LOD review, and measurement limits.
- Registered the support-driver scope in the ASSET-04 task and updated the master tracker.

## Verification

| Command/tool | Exit / observed result |
|---|---|
| `godot --headless --path game --editor --import` | 0; Godot 4.7.2 project import succeeded |
| `godot --headless --path game --scene res://tests/scenes/asset_stress.tscn` | 0; expected skip message because dummy renderer cannot measure draw calls/video memory |
| Godot MCP `run_project` with `res://tests/scenes/asset_stress.tscn` | Started and self-terminated after three fullscreen profiles; output recorded `gl_compatibility`, 2940×1846 viewport, fullscreen mode 3, 240 samples/case; `get_debug_output` returned `errors: []` |
| Visual review of `benchmarks/assets/asset_stress.png` | Inspected; the final view shows the repeated wall/door modules, prop placement, and cyan/magenta wayfinding strips. It is a benchmark view, not an art-direction approval of the future city. |
| `git diff --check` | 0; no whitespace errors |

Fullscreen result: 1+1 refs = 47 draw calls, 8.333 ms p95 frame interval, 6 proxy bodies; 5+2 = 129, 8.333 ms, 24 bodies; 20+8 = 504, 11.111 ms, 96 bodies. Median static memory rose from 46,438,967 to 49,239,559 bytes, while reported video memory remained 67,198,131 bytes. Each case retained 2 unique standard materials and 4 unique textures. See the raw JSON for all means/maxima and environment metadata.

## Limits and follow-up

- `meshes/generate_lods=true` is configured on all four imported reference GLBs. This fixture did not force/view threshold transitions; LOD popping/distance quality remains unverified.
- The sample confirms simple, low-triangle collision proxy counts, but does not load-test city-scale physics.
- `TIME_PROCESS` reports an isolated-reference max of 207.84 ms despite frame-interval samples around 8.333 ms. This suspicious monitor outlier is recorded and excluded from candidate budgeting.
- The benchmark contains no full city, streaming, district variety, traffic/NPCs, gameplay load, or interiors. Its values are samples to compare in WORLD-06, not city limits or acceptance thresholds.
- No Blender authoring/export was needed: this task profiles the existing round-tripped assets. Blender MCP availability is recorded in the master tracker/toolchain evidence.
