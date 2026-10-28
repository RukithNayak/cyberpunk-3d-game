#!/usr/bin/env python3
"""Run one local Ollama streaming request and record host/model process metadata.

Run from the repository root while the Godot feasibility scene is open:
    python3 benchmarks/feasibility/model_probe.py
"""

from __future__ import annotations

import json
import platform
import subprocess
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODEL = "llama3:willowbrook"
ENDPOINT = "http://127.0.0.1:11434"
PROMPT = "Use only this fact: a signal cache was stashed beneath the transit underpass. State what is beneath the underpass in one short sentence."


def command(args: list[str]) -> str:
    try:
        return subprocess.run(args, check=False, capture_output=True, text=True, timeout=8).stdout.strip()
    except (OSError, subprocess.TimeoutExpired) as error:
        return f"unavailable: {error}"


def get_json(path: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(
        ENDPOINT + path,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.load(response)


def process_rows() -> list[dict]:
    rows: list[dict] = []
    output = command(["ps", "-axo", "pid=,rss=,command="])
    for line in output.splitlines():
        fields = line.strip().split(None, 2)
        if len(fields) != 3:
            continue
        pid, rss_kb, process_command = fields
        name = Path(process_command.split()[0]).name if process_command.split() else "unknown"
        name_lower = name.lower()
        if "godot" in name_lower or "ollama" in name_lower or "llama-server" in name_lower:
            rows.append({"pid": int(pid), "process": name, "rss_kb": int(rss_kb)})
    return rows


def probe() -> dict:
    show = get_json("/api/show", {"model": MODEL})
    tags = get_json("/api/tags")
    model_rows = [row for row in tags.get("models", []) if row.get("name") == MODEL]
    started = time.perf_counter_ns()
    first_content_ms: float | None = None
    full_content = ""
    final: dict = {}
    request = urllib.request.Request(
        ENDPOINT + "/api/chat",
        data=json.dumps({
            "model": MODEL,
            "stream": True,
            "messages": [
                {"role": "system", "content": "Answer in one concise sentence."},
                {"role": "user", "content": PROMPT},
            ],
        }).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        for line in response:
            if not line.strip():
                continue
            row = json.loads(line)
            content = row.get("message", {}).get("content", "")
            if content and first_content_ms is None:
                first_content_ms = (time.perf_counter_ns() - started) / 1e6
            full_content += content
            if row.get("done"):
                final = row
    full_response_ms = (time.perf_counter_ns() - started) / 1e6
    info = show.get("model_info", {})
    context_values = [value for key, value in info.items() if key.endswith(".context_length")]
    return {
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "mode": "local Ollama request while Godot feasibility scene is running; single sample",
        "host": {
            "os": platform.platform(),
            "macos": command(["sw_vers"]),
            "cpu": command(["sysctl", "-n", "machdep.cpu.brand_string"]),
            "memory_bytes": command(["sysctl", "-n", "hw.memsize"]),
        },
        "godot": {
            "version": command(["godot", "--version"]),
            "running_processes": [row for row in process_rows() if "godot" in row["process"].lower()],
        },
        "model": {
            "name": MODEL,
            "parameters": show.get("details", {}).get("parameter_size"),
            "quantization": show.get("details", {}).get("quantization_level"),
            "context_length_from_model_metadata": context_values,
            "installed_model_record": model_rows,
            "ollama_ps": command(["ollama", "ps"]),
            "ollama_processes": [row for row in process_rows() if "ollama" in row["process"].lower()],
            "model_runner_processes": [row for row in process_rows() if "llama-server" in row["process"].lower()],
        },
        "request": {
            "prompt": PROMPT,
            "first_content_ms": first_content_ms,
            "full_response_ms": full_response_ms,
            "prompt_tokens": final.get("prompt_eval_count"),
            "response_tokens": final.get("eval_count"),
            "response": full_content,
            "done_reason": final.get("done_reason"),
        },
    }


if __name__ == "__main__":
    output = probe()
    target = ROOT / "benchmarks" / "feasibility" / "concurrent_model_probe.json"
    target.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2))
    print(f"Wrote {target.relative_to(ROOT)}")
