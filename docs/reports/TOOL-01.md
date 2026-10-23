## Task
- ID: TOOL-01 — Repair Codex connection to Blender Lab MCP.
- Status: complete; connection setup and subsequent native tool activation verified. See activation follow-up below.
- Owner: Main Agent / current session model; no delegation.
- Authorization: user explicitly requested connection repair and setup. No gameplay/asset scope expansion.

## Cause and changes
- Initial investigation found HTTP incorrectly pointed at Blender's raw TCP socket. On resuming this repair, that configuration had already been changed externally to `python3 -m blmcp` with a local-source PYTHONPATH. Preserved the source checkout and other settings.
- Reproduced startup failure: system `python3` is Python 3.9 and lacks the MCP package. Local server requires Python >=3.10. Observed `ModuleNotFoundError: No module named 'mcp'`, exit 1.
- Used existing Python 3.12.14 and uv to create `~/.codex/mcp-envs/blender-lab/`; installed the existing local official server package and its dependencies there. Source: `/Users/rukithnayak/blender_mcp/mcp`, official origin `https://projects.blender.org/lab/blender_mcp.git`, revision `dbbf836ad4b1025f14a2b3b504c43903f39e0b04`. Installed server package reports version 1.0.2; live add-on is 1.0.3 and interoperability was verified.
- Updated only `[mcp_servers.blender]` and its environment in `~/.codex/config.toml`: absolute dedicated launcher, explicit STDIO, host 127.0.0.1, port 9876, startup timeout 30s, tool timeout 120s. Parsed settings outside Blender were compared before/after and are identical.
- Configuration backup: `/Users/rukithnayak/.codex/config.toml.blender-backup-20261023-152455`. Backup remains outside the repository because configuration can contain unrelated private settings.
- Added this report, [tooling task](../tasks/tooling-connections.md), tracker note and [verification artifacts](../evidence/TOOL-01/). No game code or authored Blender scene changed.

## Verification
Working directory: repository root. All external writes/socket access used approved sandbox escalation.

| Exact command | Exit | Observed result |
| --- | --- | --- |
| `PYTHONPATH=/Users/rukithnayak/blender_mcp/mcp python3 -m blmcp --help` | 1 | Reproduced missing MCP dependency before fix |
| `/opt/homebrew/bin/uv venv --python /opt/homebrew/bin/python3.12 /Users/rukithnayak/.codex/mcp-envs/blender-lab` | 0 | Dedicated Python 3.12.14 environment created |
| `/opt/homebrew/bin/uv pip install --python /Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/python /Users/rukithnayak/blender_mcp/mcp` | 0 | Local package and 39 packages installed; [versions](../evidence/TOOL-01/installed-packages.json) |
| `/Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/blender-mcp --help` | 0 | Launcher starts and advertises STDIO/HTTP options |
| `/Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/python /private/tmp/blender-mcp-probe.py` | 0 | MCP initialize, 26 tools discovered, live environment query succeeded before config update; [result](../evidence/TOOL-01/standalone-probe.json) |
| `python3 /private/tmp/configure-blender-mcp.py` | 1 | First configuration script invocation lacked `tomllib` under system Python; stopped before reading/writing configuration |
| `/Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/python /private/tmp/configure-blender-mcp.py` | 0 | Backup created; Blender-only settings replacement verified |
| `/Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/python /private/tmp/blender-mcp-probe.py --configured` | 0 | Same initialize/discovery/live query using exact saved configuration; [result](../evidence/TOOL-01/configured-probe.json) |
| `codex mcp get blender` | 0 | Confirms enabled STDIO entry and dedicated launcher |
| `/Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/python /private/tmp/reload-codex-blender-mcp.py` | 1 | Codex daemon proxy initialize timed out after 40s; reload was never sent. Only this probe's proxy subprocess was terminated; daemon/conversation left running |

The read-only live call used the Blender core skill's `env_report.run()` through `execute_blender_code`. Blender returned 5.2.3 LTS. File path, dirty flag, and object/mesh/material counts were compared before/after and unchanged. No mesh authoring, export or asset acceptance is claimed. Godot tests were not rerun because no game source/configuration changed.

Probe/configuration/reload scripts are archived under `docs/evidence/TOOL-01/` for reproduction and inspection. The configuration script deliberately refuses unexpected concurrent Blender settings changes and does not log unrelated config values.

## Remaining step
- The saved MCP launch and live bridge work. This already-running assistant's tool inventory still lacks native Blender tools; standalone verification is not proof of native exposure.
- Keep Blender open, exit Codex, then run `codex resume --last --no-daemon` from the repository root. The installed CLI supports this option; it starts without reusing the existing daemon. Check `/mcp` after launch. No manual installation or configuration work remains.
- No automatic daemon restart was performed because it would interrupt this conversation and potentially other active sessions.

Activation follow-up, 23 October 2026: the subsequent session exposes native Blender tools. `mcp__blender__execute_blender_code` successfully ran the Blender core environment report during WORLD-02 verification: Blender 5.2.3 LTS, EEVEE, one mesh/light/camera, file/dirty state/object count unchanged. [Native call evidence](../evidence/WORLD-02/blender-mcp-probe.json). The preceding restart guidance records the earlier handoff; no activation blocker remains.

## Next task
- Resume WORLD-02 review as recommended by the project tracker, or select the preserved ASSET-03 partial task. This tooling repair does not accept ASSET-03.
