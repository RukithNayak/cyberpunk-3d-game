## Task
- ID and title: CORE-04 — Add idempotent migrations and domain snapshot adapters.
- Status: complete; accepted by Main Agent on 23 October 2026 (Asia/Kolkata).
- Owner: Main Agent / current session model; no subagents dispatched. Historical worker report does not verify its model metadata.
- Change reference: uncommitted working tree on `codex/stage-0-readiness`; repository has no commits.

## Execution plan and rulings
- Scope: existing CORE-04 acceptance and previously authorized SaveStore/registry/faction integration. Rejected migrations must return a failure to the caller as well as preserve bytes/live owners. This is a correction within CORE-04, not new gameplay scope.
- [x] Read owning task, accepted CORE-03 prerequisite, contracts, actual persistence files and worker report; reconcile other partial handoffs in tracker.
- [x] Preserve starting copies of ten task/shared files at `/private/tmp/cyberpunk-core04-resume-before/` for session diff review. All repository files are untracked, so ordinary `git diff` cannot show their changes.
- [x] Add a regression for a rejected migration whose reported error is OK; observe behavioral failure before changing production code.
- [x] Correct the failure result; rerun focused migration checks; integrate accepted migration coverage into `all`.
- [x] Review actual session diff and acceptance coverage; run required import, sample, focused and integrated verification; record evidence and acceptance.
- Pre-flight: CORE-03 SaveStore consumes CORE-04 migration results and adapter callbacks; registry/faction retain sole ownership and provide prepared replacement APIs. Unknown root extensions already have optional owner callbacks in the handed-off implementation/tests, but the contract prose does not describe them yet. Document them without adding another state owner. Actual gameplay participants remain future tasks.
- Ruling: work in the supplied repository root as explicitly requested. Git has no initial commit; commit-range/worktree execution scripts cannot represent this handoff. Use this durable report/ledger and preserved starting copies instead; do not create an initial commit or stage unrelated files. Review is by Main Agent because the user prohibits delegation. Cost: session diffs depend on the preserved starting copies; no independent reviewer is claimed.

## Files changed
- `game/persistence/save_store.gd` — reject a migration's contradictory `ok: false, error: OK` result with a nonzero load error.
- `game/tests/persistence/test_migrations.gd` — add the observed false-success regression; verify failure return and unchanged live/source data.
- `game/tests/run_tests.gd` — include the accepted migration suite in `all`; unaccepted chunk-loader and controller suites remain separate.
- `docs/state-contracts.md` — document existing optional root-extension ownership and migration failure behavior. Existing adapter, migration, registry and faction implementations were reviewed and retained unchanged.
- `docs/tasks/core-state-persistence.md`, `docs/master-progress.md` — accept CORE-04, update count/evidence, remove stale active assignments, and record remaining dependencies/next task.
- `docs/reports/CORE-04.md`, `docs/evidence/CORE-04/` — this report, red/green outputs, final verification logs/manifest and session diff. Historical worker report remains unchanged.
- Required Godot import also generated normal import metadata/cache and extracted embedded texture PNGs under `game/assets/reference/`. Existing GLBs, authored maps, metadata, exporter and editable Blender sources were not edited. These import artifacts do not establish ASSET-03 visual or repeatability acceptance.

## Tests run
- Repository root: `godot --headless --path game --log-file /private/tmp/core04-baseline-engine.log --script res://tests/run_tests.gd -- --suite migrations` — exit 0; 21 checks, zero failures. Sandboxed macOS CA certificate warning observed; no save filesystem access required by this suite. This is current verification, distinct from the worker's historical 18 checks.
- Red: `godot --headless --path game --log-file /private/tmp/core04-red-engine.log --script res://tests/run_tests.gd -- --suite migrations > docs/evidence/CORE-04/red-migrations.log 2>&1` — exit 1; 22 checks, one expected failure. Root cause: the rejected-migration branch propagated an integer error without excluding OK. The new behavioral assertion detects false success; existing checks passed. [Full output](../evidence/CORE-04/red-migrations.log).
- First green: `godot --headless --path game --log-file /private/tmp/core04-green-engine.log --script res://tests/run_tests.gd -- --suite migrations > docs/evidence/CORE-04/green-migrations.log 2>&1` — exit 0; 22/22. Same unrelated sandbox CA warning; expected regression now passes. [Output](../evidence/CORE-04/green-migrations.log).
- Final verification ran from repository root with approved normal macOS user-data access via `/private/tmp/cyberpunk-core04-verify.py` (driver exit 0). The driver executed the exact commands below and retained combined stdout/stderr and individual exits in [verification.json](../evidence/CORE-04/verification.json):

