## Task
- ID/title: WORLD-02 — Add asynchronous preload and bounded activation; Stage 1.
- Status: complete; Main Agent accepted 23 October 2026 (Asia/Kolkata).
- Owner/model: Main Agent / session model; bounded read-only reviewer `world02_review`, gpt-6-luna / medium. [Review](WORLD-02-review.md).
- Change reference: uncommitted working tree on `codex/stage-0-readiness`; repository has no commits. All prior source/asset/player changes preserved.

## Execution ledger and scope
- [x] Read AGENTS, prompt, tracker, approved design, owning task/prerequisites, actual source/tests and historical worker report; reproduced baseline 33/33.
- [x] Record supporting runtime fixture/runner/contract work in owning WORLD-02 task before coding. No hydration, production controller, navigation, asset production or Stage 2–5 work added.
- [x] Preserve starting copies at `/private/tmp/cyberpunk-world02-before/`; review actual session diff rather than empty Git diff. [Session diff](../evidence/WORLD-02/session.diff).
- [x] Reproduce callback/reentrant-budget failures before fix; test real native retry/cancellation before token cleanup fix.
- [x] Verify real physics and rendered captures through Godot MCP; final reviewer returned no blocking finding; run required integrated checks.
- [x] Update task acceptance, module count, tooling activation and next task in tracker.
- Ruling: continue in supplied root/unborn branch, retaining all untracked work. Commit-range/worktree workflow scripts cannot describe this handoff; use durable reports plus preserved starting-file comparison. Cost: there is no committed integration baseline. No unrelated files were staged and no initial commit created.

## Files changed
- `game/world/chunk_loader.gd` — validate activation after scene entry and manager callbacks; retire stale instances; guard recursive pumps; coalesce native load tokens and drain completed unused resources without waiting on in-progress work.
- `game/tests/world/test_chunk_loader.gd` — nine additional assertions covering callback invalidation, retained generations, recursive budget, real retry coalescing and canceled engine-token cleanup (33→42 checks).
- `game/tests/world/fixtures/activation_redirect.gd` — test-only scene-ready generation invalidation fixture.
- `game/tests/scenes/chunk_streaming.gd`, `.tscn` — actual capsule collision/support test over real threaded resources with delayed/failed neighbor status. Godot MCP created the base scene; script adds automated traversal and overview captures.
- `game/tests/run_tests.gd` — register accepted chunk-loader coverage in `all`; list existing suite names in argument help.
- `docs/world-contracts.md` — synchronous-callback checks, native-token ownership/cleanup and runtime fixture contract.
- `docs/tasks/world-scene-manager.md`, `docs/master-progress.md` — scope/acceptance, world count 2/6, historical handoff reconciliation and next eligible task.
- `docs/tasks/tooling-connections.md`, `docs/reports/TOOL-01.md` — record that native Blender tools are now active and verified.
- `docs/reports/WORLD-02*.md`, `docs/evidence/WORLD-02/` — current report/review and raw test/MCP/visual evidence. Historical `WORLD-02-worker.md` remains unchanged. Import generated normal `.uid`/cache metadata for new scripts.

## Tests run
Working directory: repository root. Final runs used approved macOS user-data access (required by native save fixtures). [Exact command/exit manifest](../evidence/WORLD-02/verification.json). `python3 /private/tmp/cyberpunk-world02-verify.py` driver exited 0.

