# Local NPC model evaluation

**Date:** 23 October 2026 (Asia/Kolkata)  
**Task:** NPC-06  
**Environment:** local Ollama at `http://127.0.0.1:11434`; no model was installed or pulled.

## Model and license

- Existing tag: `llama3:willowbrook`, 8.0B parameters, GGUF Q4_0, 4,661,224,319 bytes.
- Digest: `f0b3ffc1f6aabddbd01767cb7d7ccd9ed4ce7354cf75f20b5ead4a8269c04d87`.
- Reported context limit: 8,192 tokens.
- `/api/show` reported **META LLAMA 3 COMMUNITY LICENSE AGREEMENT**. The installed model reports the Llama 3 documentation reference [from Meta](https://llama.meta.com/get-started/). Any distribution decision remains for NPC-07; this evaluation does not grant redistribution rights.
- Setup: start Ollama and run `python3 benchmarks/npc/evaluate_local_model.py`. The standard-library script only calls `/api/tags`, `/api/show`, and `/api/chat`; it never pulls a model. Set `OLLAMA_HOST` or `OLLAMA_MODEL` to point to another already-installed local endpoint/tag.

## Measured response

Reproduction command: `python3 benchmarks/npc/evaluate_local_model.py` — **exit 0**. The run used one request at a time, 120 prompt tokens and 18 generated tokens. Observed wall time was **3,485.3 ms**; the model reported 695,204,000 ns for generation. The exact response, request context, timestamp, model digest and token counts are in [the raw run record](../benchmarks/npc/llama3_willowbrook_latest.json).

The model answered “Trade is unavailable.” and returned no action for a request to sell an unlisted military rifle. This was a scoped, safe response in that sample. An earlier exploratory request from the same installed tag returned an unsupported `retrieve_signal_cache` action for that trade question ([raw response](../benchmarks/npc/exploratory_invalid_action.json)). The validator rejected that action and routed the request to authored fallback in the focused UI suite. This variation is a material quality limit: model proposals remain untrusted, and authored mission interactions must work without model output.

## Acceptance limits and follow-up

- Context scope is checked by the existing NPC schema/validator suites; the UI fixture also confirms an unsupported action is not displayed as a committed transaction.
- The demo UI uses the deterministic authored fallback when the provider is offline, the output is invalid, or the request times out. Trade is explained as unavailable when no authorized merchant stock/panel is configured.
- One response is not a quality score, reliability estimate, or approved latency threshold. Concurrent inference, memory use, repeatability, and load while rendering/combat are not measured here; WORLD-06 owns those integration measurements.
- Audio was verified structurally and by focused playback-state tests. Subjective listening and accessibility/user playtest remain outstanding.
- Raw evidence: [NPC-06 model run](../benchmarks/npc/llama3_willowbrook_latest.json), [UI capture](evidence/NPC-06/dialogue_initial.png), [NPC-06 report](reports/NPC-06.md).
