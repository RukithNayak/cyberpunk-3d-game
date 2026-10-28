# TOOL-01 — Repair Codex connection to Blender Lab MCP

Stage 0 supporting tooling; explicitly requested by the user after CORE-04 acceptance.

- [x] Complete. Saved connection and native tool activation both verified; current session exposes Blender MCP tools.
- Owner: Main Agent; no delegation.
- Scope: verify the existing local Blender Lab server and add-on, provision an isolated Python environment if required, back up and correct only the Blender entry in user Codex configuration, and verify MCP initialize/tool discovery plus a read-only live Blender call. No scene edits or gameplay scope changes.
- Current evidence: Blender listens on 127.0.0.1:9876. The earlier HTTP configuration has already been replaced externally with `python3 -m blmcp` and PYTHONPATH `/Users/rukithnayak/blender_mcp/mcp`. Preserve that source checkout and all other configuration entries. That command currently exits 1 with `ModuleNotFoundError: No module named 'mcp'`; system Python is 3.9, while the server requires >=3.10.
- Acceptance: persistent STDIO launch uses a suitable interpreter and required dependencies; end-to-end MCP handshake and scene query succeed; configuration backup and exact verification evidence recorded. Distinguish a successful standalone connection from tools loading into this already-running Codex session.
- Ownership: `~/.codex/config.toml` Blender section only; isolated environment under `~/.codex/mcp-envs/blender-lab/`; this task/report and tracker. External writes require sandbox escalation. User's connection repair request authorizes necessary setup; no unrelated dependency/model installation.
- Result: installed the local official Blender Lab server in a dedicated Python 3.12 environment, backed up/replaced only its Codex entry, and verified 26 tools plus a live Blender 5.2.3 environment query through the saved configuration. Scene file/dirty state and object/mesh/material counts unchanged. See [report](../reports/TOOL-01.md).
- Activation follow-up, 23 October 2026: native `mcp__blender__execute_blender_code` succeeded during WORLD-02 verification, reporting Blender 5.2.3 LTS with the scene preserved. [Evidence](../evidence/WORLD-02/blender-mcp-probe.json). The prior daemon reload attempt timed out before sending a reload; the subsequent session now has the repaired native connection. No further setup action is pending.