| Exact command | Exit | Observed result |
| --- | --- | --- |
| `godot --headless --path game --editor --import` | 0 | Clean import; [log](../evidence/WORLD-02/import.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite sample` | 0 | 2/2; [log](../evidence/WORLD-02/sample.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite chunk_loader` | 0 | 42/42; [log](../evidence/WORLD-02/chunk_loader.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | 184/184; prior 142 plus accepted loader's 42; [log](../evidence/WORLD-02/all.log) |
| `godot --headless --path game res://tests/scenes/chunk_streaming.tscn` | 0 | Seven real physics checks; [log](../evidence/WORLD-02/physics.log), [data](../evidence/WORLD-02/runtime-headless.json) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite world02_unknown` | 2 | Expected unknown-suite rejection |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite` | 2 | Expected malformed-argument rejection |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite deliberate_failure` | 1 | Expected intentional failure; excluded from all |
| `/opt/homebrew/bin/python3.12 /Users/rukithnayak/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py game --json` | 0 | 55 files checked, zero errors/warnings; [data](../evidence/WORLD-02/scene-references.json) |

Red/green evidence:
- Baseline: `godot --headless --path game --log-file /private/tmp/world02-baseline-engine.log --script res://tests/run_tests.gd -- --suite chunk_loader` — exit 0; 33/33, [log](../evidence/WORLD-02/baseline.log).
- Initial callback red runs: `/private/tmp/world02-red-engine.log` and `/private/tmp/world02-red2-engine.log` versions of that command — exit 1, four then six failing assertions. The first fix run left two failures because the scene-ready test ran before the SceneTree root was ready; two test lambdas also retained RefCounted managers. Corrected the fixture to await tree readiness and use noncapturing method callables. These intermediate outputs remain in evidence; they are not acceptance evidence.
- Replayed the original loader bytes from the preserved baseline with corrected tests, restoring current implementation in `finally`. Exact child command: `godot --headless --path game --log-file /private/tmp/world02-red-replay-engine.log --script res://tests/run_tests.gd -- --suite chunk_loader` — exit 1, 40 checks/six expected failures, [log](../evidence/WORLD-02/red-callbacks-corrected.log). Fixed command using `/private/tmp/world02-green2-engine.log` — exit 0, 40/40, [log](../evidence/WORLD-02/green-callbacks-corrected.log).
- Physical fixture first passed seven checks but leaked one RefCounted engine token on exit. `godot --headless --verbose --path game --log-file /private/tmp/world02-physics-verbose-engine.log res://tests/scenes/chunk_streaming.tscn` — exit 0; verbose output traced a duplicate native threaded request during retry. [Diagnostic log](../evidence/WORLD-02/physics-verbose.log).
- New native-token regressions: `godot --headless --path game --log-file /private/tmp/world02-red-native2-engine.log --script res://tests/run_tests.gd -- --suite chunk_loader` — exit 1, 42 checks/two expected failures, [log](../evidence/WORLD-02/red-native-cleanup.log). Fixed command using `/private/tmp/world02-green3-engine.log` — exit 0, 42/42, [log](../evidence/WORLD-02/green-native.log). Final focused/integrated/physics logs have no leak or engine/script errors. Existing registry rejection warnings are expected in all. Earlier sandboxed runs emitted the known macOS CA certificate warning; final approved runs did not.
- `git diff --check` — exit 0; ordinary Git diff excludes these untracked sources. Main Agent reviewed the actual preserved-baseline comparison and new fixtures; no unrelated source edits.

## Runtime / MCP evidence
- Godot MCP `get_godot_version` and `get_project_info` confirmed 4.7.2. `create_scene` created `tests/scenes/chunk_streaming.tscn`; `run_project` launched that scene; `get_debug_output` reported ten passing checks and zero errors. `stop_project` stopped only the fixture process. MCP does not return a shell exit code for these calls; no exit was invented. [Captured MCP output](../evidence/WORLD-02/godot-mcp-runtime.json).
- Rendered run: macOS, Apple M5, OpenGL/GL Compatibility, 960×540; seven traversal checks plus three saved-image checks, about 6.15s scenario duration. [Data](../evidence/WORLD-02/runtime-rendered.json). This duration is a test scenario, not a sustained performance measurement.
- Main Agent visually inspected the overview captures: [blocked seam](../evidence/WORLD-02/blocked-seam.png) shows the capsule held at x=-0.35m over the existing floor; [crossed seam](../evidence/WORLD-02/crossed-seam.png) shows destination floor/capsule at x=2.41m after retry and old-floor unload; [return](../evidence/WORLD-02/returned-seam.png) shows safe backtracking onto reloaded A. The collision wall is intentionally invisible; physical assertions establish its collision behavior.
- Native Blender MCP `execute_blender_code` ran the Blender core environment report read-only: 5.2.3 LTS, EEVEE, one mesh/light/camera, scene file/dirty state/object count preserved. [Result](../evidence/WORLD-02/blender-mcp-probe.json). TOOL-01's prior native-activation limitation is resolved; no asset acceptance or Blender edits occurred.

## Results
- Asynchronous polling, delayed/out-of-order/missing/timeout behavior, explicit retries, desired/generation invalidation, bounded recursive activation and one scene per chunk are verified in focused tests.
- Actual body collision/support confirms no fall-through in the two-chunk unavailable-neighbor, failure/retry, crossing and backtracking scenario. Real threaded-load tests demonstrate advancing process frames; they do not establish cold-load latency for large content.
- Both WORLD-02 prerequisites are accepted. WORLD-03 is now eligible with WORLD-02 and CORE-04. Full world-module/Stage 1 gates remain unchecked.

## Risks / unrun gates
- A single scene instantiation is indivisible; activation count is bounded, not measured maximum milliseconds. Large-content frame-time/memory headroom, concurrent inference, teardown of long-running engine jobs and human playtest remain WORLD-06 gates, not claimed here.
- Fixture controls neighbor status for reproducibility; it is not a real missing-file/timeout hardware failure measurement. Those error paths are exercised in focused injected tests.
- Navigation handoff, entity hydration, final art quality and the production player controller are not accepted by this task. No remaining WORLD-02 blocker; no deferred minor review findings.

## Follow-up tasks
- Next eligible: WORLD-03 — hydrate/unload persistent entities using CORE-04 and the accepted lifecycle. Record bounded ownership before implementation.
- ASSET-03 and PLAYER-01 partial sources remain untouched; use native Blender/Godot MCP when those tasks need them. CORE-05 still awaits its gameplay prerequisites.
