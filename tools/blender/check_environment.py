#!/usr/bin/env python3
"""Create a tiny Blender-to-GLB smoke fixture; not production art.

Run with:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
    --python-exit-code 1 --python tools/blender/check_environment.py

Writes the source .blend and exported .glb beside this script's fixture directory.
"""
from pathlib import Path
import json
import struct
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "reference" / "environment-smoke"
OUT.mkdir(parents=True, exist_ok=True)


def validate_glb(path):
    data = path.read_bytes()
    if len(data) < 20:
        raise RuntimeError("GLB is too short")
    magic, version, declared_length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or declared_length != len(data):
        raise RuntimeError("Invalid GLB header")
    offset = 12
    json_chunk = None
    while offset < len(data):
        chunk_length, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset:offset + chunk_length]
        if len(chunk) != chunk_length:
            raise RuntimeError("Truncated GLB chunk")
        if chunk_type == b"JSON":
            json_chunk = chunk
        offset += chunk_length
    if offset != len(data) or json_chunk is None:
        raise RuntimeError("Malformed GLB chunk layout")
    gltf = json.loads(json_chunk.rstrip(b" \0"))
    meshes, nodes, materials = gltf.get("meshes", []), gltf.get("nodes", []), gltf.get("materials", [])
    if len(meshes) != 1 or len(nodes) != 1 or len(materials) != 1:
        raise RuntimeError("Expected one mesh, node, and material in smoke GLB")
    primitive = meshes[0]["primitives"][0]
    accessors = gltf["accessors"]
    position = accessors[primitive["attributes"]["POSITION"]]
    indices = accessors[primitive["indices"]]
    if position["min"] != [-0.5, 0, -0.5] or position["max"] != [0.5, 1, 0.5]:
        raise RuntimeError(f"Unexpected exported bounds: {position.get('min')}..{position.get('max')}")
    if indices["count"] != 36 or "TEXCOORD_0" not in primitive["attributes"]:
        raise RuntimeError("Expected 12 triangles and UV coordinates in smoke GLB")

# Fully deterministic, minimal asset: 1 m cube with ground-level, centered pivot.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
scene.unit_settings.length_unit = "METERS"
mesh = bpy.data.meshes.new("SMK_Block_Mesh")
mesh.from_pydata(
    [(-0.5, -0.5, 0.0), (0.5, -0.5, 0.0), (0.5, 0.5, 0.0), (-0.5, 0.5, 0.0),
     (-0.5, -0.5, 1.0), (0.5, -0.5, 1.0), (0.5, 0.5, 1.0), (-0.5, 0.5, 1.0)],
    [],
    [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
     (2, 3, 7, 6), (3, 0, 4, 7)],
)
mesh.update()
# Unwrap each face into a separate tile in a 3x2 atlas for a clean QA/export contract.
uv_layer = mesh.uv_layers.new(name="UVMap")
gutter = 0.01
for poly in mesh.polygons:
    col, row = poly.index % 3, poly.index // 3
    u0, v0 = col / 3 + gutter, row / 2 + gutter
    u1, v1 = (col + 1) / 3 - gutter, (row + 1) / 2 - gutter
    corners = ((u0, v0), (u1, v0), (u1, v1), (u0, v1))
    for loop_index, coord in zip(poly.loop_indices, corners):
        uv_layer.data[loop_index].uv = coord
obj = bpy.data.objects.new("SMK_Block", mesh)
scene.collection.objects.link(obj)
obj["asset_role"] = "environment_smoke_fixture"
obj["pivot"] = "bottom_center"
mat = bpy.data.materials.new("M_SMK_Neutral")
mat.diffuse_color = (0.18, 0.55, 0.72, 1.0)
bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
bsdf.inputs["Base Color"].default_value = (0.18, 0.55, 0.72, 1.0)
bsdf.inputs["Roughness"].default_value = 0.7
obj.data.materials.append(mat)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
if tuple(round(v, 4) for v in obj.dimensions) != (1.0, 1.0, 1.0):
    raise RuntimeError(f"Unexpected smoke mesh dimensions: {tuple(obj.dimensions)}")
if len(mesh.polygons) != 6 or len(mesh.uv_layers) != 1 or len(obj.material_slots) != 1:
    raise RuntimeError("Expected 6 faces, one UV map, and one material")

blend_path = OUT / "environment_smoke.blend"
glb_path = OUT / "environment_smoke.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
result = bpy.ops.export_scene.gltf(
    filepath=str(glb_path), export_format="GLB", use_selection=True,
    export_apply=True, export_yup=True,
)
if "FINISHED" not in result or not glb_path.exists() or glb_path.stat().st_size == 0:
    raise RuntimeError(f"GLB export failed: {result}")
validate_glb(glb_path)
print(f"ASSET_SMOKE blender={bpy.app.version_string} objects=1 dims_m={tuple(round(v, 4) for v in obj.dimensions)} tris={len(mesh.polygons) * 2} blend={blend_path} glb={glb_path} bytes={glb_path.stat().st_size}")
