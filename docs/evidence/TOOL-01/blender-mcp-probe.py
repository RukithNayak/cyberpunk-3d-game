import asyncio
import json
import os
import sys
import tomllib
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def probe():
    configured = '--configured' in sys.argv
    if configured:
        config = tomllib.loads(Path('/Users/rukithnayak/.codex/config.toml').read_text())['mcp_servers']['blender']
    else:
        config = {'command': '/Users/rukithnayak/.codex/mcp-envs/blender-lab/bin/blender-mcp', 'args': [], 'env': {'BLENDER_MCP_HOST': '127.0.0.1', 'BLENDER_MCP_PORT': '9876'}}
    params = StdioServerParameters(command=config['command'], args=config.get('args', []), env={**os.environ, **config.get('env', {})})
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            initialized = await session.initialize()
            listed = await session.list_tools()
            names = sorted(tool.name for tool in listed.tools)
            assert 'execute_blender_code' in names
            code = '''import sys, bpy
before = (bpy.data.filepath, bpy.data.is_dirty, len(bpy.data.objects), len(bpy.data.meshes), len(bpy.data.materials))
sys.path.insert(0, '/Users/rukithnayak/.agents/skills/blender-core/scripts')
try:
    import env_report
    environment = env_report.run()
finally:
    sys.path.pop(0)
after = (bpy.data.filepath, bpy.data.is_dirty, len(bpy.data.objects), len(bpy.data.meshes), len(bpy.data.materials))
result = {'environment': environment, 'scene_preserved': before == after}
'''
            response = await session.call_tool('execute_blender_code', {'code': code})
            assert not response.isError, response
            payload = next(json.loads(item.text) for item in response.content if item.type == 'text')
            assert payload.get('status') == 'ok', payload
            result = payload['result']
            assert result['environment']['ok'] and result['scene_preserved'], result
            output = {'configured_launch': configured, 'command': config['command'], 'server': initialized.serverInfo.model_dump(mode='json'), 'protocol': initialized.protocolVersion, 'tools_count': len(names), 'tools': names, 'live_result': result}
            target = Path('docs/evidence/TOOL-01/configured-probe.json' if configured else 'docs/evidence/TOOL-01/standalone-probe.json')
            target.write_text(json.dumps(output, indent=2) + '\n')
            print(json.dumps({'ok': True, 'configured_launch': configured, 'tools_count': len(names), 'blender': result['environment']['blender'], 'scene_preserved': result['scene_preserved'], 'evidence': str(target)}))

asyncio.run(asyncio.wait_for(probe(), timeout=45))
