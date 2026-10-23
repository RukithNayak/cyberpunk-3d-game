# NPC-04 — Guarded deterministic action dispatch

**Status:** Accepted, Stage 1
**Date:** 23 October 2026 (Asia/Kolkata)
**Owner:** Main Agent
**Scope:** `ActionDispatcher`, its focused regression suite, the coordinated test runner, and the adapter/permission policy.

## Implementation

- Revalidates exact NPC-01 response schema, active NPC/conversation identity, live actor, monotonic generation, and duplicate transaction before dispatch.
- Supports only the six specified actions: mission offers, merchant trade, faction admission, live NPC fight transition, fact disclosure, and entitled item grant.
- Requires game-owned adapters and allowlists. Unknown or unconfigured actions and IDs fail closed.
- Uses a stable transaction identifier for the conversation and request generation. Duplicate responses return cached results without repeating side effects.
- Routes items through `ItemGrants`; full inventories retain an idempotent pending entitlement for later retry.
- Documents each adapter and its commit-time authority in [NPC action policy](../npc-action-policy.md).

## Verification

Commands were run from the repository root with Godot 4.7.2:

| Command | Result |
| --- | --- |
| `godot --headless --path game --editor --import` | Exit 0; import completed. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_actions` | Exit 0; 41 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | Exit 0; 992 cases, 0 failures. One ObjectDB instance and one `GodotBody3D` RID were reported leaked at shutdown. |
| `git diff --check` | Exit 0. |

The suite was also observed failing before implementation: `ActionDispatcher` was absent, so `dialogue_actions` exited 1 on the availability regression. An intermediate focused run exposed the AI's expected requirement for a damageable combat target; the fixture was corrected to use a live damageable target and the final suite then passed. No visual or Blender evidence applies to this runtime logic task. The local Ollama provider was not exercised; it is outside NPC-04 acceptance.

## Evidence and limitations

Automated cases exercise authorized and rejected paths across all six actions, invented identifiers, stale merchant eligibility, stale generation and conversation, actor unload, exact-schema tampering, duplicate responses, live combat transition, and full-inventory retry. NPC-04 does not include live provider inference or a visual playtest.
