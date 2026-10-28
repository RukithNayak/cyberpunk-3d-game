## Task
- ID/title: WORLD-03 — Hydrate and unload persistent entities; Stage 1.
- Status: complete; Main Agent accepted 23 October 2026 (Asia/Kolkata).
- Base/change reference: `f71404e` on `codex/stage-0-readiness`; changes remain in the working tree. No commit or push performed for this task.
- Ownership: Main Agent integration/shared contracts/configuration; worker `entity_hydrator` owned hydrator/tests/projection fixture; `world03_review` performed bounded read-only review. Both spawns requested gpt-6-luna / medium with `fork_turns: none`; requests were accepted without a tool rejection. Follow-up reused the worker context. Worker self-reported no independently verifiable runtime model identity; no alternative model was deliberately substituted.
- [Design/ownership ledger](../briefs/WORLD-03.md), [worker report](WORLD-03-worker.md), [review/resolution](WORLD-03-review.md).

## Files changed
- `game/world/entity_hydrator.gd` — transient registry-to-scene projection service; generation checks, prepare/activate/retire phases, immediate checked authority commits, tombstone suppression, invalidation notifications and callback-safe ownership cleanup.
- `game/world/chunk_manifest.gd` — optional data-only authored entity descriptors; validate UUIDs, globally unique ownership, relative node paths and initial state before accepting manifest.
- `game/world/chunk_loader.gd` — optional lifecycle protocol; hydrate before scene entry, enable after entry/before manager acknowledgement, retire before teardown, and preserve retry behavior on projection failure. Existing no-hydrator consumers remain compatible.
- `game/persistence/entity_registry.gd` — checked boolean commit API delegates to the same validation/merge path as the original void method.
- `game/tests/world/test_chunk_persistence.gd`, `fixtures/persistent_projection.gd` — worker's 51 behavioral checks plus Main Agent's three explicit destroyed-record characterization checks (54 final); copied state, stale writes, boundary save, atomic failure and callback/re-entry coverage.
- `game/tests/persistence/test_registry.gd`, `game/tests/world/test_manifest.gd`, `game/tests/world/test_chunk_loader.gd` — checked commit, authored descriptor and loader lifecycle regressions.
- `game/tests/scenes/chunk_persistence.{gd,tscn}`, `game/tests/world/fixtures/persistence_visual.gd` — test-only end-to-end fixture with two temporary chunks, generic door/loot/NPC projections, real SnapshotAdapters/SaveStore, reverse-order reload and overview captures. Temporary scenes/save slots use PID-specific user-data paths and are cleaned after the run.
- `game/tests/run_tests.gd` — register `chunk_persistence` focused and in `all`.
- `docs/state-contracts.md`, `docs/world-contracts.md`, `docs/briefs/WORLD-03.md`, `docs/tasks/world-scene-manager.md`, `docs/master-progress.md` — contracts, pre-recorded scope, evidence/acceptance and next task. Report/review/evidence added under `docs/reports/` and `docs/evidence/WORLD-03/`. Import generated `.uid` metadata for new scripts.

## Tests run
All commands ran from repository root with Godot 4.7.2; no installations or model downloads. [Exact command/exit manifest](../evidence/WORLD-03/verification.json). Final driver `python3 /private/tmp/cyberpunk-world03-verify.py` exited 0.

