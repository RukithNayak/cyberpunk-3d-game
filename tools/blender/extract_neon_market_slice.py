"""Extract an editable 300 m Lantern Market district slice from the pinned source.

Run:
  blender -b --disable-autoexec SOURCE.blend --python-exit-code 1 -P \
    tools/blender/extract_neon_market_slice.py -- --out game/assets/environment/night_market/neon_market_district.glb
"""
import bpy
import json
import os
import sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SOURCE_SCENE = "VESPER / street composition"
COLLECTIONS = (
    "01 CITY / editable voxel architecture",
    "02 NEON / editable signage",
    "07 STREET FRONTS / attached entrance assemblies",
    "09 AUTHORED BLOCKS / residential court and market",
)
# Blender city coordinates (X/Y horizontal, Z vertical). Lantern Market sits at
# X≈-250, Y≈-100. This keeps the approved 300 m square and centers it at origin.
CROP_MIN = Vector((-400.0, -250.0, -50.0))
CROP_MAX = Vector((-100.0, 50.0, 220.0))
SHIFT = Vector((250.0, 100.0, 0.0))

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out_index = args.index("--out") if "--out" in args else -1
if out_index < 0 or out_index + 1 >= len(args):
    raise SystemExit("required: --out PATH")
OUT = os.path.abspath(args[out_index + 1])
OUT_BLEND = os.path.join(ROOT, "art/source/environment/night_market/neon_market_district.blend")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

source = bpy.data.scenes[SOURCE_SCENE]
window = bpy.context.window
previous_scene = window.scene if window else None
if window:
    window.scene = source

def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return Vector(tuple(min(p[i] for p in points) for i in range(3))), Vector(
        tuple(max(p[i] for p in points) for i in range(3)))

def intersects_crop(obj):
    lo, hi = world_bounds(obj)
    return (all(hi[i] >= CROP_MIN[i] and lo[i] <= CROP_MAX[i] for i in (0, 1))
            and hi.x - lo.x < 320.0 and hi.y - lo.y < 320.0)

def contains_user_reference_ad(obj):
    for slot in obj.material_slots:
        material = slot.material
        if not material or not material.node_tree:
            continue
        for node in material.node_tree.nodes:
            if (node.type == "TEX_IMAGE" and node.image
                    and node.image.name.startswith("advert-")):
                return True
    return False

new_scene = bpy.data.scenes.new("NEON DISTRICT / Lantern Market 300m")
new_root = bpy.data.collections.new("ND_Lantern_Market_300m")
new_scene.collection.children.link(new_root)
new_scene.unit_settings.system = "METRIC"
new_scene.unit_settings.scale_length = 1.0
new_scene.render.engine = "BLENDER_EEVEE"
counts = {}
triangles = 0
selected = []
gltf_materials = {}

def gltf_material(original):
    if original.name in gltf_materials:
        return gltf_materials[original.name]
    material = bpy.data.materials.new(
        "M_NeonDistrict_" + original.name.split("/")[-1].strip().replace(" ", "_"))
    material.use_nodes = True
    material.diffuse_color = (1.0, 1.0, 1.0, 1.0)
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tint = tree.nodes.new("ShaderNodeVertexColor")
    tint.layer_name = "VoxelTint"
    tree.links.new(tint.outputs["Color"], shader.inputs["Base Color"])
    surface = original.name.lower()
    if "emissive neon" in surface:
        roughness, metallic, emission = .3, .12, 2.4
    elif "warm windows" in surface:
        roughness, metallic, emission = .38, .08, 1.2
    elif "asphalt" in surface:
        roughness, metallic, emission = .91, .025, 0.0
    elif "metal panels" in surface:
        roughness, metallic, emission = .57, .66, 0.0
    else:
        roughness, metallic, emission = .86, .08, 0.0
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if emission:
        tree.links.new(tint.outputs["Color"], shader.inputs["Emission Color"])
        shader.inputs["Emission Strength"].default_value = emission
    tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    gltf_materials[original.name] = material
    return material

for collection_name in COLLECTIONS:
    src_collection = bpy.data.collections[collection_name]
    dst = bpy.data.collections.new("ND_" + collection_name.split(" / ")[0])
    new_root.children.link(dst)
    count = 0
    for original in src_collection.all_objects:
        if (original.type not in {"MESH", "CURVE"} or original.get("campaign_asset")
                or contains_user_reference_ad(original)):
            continue
        if not intersects_crop(original):
            continue
        clone = original.copy()
        if original.data:
            clone.data = original.data.copy() if original.type == "MESH" else original.data
        clone.name = "ND_" + original.name
        clone.parent = None
        clone.matrix_world = original.matrix_world.copy()
        clone.location.x += SHIFT.x
        clone.location.y += SHIFT.y
        dst.objects.link(clone)
        if clone.type == "MESH":
            for index, slot in enumerate(clone.material_slots):
                if slot.material:
                    clone.data.materials[index] = gltf_material(slot.material)
        selected.append(clone)
        count += 1
        if clone.type == "MESH":
            triangles += sum(len(poly.vertices) - 2 for poly in clone.data.polygons)
    counts[collection_name] = count

if not selected:
    raise RuntimeError("district crop selected no compatible objects")

# Keep this temporary Blender process focused on the extracted subset. The
# upstream file is only opened read-only; this process never writes to it.
if window:
    window.scene = new_scene
keep = set(selected)
for obj in list(bpy.data.objects):
    if obj not in keep:
        bpy.data.objects.remove(obj, do_unlink=True)
for old_scene in list(bpy.data.scenes):
    if old_scene != new_scene:
        bpy.data.scenes.remove(old_scene)
keep_collections = {new_root}
keep_collections.update(new_root.children)
for collection in list(bpy.data.collections):
    if collection not in keep_collections:
        bpy.data.collections.remove(collection, do_unlink=True)
# Do not redistribute campaign images derived from user-supplied references.
used_materials = {slot.material for obj in selected for slot in obj.material_slots
                  if slot.material}
for material in list(bpy.data.materials):
    if material not in used_materials:
        bpy.data.materials.remove(material)
for image in list(bpy.data.images):
    if image.users == 0 or image.name.startswith("advert-"):
        bpy.data.images.remove(image)
bpy.context.window.scene = new_scene
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.object.select_all(action="DESELECT")
for obj in selected:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(
    (obj for obj in selected if obj.type == "MESH"), selected[0])
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_cameras=False,
    export_lights=False,
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_yup=True,
    export_animations=False,
)

result = {
    "blender": bpy.app.version_string,
    "scene": SOURCE_SCENE,
    "crop_blender_xy": [[CROP_MIN.x, CROP_MIN.y], [CROP_MAX.x, CROP_MAX.y]],
    "translation_to_local_origin": list(SHIFT),
    "collections": counts,
    "selected_objects": len(selected),
    "base_triangles": triangles,
    "glb": OUT,
    "glb_bytes": os.path.getsize(OUT),
    "editable_source": OUT_BLEND,
    "source_bytes": os.path.getsize(OUT_BLEND),
    "excluded_campaign_images": True,
    "campaign_images_remaining": [image.name for image in bpy.data.images
                                  if image.name.startswith("advert-")],
}
print("NEON_MARKET_SLICE " + json.dumps(result, sort_keys=True))
