# Asset budget calibration — ASSET-04

## Scope and conditions

This is a calibration run using only the ASSET-03 wall/doorway and mechanical-prop references. It is not a measurement of the full game or a limit on city size/content. The confirmed direction remains a large, continuous, walkable cyberpunk city with distinct districts, landmarks, vertical routes, and selected detailed interiors. Full-city content must be profiled in WORLD-06 before final limits are chosen.

Recorded on 23 October 2026 with Godot 4.7.2 stable, debug build, `gl_compatibility`, fullscreen (`window_mode=3`), screen 2940×1912, viewport 2940×1846, frame cap disabled. Each case warmed up for 90 frames and sampled 240 frames. No alternate resolutions were tested, per user direction. The device runtime reported OpenGL 4.1 Metal / Apple M5. Results are display-, driver-, and debug-build-dependent.

## Observations

| Profile | Wall + prop refs | Reference triangles | Render mesh nodes | Draw calls | Frame interval ms (median / p95 / max) | Static memory median | Video memory |
|---|---:|---:|---:|---:|---:|---:|---:|
| Isolated reference | 1 + 1 | 6,028 | 43 | 47 | 8.333 / 8.333 / 8.333 | 46,438,967 B | 67,198,131 B |
| Small block | 5 + 2 | 16,340 | 125 | 129 | 8.333 / 8.333 / 8.333 | 46,951,871 B | 67,198,131 B |
| Street segment | 20 + 8 | 65,360 | 500 | 504 | 8.333 / 11.111 / 16.661 | 49,239,559 B | 67,198,131 B |

The cases reused 2 unique `StandardMaterial3D` resources and 4 textures (two 1K maps per source asset) at every count. This indicates sharing across repeated references is effective for those resources. Draw calls still scale with the represented geometry: 504 at the 20-wall/8-prop sample. The GLBs contain multiple render mesh nodes, not a demonstrated `MultiMeshInstance3D` batch. Larger streets should evaluate static batching/chunk meshes and distance LOD before bulk production.

The source collision exports use four simple proxy shapes / 48 collision triangles per wall and two / 24 per prop. The fixture verified 6, 24, and 96 `StaticBody3D`/`CollisionShape3D` pairs for the three profiles. At the largest sample this is 96 static bodies and 1,152 aggregate collision triangles. These simple proxies are appropriate candidates for walkable city geometry; the sample does not establish physics cost at city scale.

All four imported GLBs have `meshes/generate_lods=true` in their Godot import settings. This confirms LOD generation is enabled, but the fixture did not force distance thresholds, record active LOD transitions, or evaluate visible popping. The capture shows the repeated street segment and prop placement at one view distance; it does not visually prove an LOD transition.

## Candidate calibration for WORLD-06

Use `gl_compatibility` fullscreen with a representative 20-wall/8-prop segment as a candidate baseline case. On this run it used 504 draw calls, 65,360 reference triangles, 96 simple collision bodies, and had an 11.111 ms p95 / 16.661 ms max rendered frame interval. This sample stayed below a 16.7 ms interval at p95, but had a single larger interval and is only a short debug capture. These are candidate comparison values, not hard city-wide maxima, a renderer selection, or production acceptance limits. WORLD-06 must profile the integrated world and ratify budgets after its combined workload and playtest evidence exist.

The `TIME_PROCESS` monitor showed a large isolated-case outlier (207.84 ms max, despite a stable 8.333 ms p95 frame interval); monitor values appear inconsistent for that baseline sample and are retained in the raw JSON rather than used for the candidate budget. Static/video memory values are totals for the running scene, not per-asset deltas. A production city is expected to exceed this fixture substantially and needs streaming, culling, LOD and batching strategies sized by full-world measurement.

## Evidence

- Raw samples and runtime metadata: [`benchmarks/assets/asset_stress.json`](../benchmarks/assets/asset_stress.json)
- Fullscreen fixture capture: [`benchmarks/assets/asset_stress.png`](../benchmarks/assets/asset_stress.png)
- Asset import and source details: [`docs/asset-roundtrip.md`](asset-roundtrip.md)
- Task execution record: [`docs/reports/ASSET-04.md`](reports/ASSET-04.md)
