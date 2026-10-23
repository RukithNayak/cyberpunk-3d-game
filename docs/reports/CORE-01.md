# CORE-01 — Runtime and test harness

## Task
- Status: awaiting Main Agent review.
- Owner: Main Agent / session model; Stage 0; dependencies: none.
- Change reference: uncommitted working tree; no initial repository commit.

## Files changed
- `AGENTS.md`: folder ownership, scope and verification commands.
- `.gitignore`: engine caches, local credentials/builds, model weights and backups.
- `game/project.godot`: minimal Godot project, temporary compatibility renderer.
- `game/tests/run_tests.gd`: typed dependency-free suite runner with explicit exits.
- `game/tests/scenes/startup.tscn`: bounded native startup fixture (supporting CORE-01 acceptance, not gameplay expansion).
- `docs/toolchain.md`: fresh runtime/hardware/storage/provider evidence.

## Tests run
Exact commands and results: [toolchain](../toolchain.md).
- Clean headless import exit 0.
- Sample/all: 2 cases each, exit 0.
- Deliberately failing fixture: 1 expected failure, exit 1.
- Unknown suite: exit 2.
- Native macOS launch: ten frames, exit 0, Apple M5 Compatibility renderer.
- Ollama HTTP health/model inventory: exit 7, server unavailable; on-disk manifests inventoried separately.
- Initial sandbox import had environmental errors despite exit 0; clean escalated run supersedes it.
- Not run: performance/inference/packaging, outside this task; no human playtest claimed.

## Results
Godot pin matches. Runtime and harness acceptance have reproducible results.
Ollama unavailability is recorded as required; it blocks real-provider evaluation,
not the test harness. No weights downloaded. Hardware and storage recorded.

## Risks
On-disk model manifests do not establish provider health or suitable licensed weights.
No production renderer or performance threshold is ratified.

## Follow-up tasks
CORE-02 after review; ASSET-01 independently active. NPC-06 real-provider gate
requires a reachable server and evaluated model. No new scope added.
