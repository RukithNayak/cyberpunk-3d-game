# NPC-02 — Asynchronous Ollama lifecycle and fallback

**Status:** Accepted for offline/mock-backed Stage 1; live Ollama smoke check blocked by the local server being unavailable. 23 October 2026 (Asia/Kolkata).
**Owner:** Main Agent.
**Dependencies:** NPC-01 and CORE-01 accepted.

## Delivered

- Added `OllamaProvider`, a non-blocking Godot `HTTPRequest` adapter for `/api/chat`. It requires explicit model configuration, disables streaming, sends the NPC-01 JSON Schema, bounds the request and response body, and returns only the model's raw JSON content to the validator.
- Added `DialogueOrchestrator` with one in-flight request, a default limit of two queued requests, bounded prompts/context, and a configurable 15-second default deadline. Offline transport rejection, HTTP error/malformed envelope, timeout, and invalid model JSON route to authored fallback once.
- Cancellation, conversation replacement and node unload invalidate request generations and clear queued work before cancelling transport, so even synchronous or late callbacks cannot publish stale dialogue. Duplicate/mismatched replies are ignored. Provider proposals remain inert.
- Preserved both `MockDialogueProvider` input forms: NPC-01 direct context payload and NPC-02 `{context, prompt}` payload.
- Added and registered `dialogue_requests`, covering queue and timeout defaults, asynchronous submission, serialization, timeout/offline/invalid-output fallback, queue saturation, 4xx/5xx/malformed HTTP envelopes, model switching while idle vs active, cancellation/replacement, stale and duplicate results.

## Verification

- Regression first: `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_requests` initially exposed the fallback dictionary alias bug (exit 1; timeout/offline fallback failed). After the copy-before-clear fix, the focused suite passed 23/23 (exit 0).
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_schema` — 44 cases, 0 failures, exit 0. This caught and verified repair of the NPC-01 direct-payload compatibility regression during integration.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` — 910 cases, 0 failures, exit 0. Existing shutdown warnings remain: one ObjectDB instance and one `GodotBody3D` RID leak.
- `godot --headless --path game --editor --import` — exit 0.
- `git diff --check` — exit 0.
- `curl --silent --show-error --max-time 2 http://127.0.0.1:11434/api/tags` — exit 7, connection refused. Consequently no live model request was run; no model was downloaded or installed.

No Blender or Godot MCP visual check applies to this logic-only task. Headless tests validate simulated HTTP response handling but do not prove live Ollama availability or model response quality.

## Next

NPC-03 — deterministic mission offers and lifecycle — is the next dependency-ready task. NPC-04 remains gated on NPC-02 and NPC-03.
