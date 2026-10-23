# NPC-01 — Response schema, context and mock provider

**Status:** Accepted, Stage 1. 23 October 2026 (Asia/Kolkata).
**Owner:** Main Agent.
**Dependency:** CORE-02 accepted. This task defines inert data contracts only; it does not connect HTTP or execute proposed actions.

## Delivered

- `ContextSnapshot` builds a bounded JSON projection of NPC identity, scoped facts, memory summary, eligible mission templates and faction standing. It validates canonical IDs/counts/lengths and contains no Node references.
- `ResponseValidator` parses strict JSON with exact root/action keys, type and size limits, the six detailed-design actions, and each action's exact parameter shape. Invalid output returns a reason without executing or mutating state.
- `LLMResponse` is a data-only wrapper for dialogue text and an inert action proposal.
- `DialogueProvider` defines completion events carrying NPC, conversation and request-generation IDs. `MockDialogueProvider` deterministically emits valid, delayed and malformed raw responses and has no game-state references.
- `test_schema.gd` covers bounded context, prompt-like text remaining inert, all six proposals, malformed/oversized/wrongly typed/unknown payloads, no registry/faction mutation, and provider metadata/delay/failure modes.

Engineering defaults are documented in the task contract: 8 KiB JSON envelopes, 1,200-character dialogue and memory bounds, 32 facts/templates, 240-character fact strings, 80-character display names and lowercase stable IDs. These are configurable implementation limits, not narrative or gameplay balance.

## Verification

- `godot --headless --path game --editor --import` — exit 0.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_schema` — exit 0; 44 cases, 0 failures.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` — first attempt exit 1 because the existing isolated AI navigation fixture returned an empty path at map iteration 2 / region iteration 1; retry exit 0, 887 cases, 0 failures. The passing run retains the known ObjectDB and `GodotBody3D` RID shutdown warnings.
- `git diff --check` — exit 0.

No Godot MCP scene launch or Blender MCP call was needed: this deliverable has no scene, visual or Blender asset changes. Live Ollama integration remains NPC-02 scope; this mock-only task does not require a running inference server.

## Next

NPC-02 (asynchronous Ollama lifecycle and authored fallback) and NPC-03 (deterministic mission lifecycle) are now dependency-ready. NPC-02 is recommended next to continue the dialogue request path. Real-provider behavior remains subject to the existing Ollama availability blocker; mock-backed lifecycle work can proceed.
