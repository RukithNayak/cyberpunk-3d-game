# WORLD-06 Feasibility Build

**Status:** In progress; integrated prototype checks pass, full task acceptance remains open.
**Date:** 24 October 2026 (Asia/Kolkata)
**Scope:** Stage 1 fixture only. Existing gameplay modules are composed without changing production ownership or `project.godot`'s main scene.

## Integrated fixture

Run from the repository root:

```sh
godot --path game res://tests/scenes/feasibility.tscn
```

The fullscreen fixture combines the accepted first-person player and pistol, a security enemy, two existing streamed chunks, Mara Vega's authored retrieval offer, a persistent hackable door, a world loot pickup, grid inventory, healing and checkpoint persistence. `WASD` moves; mouse aims and `Enter` fires; `E` opens contact; `F` picks up loot; `H` heals; `G` hacks the service door; `Tab` opens inventory; `F5` saves; `F9` restores; `Esc` pauses. Dialogue is hidden at startup and opens on contact.

The viewport is fullscreen at 2940×1846 on the measured Mac. The scene is feasibility greybox content and does not represent the target city's content density or art quality. [Fullscreen capture](../benchmarks/feasibility/feasibility_startup.png).

## Environment and measurements

- OS: macOS 26.5.1 (build 25F80), Apple M5, 17,179,869,184 bytes unified memory.
- Godot: 4.7.2 stable (`ed1daf0bf`), OpenGL 4.1 Metal compatibility renderer. Runtime reports adapter `Apple M5`, fullscreen mode `3`, viewport 2940×1846.
- Game-only fullscreen run: 76.37 seconds, 10,884 frame samples. Frame interval median 6.896 ms, p95 6.944 ms, max 150 ms. Godot process monitor static memory median/p95/max 58,086,071 / 58,571,591 / 58,571,591 bytes. Process-time monitor median/p95/max 0.159 / 15.088 / 168.007 ms; physics-process monitor 0.603 / 0.716 / 7.596 ms; draw calls 37 median/p95. These are raw observations, not a pass/fail result: the project has not ratified frame or memory thresholds.
- Latest fullscreen comparison: 29.90 seconds game-only (4,296 samples) then 60.60 seconds with local inference and five seam crossings (8,783 samples). Game-only frame interval median/p95/max 6.896/6.981/100.499 ms, process-time median/p95/max 0.205/48.349/169.849 ms, physics median/p95/max 0.601/0.724/7.416 ms, draw calls 37, and static-memory median/max 57,944,732/58,314,024 bytes. Concurrent frame interval median/p95/max 6.896/6.944/9.593 ms, process-time median/p95/max 0.415/2.258/10.802 ms, physics median/p95/max 0.611/0.714/0.868 ms, draw calls 37, and static-memory median/max 59,130,593/59,867,606 bytes. All 22 in-game requests completed (0 failures, 0 fallbacks); full-response latency median/p95/max 2,015.018/2,233.442/2,470.411 ms. Five seam crossings activated in 7.367–14.073 ms, with 0.5-second settled-frame maximum 6.896 ms and static-memory changes -44 to 6,472 bytes. The raw samples are [`sustained_load.json`](../benchmarks/feasibility/sustained_load.json), command output is [`sustained_load.log`](../benchmarks/feasibility/sustained_load.log).
- The initial benchmark ran while nine stale headless Godot processes had been alive 31 minutes to over 7 hours; that raw sample is preserved in [`sustained_load_contended.json`](../benchmarks/feasibility/sustained_load_contended.json). The nine processes were terminated before two repeats; the no-extra-probe run is preserved in [`sustained_load_no_probe.json`](../benchmarks/feasibility/sustained_load_no_probe.json). During the latest run, `python3 benchmarks/feasibility/model_probe.py` sampled host/game/model processes concurrently: 16 GiB host memory, game RSS 221,424 KB, a separate desktop Godot process RSS 59,872 KB, and `llama-server` RSS 5,421,280 KB; Ollama reported the 5.6 GB model fully on GPU. The probe measured 192.722 ms first content and 633.526 ms full response for a 50/13-token exchange. The separate desktop Godot app (35 minutes old, ~1% CPU) remains a source of host noise. The latest run also recorded 100.499 ms frame and 169.849 ms process-time maxima in game-only phase. Memory headroom and numeric acceptance thresholds remain unresolved; treat all figures as observations, not a performance pass.
- Earlier one-time probe: installed `llama3:willowbrook`, 8.0B parameters, Q4_0, 8,192-token context. `ollama ps` reported 5.6 GB at 100% GPU; `llama-server` RSS was 5,480,048 KB and game RSS was 201,232 KB. One streamed 50-token prompt/13-token response measured 51.31 ms to first content and 496.85 ms to completion. These earlier values are retained as historical observations; the latest concurrent probe is summarized above and in `concurrent_model_probe.json`.
- The machine-wide memory total is 16 GiB. A sustained concurrent render-plus-inference interval and one-time OS/game/model RSS sample during that interval exist, but free-memory headroom was not measured and there is no ratified threshold for interpreting the results.

