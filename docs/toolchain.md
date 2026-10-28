# Verified toolchain — 23 October 2026 (Asia/Kolkata)

All commands ran from the repository root unless noted. No installation or model download occurred.

| Check | Fresh result |
|---|---|
| `command -v godot` / `godot --version` | `/opt/homebrew/bin/godot`; `4.7.2.stable.official.ed1daf0bf`, exit 0, matches pin |
| `/Applications/Blender.app/Contents/MacOS/Blender --version` | 5.2.3 LTS, hash e13b728c6880, exit 0; 5.2 target family |
| `command -v ollama` / `ollama --version` | `/usr/local/bin/ollama`; client 0.40.8, exit 0 with no-server warning |
| `curl --max-time 5 -sS http://127.0.0.1:11434/api/tags` | exit 7, connection refused, including outside filesystem sandbox; provider unavailable |
| `uname -m`; `sw_vers` | arm64; macOS 26.5.1, build 25F80; exit 0 |
| `sysctl -n hw.memsize hw.model machdep.cpu.brand_string` | 17179869184 bytes (16 GiB), Mac17,3, Apple M5; exit 0 with approved sandbox escalation |
| `df -h .` | 460 GiB volume, 308 GiB available at inspection; exit 0 |

Read-only local manifest inventory under `~/.ollama/models/manifests/registry.ollama.ai/library/`:
`gemma3:12b-it-q4_K_M` (8,164,039,587 layer bytes), `llama3:latest`
(4,661,224,191), `llama3:willowbrook` (4,661,224,206),
`nomic-embed-text:latest` (274,302,030). These are on-disk manifest observations,
not live API availability, complete-blob verification, license approval or model suitability.
No model was loaded. Runtime-provider evaluation remains blocked until a server is reachable.

## Reproduction and observed exits

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/run_tests.gd -- --suite sample
godot --headless --path game --script res://tests/run_tests.gd -- --suite deliberate_failure
godot --headless --path game --script res://tests/run_tests.gd -- --suite missing
godot --headless --path game --script res://tests/run_tests.gd -- --suite all
godot --path game --quit-after 10
```

Import: exit 0. Sample: 2 cases, 0 failures, exit 0. Deliberate failure:
1 case, 1 expected failure, exit 1. Unknown suite: exit 2. All: 2 cases,
0 failures, exit 0 (intentional fixture excluded). Native macOS launch:
exit 0 after ten frames; OpenGL 4.1 Metal Compatibility on Apple M5.
The launch verifies startup only; no gameplay, human playtest or performance acceptance.
Compatibility rendering at 960×540 is a temporary smoke-test configuration,
not an approved production renderer/resolution or benchmark result.

The first sandboxed import exited 0 **with errors** creating user data and saving
editor settings in macOS Application Support. It is not the clean acceptance run.
The subsequent approved `godot` escalation imported without errors and all listed
Godot acceptance commands used normal macOS data access. Initial `sysctl` was denied
and repeated successfully with approved escalation. Git branch creation was denied
at `.git/HEAD.lock`; no commits/staging or existing source-document changes were discarded.

Asset smoke evidence is owned by ASSET-01; see [asset pipeline](asset-pipeline.md)
and its report when available. No export templates, packaged build, inference latency,
combined memory/thermal budget or frame-time acceptance has been verified here.

## ASSET-01 accepted evidence

Blender smoke export repeated successfully with approved escalation, 1,980-byte GLB; game-profile geometry QA passed (12 triangles, no errors/warnings). Godot GLTFDocument import exit 0 preserves 1 m Y-up bounds and assigned material. [Worker and integration report](reports/ASSET-01-worker.md), [contact sheet](evidence/ASSET-01-review.png). This supersedes earlier sandbox startup crashes and the first 1,648-byte pre-UV draft.