| Exact command | Exit | Observed result / evidence |
| --- | --- | --- |
| `godot --headless --path game --editor --import` | 0 | Clean script/asset import; [output](../evidence/CORE-04/import.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite sample` | 0 | 2 checks, zero failures; [output](../evidence/CORE-04/sample.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite migrations` | 0 | 22 checks, zero failures; [output](../evidence/CORE-04/migrations.log) |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | 142 checks, zero failures; includes registry 39, health 19, saves 23, world manifest 37, sample 2 and migrations 22; [output](../evidence/CORE-04/all.log) |

- Final logs contain no script errors, engine errors or leak warnings. `all` contains expected EntityRegistry rejection/duplicate warnings from existing negative tests. Runtime banner is Godot 4.7.2.
- `git diff --check` — exit 0, but all source files are untracked, so it alone does not validate this session's edits. Reviewed the actual comparison against preserved starting files in [session.diff](../evidence/CORE-04/session.diff); no unrelated source edits in that comparison. New report/evidence files reviewed directly.
- Not run: visual, performance, real gameplay-owner integration, packaged builds and human playtests; none is an acceptance requirement of CORE-04. WORLD-02/ASSET-03/player acceptance checks were not substituted for this task's checks.

## Results
- Previous-schema fixture: `_v0_fixture()` uses `domain_records`; ordered v0→v1 migration preserves the canonical UUID and opaque root/domain records, and repeated old/current migration yields identical snapshots. Missing step and future version reject. No runtime scene instance is needed for load/restore.
- Failure safety: unsafe migration and participant preparation failures preserve source bytes/live owners. Successful old-schema load also leaves the source untouched; explicit save retains unknown records. New contradictory migration result now returns a failure rather than false success (observed red→green).
- Ownership: registry/factions remain authoritative; player/domain/extension fixture callbacks prepare all data before synchronous commit. Candidates with unknown root data reject if no extension owner is configured; configured owners preserve it through recapture and save. No persistent Node references or domain scene imports were introduced.
- Clock policy: `docs/state-contracts.md` documents remaining durations advancing only on the active, unpaused simulation clock and pausing while unloaded/offline; this engineering default is shared with HACK-05 and is not balance approval.
- Review: Main Agent separately reviewed the inherited migration/adapter implementations, SaveStore integration, registry/faction preparation APIs, test coverage and actual session diff against the owning acceptance criteria. The false-success issue was fixed with an observed failing regression. No remaining blocking or minor review findings. This is self-review per the user's no-delegation instruction; no independent review or merge is claimed.
- CORE-04 accepted; module count is 4/5 Stage 0/1 tasks. Overall module and Stage 0/1 milestone gates remain unchecked.
- Handoff reconciliation: WORLD-02 has implementation/tests/report awaiting validation; ASSET-03 has exporter/generated assets but lacks fixture/report; PLAYER-01 has a test but no controller/fixture implementation. None has a live worker in this session. Their source files remain untouched.
- Blender MCP inventory: filtering the available tool names/descriptions for Blender returned zero entries. No Blender work, installation or configuration changes are needed for this persistence task.

## Risks
- Actual gameplay-domain participants must honor pure prepare and silent/infallible commit contracts; current player/domain/extension owners are data fixtures.

## Follow-up tasks
- Next eligible task: WORLD-02 review/validation; implementation, focused tests and historical report already exist. No active assignment left at this handoff.
- WORLD-03 remains blocked until WORLD-02 is accepted; its CORE-04 dependency is now satisfied.
- CORE-05 remains blocked by PLAYER-04, INV-04, NPC-05 and HACK-05. Integrate real gameplay participants in their owning tasks and CORE-05, preserving prepare/commit/opaque-data contracts.
- ASSET-03 remains eligible partial work; verify the available local Blender 5.2.3 executable when resuming it, then complete repeatability/visual evidence with the required Blender skills. No MCP configuration or software installation was attempted.
