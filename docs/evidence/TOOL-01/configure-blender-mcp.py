from pathlib import Path
from datetime import datetime
import copy
import os
import shutil
import tomllib

path = Path('/Users/rukithnayak/.codex/config.toml')
original_bytes = path.read_bytes()
original_text = original_bytes.decode('utf-8')
original = tomllib.loads(original_text)
expected = {'command': 'python3', 'args': ['-m', 'blmcp'], 'env': {'PYTHONPATH': '/Users/rukithnayak/blender_mcp/mcp'}}
assert original['mcp_servers']['blender'] == expected, 'Blender configuration changed; refusing to overwrite unexpected edits.'
lines = original_text.splitlines(keepends=True)
start = next(i for i, line in enumerate(lines) if line.strip() == '[mcp_servers.blender]')
end = len(lines)
for i in range(start + 1, len(lines)):
    header = lines[i].strip()
    if header.startswith('[') and not header.startswith('[mcp_servers.blender.'):
        end = i
        break
replacement = '''[mcp_servers.blender]
command = "/Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/blender-mcp"
args = ["--transport", "stdio"]
startup_timeout_sec = 30
tool_timeout_sec = 120

[mcp_servers.blender.env]
BLENDER_MCP_HOST = "127.0.0.1"
BLENDER_MCP_PORT = "9876"

'''
candidate_text = ''.join(lines[:start]) + replacement + ''.join(lines[end:])
candidate = tomllib.loads(candidate_text)
before_other = copy.deepcopy(original)
after_other = copy.deepcopy(candidate)
before_other['mcp_servers'].pop('blender')
after_other['mcp_servers'].pop('blender')
assert before_other == after_other, 'Unexpected change outside Blender config.'
backup = path.with_name('config.toml.blender-backup-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
assert not backup.exists()
shutil.copy2(path, backup)
assert path.read_bytes() == original_bytes, 'Concurrent configuration edit; backup retained and configuration untouched.'
with path.open('w', encoding='utf-8') as handle:
    handle.write(candidate_text)
    handle.flush()
    os.fsync(handle.fileno())
print('Updated Blender STDIO launch; other parsed settings unchanged.')
print('Backup: ' + str(backup))
