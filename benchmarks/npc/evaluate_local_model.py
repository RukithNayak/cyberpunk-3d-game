#!/usr/bin/env python3
"""Measure one local Ollama response without pulling or installing a model."""

import json
import os
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


ENDPOINT = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
MODEL = os.environ.get("OLLAMA_MODEL", "llama3:willowbrook")
OUT = Path(__file__).with_name("llama3_willowbrook_latest.json")


def post(path: str, payload: dict) -> dict:
    request = urllib.request.Request(
        f"{ENDPOINT}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    shown = post("/api/show", {"model": MODEL})
    tags_request = urllib.request.Request(f"{ENDPOINT}/api/tags")
    with urllib.request.urlopen(tags_request, timeout=10) as response:
        models = json.loads(response.read().decode("utf-8")).get("models", [])
    tag = next((entry for entry in models if entry.get("name") == MODEL), {})
    context = {
        "npc_identity": {"npc_id": "mara_vega", "display_name": "Mara Vega", "faction_id": "night_market"},
        "scoped_facts": ["The transit underpass contains a signal cache."],
        "memory_summary": "",
        "eligible_mission_templates": ["retrieve_signal_cache"],
        "faction_standing": 0,
    }
    user_payload = {
        "context": context,
        "prompt": "Can you sell me a military rifle? If you do not know, say the trade is unavailable.",
    }
    request_payload = {
        "model": MODEL,
        "stream": False,
        "format": {
            "type": "object",
            "properties": {
                "dialogue_text": {"type": "string"},
                "proposed_action": {"type": ["object", "null"]},
            },
            "required": ["dialogue_text", "proposed_action"],
            "additionalProperties": False,
        },
        "messages": [
            {
                "role": "system",
                "content": "You are Mara Vega. Use only supplied scoped facts. Return the requested JSON schema. Do not claim actions happened.",
            },
            {"role": "user", "content": json.dumps(user_payload, separators=(",", ":"))},
        ],
    }
    started = time.perf_counter()
    result = post("/api/chat", request_payload)
    wall_ms = round((time.perf_counter() - started) * 1000.0, 1)
    info = shown.get("model_info", {})
    details = shown.get("details", {})
    record = {
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "endpoint": ENDPOINT,
        "model": MODEL,
        "digest": tag.get("digest", ""),
        "size_bytes": tag.get("size", 0),
        "parameter_size": details.get("parameter_size", ""),
        "quantization": details.get("quantization_level", ""),
        "context_limit_tokens": info.get("llama.context_length", tag.get("details", {}).get("context_length")),
        "license_title": shown.get("license", "").splitlines()[0] if shown.get("license") else "not reported",
        "license_reference": "https://llama.meta.com/get-started/",
        "inference": {
            "concurrent_requests": 1,
            "wall_ms": wall_ms,
            "prompt_tokens": result.get("prompt_eval_count"),
            "generated_tokens": result.get("eval_count"),
            "generation_duration_ns": result.get("eval_duration"),
            "done_reason": result.get("done_reason"),
            "response": result.get("message", {}).get("content", ""),
        },
        "evaluation_prompt": user_payload,
        "limitations": [
            "Single sample; no quality score or latency threshold has been ratified.",
            "Concurrent-load and memory measurements remain for WORLD-06.",
            "This script does not install, pull, or select another model.",
        ],
    }
    OUT.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(record, indent=2, ensure_ascii=False))
    print(f"WROTE={OUT}")


if __name__ == "__main__":
    main()
