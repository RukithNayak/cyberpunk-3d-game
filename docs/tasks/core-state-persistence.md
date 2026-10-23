# Core State & Persistence Registry Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Provide scene-independent authoritative state and recoverable versioned saves.

**Architecture:** Owns records, serialization and faction values. Gameplay modules own domain rules; registry records never retain scene nodes. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 1](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

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

### CORE-01: Verify runtime and establish the test harness

- [x] **CORE-01 — deliverable complete** (Stage 0).

**Dependencies / sequencing:** None. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `AGENTS.md`; `.gitignore`; `game/project.godot`; `game/tests/run_tests.gd`; `docs/toolchain.md`.

**Interfaces:** Provide `godot --headless --path game --script res://tests/run_tests.gd -- --suite <suite>`; suite failures and unknown suites exit nonzero.

- [x] **Acceptance:** Record actual Godot version against the approved 4.7.2 pin; locate Ollama and record health/model inventory without downloading weights. Record hardware/storage evidence or unavailable checks; scaffold typed GDScript and ignored caches/model weights. Document folder ownership and verification commands.

- [x] **Test expectations:** Run a passing sample suite, a deliberately failing fixture and an unknown suite; record their exit codes. Import the empty project headlessly and launch it on macOS. Do not treat historical environment observations as fresh verification.

- [x] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent; working tree. [Report](../reports/CORE-01.md), [exact commands/results](../toolchain.md). Focused independent review: gpt-6-luna / medium, compliant, no material findings. Sample/all 2/2; intentional failure exit 1; unknown exit 2; clean import/native launch exit 0. Ollama offline recorded, not a runtime-harness blocker.

### CORE-02: Define registry and stable-identity contracts

- [x] **CORE-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/persistence/entity_registry.gd`; `game/persistence/faction_state.gd`; `game/tests/persistence/test_registry.gd`; `docs/state-contracts.md`.

**Interfaces:** `register_entity(uuid: String, initial_state: Dictionary) -> void`; `commit_state_delta(uuid: String, delta: Dictionary) -> void`; `get_faction_standing(faction_id: String) -> int`. Add documented copy-returning state lookup and faction mutation contracts for consumers.

- [x] **Acceptance:** EntityState uses stable UUIDs independent of scene paths/load order. Duplicate registration warns and preserves existing state. Specify unknown-ID behavior, allowed serializable values, delta merge semantics and faction thresholds before consumers implement them; clamp standing to -100..100. Registry owns no Node references.

- [x] **Test expectations:** Assert duplicate registration preserves modified flags; mutating a returned copy cannot alter truth. Reject node-valued state, invalid UUIDs/deltas and unknown faction mutations as documented. Cover -100/100 bounds and each hostility threshold.

- [x] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

Accepted 23 October 2026 (Asia/Kolkata), registry worker gpt-6-luna medium; working tree. Main Agent reproduced registry 39/39 exit 0; independent reviewer found no material spec/quality issue. [Report](../reports/CORE-02-worker.md), [contracts](../state-contracts.md). Engineering choices: canonical lowercase UUIDs, JSON-like data, inclusive configurable -50/+50 thresholds (not balance approval).

### CORE-03: Implement atomic save and validated load

- [x] **CORE-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/persistence/save_store.gd`; `game/tests/persistence/test_save_store.gd`.

**Interfaces:** `save_to_disk(slot: int) -> Error`; define and document `load_from_disk(slot: int) -> Error` and a versioned snapshot envelope in docs/state-contracts.md.

- [x] **Acceptance:** Save player/entity/faction/domain records through temporary-write then replacement. Failed writes retain the last valid save. Fully validate a candidate snapshot before swapping live state; malformed, missing, unsupported future or invalid-slot saves fail without partial mutation.

- [x] **Test expectations:** Round-trip every supported value; simulate truncated data, missing file, invalid slot, permission/write failure and interrupted replacement. Verify prior save/live state remains usable and duplicate UUIDs cannot enter through loading.

- [x] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

Accepted 23 October 2026 (Asia/Kolkata), save_store worker/reviewer gpt-6-luna medium; Main Agent reproduced 23/23, exit 0. Working-tree branch codex/stage-0-readiness. [Report](../reports/CORE-03-worker.md), [save contract](../state-contracts.md). Same-directory atomic replacement, tagged int64/float64 codec and candidate validation verified; concrete domain integration remains CORE-04/05.

### CORE-04: Add idempotent migrations and domain snapshot adapters

- [x] **CORE-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/persistence/save_migrations.gd`; `game/persistence/snapshot_adapters.gd`; `game/tests/persistence/test_migrations.gd`.

**Interfaces:** Document adapter ownership and snapshot keys for player, inventory, missions, NPC memory and active hacks; adapters exchange data only, without importing domain scenes.

- [x] **Acceptance:** Provide one previous-schema fixture and ordered migrations; repeated migration gives the same current result. Preserve stable IDs and unknown recoverable records; reject unsafe migrations without overwriting source saves. Document timed-effect clock policy shared with HACK-05.

- [x] **Test expectations:** Migrate an older fixture twice and compare results; test missing migration step and unsupported future version. Reload saved records without any runtime scene instances.

- [x] **Evidence recorded:** [Main Agent acceptance report](../reports/CORE-04.md), [exact commands/exits](../evidence/CORE-04/verification.json), [red regression](../evidence/CORE-04/red-migrations.log), [focused green](../evidence/CORE-04/migrations.log), [integrated suite](../evidence/CORE-04/all.log), [session diff](../evidence/CORE-04/session.diff).

Accepted 23 October 2026 (Asia/Kolkata), Main Agent / session model; working tree on `codex/stage-0-readiness`. Existing worker implementation reviewed and retained. Migration false-success regression observed red (22 checks, one failure, exit 1), then green (22/22, exit 0); import/sample/all exit 0, integrated all 142/142. Unknown root extensions are explicitly owned or rejected before mutation; opaque records survive migration, recapture and explicit save. Timed-effect clock policy is published in [state contracts](../state-contracts.md). Review performed inline per user instruction; no independent reviewer claimed. CORE-05 still requires its gameplay prerequisites; WORLD-03 also requires WORLD-02 acceptance.

### CORE-05: Connect checkpoints to player and domain state

- [ ] **CORE-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-04, PLAYER-04, INV-04, NPC-05, HACK-05. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/persistence/checkpoint_controller.gd`; `game/tests/persistence/test_checkpoint.gd`; `game/tests/scenes/checkpoint_fixture.tscn`.

**Interfaces:** Consume player `on_death` and domain snapshot adapters; orchestrate restore after validated load, before control is returned.

- [ ] **Acceptance:** Death restores a coherent checkpoint containing health, equipment/ammo, missions, world flags, NPC facts and active-effect state. Missing/corrupt checkpoints fail with a recoverable user state. Reject save/load reentrancy and partial restore.

- [ ] **Test expectations:** Change each domain, die, restore and assert the checkpoint values together. Save, fully quit and relaunch fixture; verify no loot duplication, mission re-award or dead NPC resurrection beyond checkpoint policy.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### CORE-06: Exercise save compatibility for release

- [ ] **CORE-06 — deliverable complete** (Stage 2–5 (deferred)).

**Dependencies / sequencing:** CORE-05; release targets selected. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/tests/persistence/fixtures/`; `docs/save-compatibility.md`.

**Interfaces:** Extend the existing schema/migration interfaces; do not introduce a second save authority.

- [ ] **Acceptance:** Keep a fixture per shipped schema and document backup/recovery behavior on selected release platforms. Release work starts only after scope and targets are approved.

- [ ] **Test expectations:** Load all retained schema fixtures on packaged target builds; verify migration, clean install paths and failure recovery without data loss.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
