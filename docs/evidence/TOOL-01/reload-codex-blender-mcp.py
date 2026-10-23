import json
import os
import select
import subprocess
import time
from pathlib import Path

process = subprocess.Popen(['/opt/homebrew/bin/codex', 'app-server', 'proxy'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
responses = {}
def send(payload):
    process.stdin.write(json.dumps(payload) + '\n')
    process.stdin.flush()
def request(number, method, params=None):
    message = {'id': number, 'method': method}
    if params is not None:
        message['params'] = params
    send(message)
    deadline = time.monotonic() + 40
    while time.monotonic() < deadline:
        ready, _, _ = select.select([process.stdout], [], [], 1)
        if not ready:
            if process.poll() is not None:
                raise RuntimeError('Codex proxy exited: ' + process.stderr.read()[:800])
            continue
        line = process.stdout.readline()
        if not line:
            raise RuntimeError('Codex proxy closed')
        response = json.loads(line)
        if response.get('id') == number:
            if 'error' in response:
                raise RuntimeError(method + ': ' + json.dumps(response['error']))
            responses[method] = response['result']
            return response['result']
    raise TimeoutError(method)
try:
    request(1, 'initialize', {'clientInfo': {'name': 'blender_connection_repair', 'version': '1.0.0'}})
    send({'method': 'initialized'})
    status = request(2, 'mcpServerStatus/list', {'serverName': 'blender', 'detail': 'toolsAndAuthOnly'})
    servers = status.get('data', [])
    blender = next(server for server in servers if server.get('name') == 'blender')
    tools = blender.get('tools', {})
    assert len(tools) >= 1, blender
    request(3, 'config/mcpServer/reload')
    safe = {'blender': blender, 'reload_acknowledged': True}
    Path('docs/evidence/TOOL-01/codex-reload.json').write_text(json.dumps(safe, indent=2) + '\n')
    print(json.dumps({'ok': True, 'codex_discovered_tools': len(tools), 'reload_acknowledged': True, 'connectionStatus': blender.get('connectionStatus')}))
finally:
    process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
