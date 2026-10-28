# NPC-05 — Scoped NPC knowledge and bounded memory

**Status:** Accepted, Stage 1
**Date:** 23 October 2026 (Asia/Kolkata)
**Owner:** Main Agent
**Commit:** `fdf8ae0` (`Persist scoped NPC dialogue memory`)
**Scope:** Data-only NPC memory, dialogue-domain persistence/projection, focused tests, and coordinated test-runner registration.

## Implementation

- Added `NpcMemory`, keyed by stable NPC IDs and storing authored fact references with their `witnessed`/`disclosed` provenance and stable evidence IDs.
- Fact commits require a game-owned evidence authorization callback returning boolean true. Model text, transcript lines, and derived summaries do not enter the fact catalog or mutate mission/faction state.
- Recent dialogue lines and derived summaries are stored separately from verified facts. Per-NPC history caps at 32 lines; each line is capped at 500 characters and summaries at 1,200 characters. Fact count caps at 32 per NPC and NPC records at 64.
- Added `DialogueSnapshot` as a CORE-04 domain callback owner for `npc_memory` and existing `missions`. It builds the existing `ContextSnapshot` from authored verified fact text, current `FactionState` standing, and a caller-supplied game-validated eligible-template list.
- Domain capture/prepare/commit uses copies and no gameplay callbacks. Unknown domain records are preserved opaquely; history restoration never replays fact authorization, rewards, or faction actions.

## Verification

Commands ran from the repository root with Godot 4.7.2:

| Command | Result |
| --- | --- |
| `godot --headless --path game --editor --import` | Exit 0; classes registered and imports completed. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_memory` | Exit 0; 30 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | Exit 0; 1,022 cases, 0 failures. One ObjectDB instance and one `GodotBody3D` RID were reported leaked at shutdown. |
| `git diff --check` | Exit 0. |

Regression-first evidence: before implementation, the focused suite failed because `npc_memory.gd` and `dialogue_snapshot.gd` were absent (1 case, exit 1). The final focused suite covers authorized/unauthorized evidence, hostile prompts, derived-summary isolation, history bounds, malformed and data-only snapshots, unknown-domain preservation, and an actual SaveStore disk reload into recreated memory, faction, and mission owners. The reloaded active mission and faction standing are retained; loading invokes no fact authorization or reward/action callback.

Ollama was not used for NPC-05: model inference is not required to establish these persistence and authority guarantees. The summary API treats any supplied summary as derived text. No visual or Blender evidence applies to this runtime logic task.