| Exact command | Exit | Observed result |
| --- | --- | --- |
| `godot --headless --path game --editor --import` | 0 | Clean import; [log](../evidence/WORLD-03/import.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite sample` | 0 | 2/2 |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite registry` | 0 | 44/44 |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite world_manifest` | 0 | 45/45 |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite chunk_loader` | 0 | 49/49 |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite chunk_persistence` | 0 | 54/54; [log](../evidence/WORLD-03/chunk_persistence.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | 258/258; [log](../evidence/WORLD-03/all.log) |
| `godot --headless --path game res://tests/scenes/chunk_persistence.tscn` | 0 | 12 end-to-end checks; [log](../evidence/WORLD-03/runtime.log), [data](../evidence/WORLD-03/runtime-headless.json) |
| `/opt/homebrew/bin/python3.12 /Users/rukithnayak/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py game --json` | 0 | 66 files, zero errors/warnings; [output](../evidence/WORLD-03/scene-references.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite world03_unknown` | 2 | Expected unknown-suite rejection |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite` | 2 | Expected malformed arguments |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite deliberate_failure` | 1 | Expected intentional failure; excluded from all |

Regression-first evidence, using the same focused command as above:
- Registry: 40 checks/one missing checked-commit failure, exit 1 ([red](../evidence/WORLD-03/registry-red.log)); 44/44 after implementation ([green](../evidence/WORLD-03/registry-green.log)).
- Manifest: 45 checks/eight behavioral failures, exit 1 ([red](../evidence/WORLD-03/manifest-red.log)); 45/45 after implementation ([green](../evidence/WORLD-03/manifest-green.log)).
- Loader: first 43 checks/one missing protocol failure; added an argument-only interface stub so actual lifecycle expectations could run: 49 checks/five behavioral failures, exit 1 ([red](../evidence/WORLD-03/loader-hooks-red.log)); full hooks passed 49/49 ([green](../evidence/WORLD-03/loader-hooks-green.log)).
- Hydrator: behavior-first API shell ran 35 checks/20 failures, exit 1 ([red](../evidence/WORLD-03/hydrator-red.log)); implementation passed 35/35. Callback reentrancy fixes were separately reproduced red before correction: combined replay 51/five failures and retained-root replay 51/one failure, both exit 1; worker final green51. Main then added three characterization assertions for the already implemented destroyed-tombstone path; final54 passed without production changes. See review report for retained artifacts; intermediate 47-check/two-failure log is retained as diagnostic history, not mislabeled final evidence.
- First standalone runtime attempt preceded import of the new global EntityHydrator type; it logged a missing-type parse error and was explicitly terminated (exit 143). Headless import resolved class registration. First rendered run passed but reported a fixture parameter shadowing `Node.name`; renamed that local parameter. Final import/focused/all/runtime/MCP logs contain no script/engine errors or leaks. Expected registry rejection warnings remain in negative tests.
- `git diff --check` passes after report/tracker formatting review. Main inspected tracked diff and new source/fixtures; no unrelated asset/player partial work was modified.

## MCP and visual evidence
- Godot MCP verified engine 4.7.2 and created the runtime scene. `run_project`, `get_debug_output`, and `stop_project` exercised the fixture. Final debug output has 14 passing checks (12 lifecycle/save checks and two capture checks), zero errors/warnings. [Raw MCP result](../evidence/WORLD-03/godot-mcp-runtime.json), [rendered data](../evidence/WORLD-03/runtime-rendered.json). MCP does not expose a shell process exit code for these calls; none is claimed.
- Main Agent inspected [before](../evidence/WORLD-03/before-changes.png) and [after restore](../evidence/WORLD-03/after-restore.png): locked door/red and loot/yellow initially; unlocked door/green, no loot projection and restored NPC/cyan afterward. These are generic greybox state projections, not production art or gameplay acceptance. Renderer: Compatibility, 960×540, Apple M5/macOS.
- No Blender authoring was required for persistence logic; preserved editable assets/exporter and current Blender scene. Godot MCP was used where the runtime/scene work required it.

## Results
- Hydration completes before `_ready` and before interactions enable. Whole-chunk target/data validation rejects bad bindings before partial default registration; existing records and unknown fields win over authored defaults.
- Door unlock, collected/destroyed tombstones and NPC data persist across actual chunk teardown, reverse-order reload and a real save/restore with no runtime scenes present. Registry retains data-only records and stable UUIDs; only transient hydrator bindings contain Nodes.
- Accepted mutation is immediately authoritative. A boundary save therefore captures the latest values before unload; no Node scraping or secondary pending truth store is required.
- Pre-unload revokes old bindings and emits generation-tagged invalidation; stale loader generations and stale interaction deltas cannot revive retired state. Reentrant cleanup preserves newer replacement/retained-root bindings and cannot re-enable a tombstone.
- WORLD-03 accepted; world Stage 0/1 count is 3/6. Full module/overall Stage 1 gates remain incomplete.

## Risks / unrun gates
- Projection callbacks are authored, synchronous consumers of data copies; future gameplay modules must supply their own permission/precondition validation and must preserve hydrated state in `_ready`. No door/NPC AI, reward, inventory or mission gameplay is implemented here.
- Checkpoint orchestration across real gameplay domains (CORE-05), navigation handoff and sustained memory/frame/latency/human-playtest acceptance remain later gates. Small greybox runtime success does not establish those results.
- No WORLD-03 blocker or deferred minor finding remains.

## Follow-up tasks
- Next eligible: WORLD-04 — safe interior fades, consuming accepted WORLD-03 and preserving exterior streaming. Record its bounded interfaces/ownership before implementation.
- ASSET-03 and PLAYER-01 partial handoffs remain preserved and unaccepted. Changes are uncommitted; no publication step was part of this implementation task.