Raw samples and the local probe driver: [`benchmarks/feasibility/`](../benchmarks/feasibility/), including [`runtime_metrics.json`](../benchmarks/feasibility/runtime_metrics.json), [`headless_smoke.log`](../benchmarks/feasibility/headless_smoke.log), [`all_suite_final.log`](../benchmarks/feasibility/all_suite_final.log), [`concurrent_model_probe.json`](../benchmarks/feasibility/concurrent_model_probe.json), and [`model_probe.py`](../benchmarks/feasibility/model_probe.py).

## Commands and observed results

| Command / action | Exit | Observed result |
|---|---:|---|
| `godot --headless --path game --editor --import` | 0 | Godot 4.7.2 imported the project. |
| `godot --headless --path game res://tests/scenes/feasibility.tscn -- --smoke` | 0 | Latest run 24/24: two-chunk activation/traversal/backtracking, combat damage, mission offer, local Ollama response, hack, loot/grid pickup, healing, checkpoint restore/fresh-process reload, offline fallback, and cancellation of delayed dialogue after walking away, chunk unload, or death. Relaunch subprocess printed one ObjectDB teardown leak warning. See [`headless_smoke.log`](../benchmarks/feasibility/headless_smoke.log). |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite sample` | 0 | 2 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` (first run) | 0 | 1,064 cases, 0 failures. Shutdown printed three ObjectDB leaks and one `P11GodotBody3D` RID leak. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` (final rerun) | 1 | 1,051 cases, 2 failures. `ai_navigation` had an empty route at “navigation map returns a routed path around the wall”; the isolated-suite wrapper also failed. Shutdown printed three ObjectDB leaks and one `P11GodotBody3D` RID leak. The intermittent AI-03 issue remains outside WORLD-06 ownership. See [`all_suite_final.log`](../benchmarks/feasibility/all_suite_final.log). |
| `python3 benchmarks/feasibility/model_probe.py` (during the latest benchmark's concurrent phase) | 0 | Recorded host capacity, game/desktop Godot and model-runner RSS, GPU placement and first/full streamed response latency. The distinct desktop Godot process is listed in the raw probe. |
| `godot --path game res://tests/scenes/feasibility.tscn` | 0 on clean interrupt after 76.37 seconds | Fullscreen app ran on OpenGL 4.1 Metal / Apple M5; wrote the rendered capture and runtime metrics. |
| `godot --path game res://tests/scenes/feasibility.tscn -- --benchmark` | 0 | Latest run completed 29.90-second baseline plus 60.60-second concurrent inference phase, 22 successful requests and five active chunk crossings. Per-phase stats and per-crossing static-memory deltas are in `sustained_load.json`; command output is in `sustained_load.log`. Stale headless fixture processes were stopped; a desktop Godot process remained and timing outliers still occurred, so this is descriptive, not an acceptance result. Earlier runs are preserved as `sustained_load_no_probe.json` and `sustained_load_contended.json`. |
| Godot MCP `run_project`, `get_debug_output`, `stop_project` | Started / read / stopped | Project reported Godot 4.7.2 and the fixture reached its ready message. Debug output contained existing GDScript warnings, no runtime errors. |
| `find game -name export_presets.cfg -print` | 0 | No export preset found. |
| `ls -la "$HOME/Library/Application Support/Godot/export_templates"` | 0 | Export-template directory was empty. |
| `godot --headless --path game --export-release "macOS" /tmp/world06_feasibility.zip` | 1 | Godot refused because the project has no root `export_presets.cfg`. No preset or template was installed or added. |

## Remaining acceptance evidence

- No user-approved numeric frame-time or memory-headroom thresholds exist. Keep the raw measurements descriptive until those are ratified.
- Sustained comparison and boundary observations now exist, with a one-time OS/game/model RSS sample during the interval. Free-memory headroom and a ratified threshold for interpreting the results are still missing.
- Walking-away, unload and death cancellation now pass delayed-response smoke checks.
- No human gameplay/readability/playability review has been performed.
- A packaged macOS build is unavailable until an export preset and Godot export templates exist. Adding either is outside the recorded scope and no template installation was authorized.
- The fullscreen capture is a simple greybox; it establishes that the scene renders and its HUD is present, not art-direction acceptance.

WORLD-06 remains in progress. See the [task report](reports/WORLD-06.md) and [owning task](tasks/world-scene-manager.md#world-06-assemble-and-measure-the-integrated-feasibility-build).
