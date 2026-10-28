#!/usr/bin/env python3
"""Bake and export the two Stage 0 reference assets for Godot.

Run from the repository root:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
    --python-exit-code 1 --python tools/blender/export_modular_kit.py -- \
    --out-dir game/assets/reference --repeat-check

The source files are opened read-only. The atlas bake is intentionally a
constant-material bake: ASSET-02 materials contain only constant Principled
base color, roughness and metallic values. Every evaluated triangle gets its
own padded, non-overlapping UV cell, so the maps remain unique and auditably
packed without adding visual detail.
"""
from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile
import time

import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
ASSETS = (
    ("env_wall_doorway_a", ROOT / "art/reference/wall_doorway.blend", "wall_doorway"),
    ("prop_utility_junction_a", ROOT / "art/reference/mechanical_prop.blend", "mechanical_prop"),
)
RESOLUTION = 1024
GUTTER_PX = 2
EXPORT_SETTINGS = {
    "format": "GLB", "export_yup": True, "export_apply": True,
    "export_texcoords": True, "export_normals": True,
    "export_materials": "EXPORT", "export_image_format": "AUTO",
    "export_cameras": False, "export_lights": False,
    "units": "meters; 1 Blender unit = 1 meter",
    "atlas_channels": {"basecolor": "linear RGB source values saved as sRGB PNG",
                       "packed_orm": {"R": "occlusion (constant 1.0)",
                                      "G": "roughness", "B": "metallic"}},
    "collision": "separate *_collision.glb; source COL_ meshes renamed with Godot -colonly suffix",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def principled_constants(material):
    if material is None or not material.use_nodes:
        raise RuntimeError("All render slots must have a node-based Principled material")
    shader = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if shader is None:
        raise RuntimeError(f"No Principled BSDF in {material.name}")
    values = {}
    for label in ("Base Color", "Roughness", "Metallic"):
        socket = shader.inputs[label]
        if socket.is_linked:
            raise RuntimeError(f"{material.name} {label} is procedural/image-driven; this task only bakes constant ASSET-02 inputs")
        value = socket.default_value
        values[label] = list(value) if label == "Base Color" else float(value)
    return values


def evaluated_objects(role: str):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    result = []
    for source in sorted((o for o in bpy.context.scene.objects
                          if o.type == "MESH" and o.get("asset_role") == role),
                         key=lambda o: o.name):
        evaluated = source.evaluated_get(depsgraph)
        mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                               depsgraph=depsgraph)
        mesh.transform(evaluated.matrix_world)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        if any(len(face.verts) != 3 for face in bm.faces):
            bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY", ngon_method="BEAUTY")
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        result.append((source.name, mesh, list(source.data.materials)))
    return result


def make_atlas(asset_id: str, render_objects, out_dir: Path):
    face_records = []
    materials = {}
    for _, mesh, slots in render_objects:
        for mat in slots:
            if mat and mat.name not in materials:
                materials[mat.name] = principled_constants(mat)
        for poly in mesh.polygons:
            if poly.material_index >= len(slots) or not slots[poly.material_index]:
                raise RuntimeError(f"Missing material on a render face in {mesh.name}")
            face_records.append((mesh.name, poly.index, slots[poly.material_index].name))
    if not face_records:
        raise RuntimeError(f"No render faces for {asset_id}")

    cols = math.ceil(math.sqrt(len(face_records)))
    rows = math.ceil(len(face_records) / cols)
    if cols * rows > (RESOLUTION // (2 * GUTTER_PX + 1)) ** 2:
        raise RuntimeError(f"{asset_id} exceeds the {RESOLUTION}px atlas cell capacity")
    cell_w, cell_h = RESOLUTION // cols, RESOLUTION // rows
    base = array("f", [0.0]) * (RESOLUTION * RESOLUTION * 4)
    orm = array("f", [0.0]) * (RESOLUTION * RESOLUTION * 4)
    face_index = 0
    uv_layout = {}
    for object_name, mesh, _slots in render_objects:
        for layer in list(mesh.uv_layers):
            mesh.uv_layers.remove(layer)
        uv = mesh.uv_layers.new(name="UVMap")
        per_object = []
        for poly in mesh.polygons:
            x, y = face_index % cols, face_index // cols
            px0, px1 = x * cell_w, min(RESOLUTION, (x + 1) * cell_w)
            py0, py1 = y * cell_h, min(RESOLUTION, (y + 1) * cell_h)
            rgb = materials[face_records[face_index][2]]["Base Color"]
            rough = materials[face_records[face_index][2]]["Roughness"]
            metal = materials[face_records[face_index][2]]["Metallic"]
            for py in range(py0, py1):
                for px in range(px0, px1):
                    offset = (py * RESOLUTION + px) * 4
                    base[offset:offset + 4] = array("f", (rgb[0], rgb[1], rgb[2], 1.0))
                    orm[offset:offset + 4] = array("f", (1.0, rough, metal, 1.0))
            u0 = (px0 + GUTTER_PX) / RESOLUTION
            u1 = (px1 - GUTTER_PX) / RESOLUTION
            v0 = (py0 + GUTTER_PX) / RESOLUTION
            v1 = (py1 - GUTTER_PX) / RESOLUTION
            # Evaluated meshes are triangulated above; triangle UVs occupy one
            # half-cell and quads occupy the full cell. Neighboring cells never overlap.
            coords = ((u0, v0), (u1, v0), (u1, v1), (u0, v1))
            for loop_i, coord in zip(poly.loop_indices, coords):
                uv.data[loop_i].uv = coord
            poly.material_index = 0
            per_object.append(face_index)
            face_index += 1
        mesh.materials.clear()
        per_object_count = len(per_object)
        uv_layout[object_name] = {"face_count": per_object_count,
                                  "atlas_face_indices": per_object}

    base_name = f"{asset_id}_basecolor_1k.png"
    orm_name = f"{asset_id}_orm_1k.png"
    base_img = bpy.data.images.new(f"T_{asset_id}_BaseColor_1K", RESOLUTION, RESOLUTION, alpha=False)
    base_img.colorspace_settings.name = "sRGB"
    base_img.pixels.foreach_set(base)
    base_path = out_dir / base_name
    base_img.filepath_raw = str(base_path)
    base_img.file_format = "PNG"
    base_img.save()
    orm_img = bpy.data.images.new(f"T_{asset_id}_ORM_1K", RESOLUTION, RESOLUTION, alpha=False)
    orm_img.colorspace_settings.name = "Non-Color"
    orm_img.pixels.foreach_set(orm)
    orm_path = out_dir / orm_name
    orm_img.filepath_raw = str(orm_path)
    orm_img.file_format = "PNG"
    orm_img.save()

    mat = bpy.data.materials.new(f"M_{asset_id}_Baked")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    base_node = nodes.new("ShaderNodeTexImage")
    base_node.image = base_img
    base_node.interpolation = "Linear"
    links.new(base_node.outputs["Color"], principled.inputs["Base Color"])
    orm_node = nodes.new("ShaderNodeTexImage")
    orm_node.image = orm_img
    orm_node.interpolation = "Linear"
    separate = nodes.new("ShaderNodeSeparateColor")
    separate.mode = "RGB"
    links.new(orm_node.outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Green"], principled.inputs["Roughness"])
    links.new(separate.outputs["Blue"], principled.inputs["Metallic"])
    for _name, mesh, _slots in render_objects:
        mesh.materials.append(mat)
    # Make both files embedded in GLB through standard glTF image references.
    return {"basecolor": base_path, "orm": orm_path, "materials": materials,
            "uv_layout": uv_layout, "face_count": len(face_records),
            "grid": [cols, rows], "gutter_px": GUTTER_PX}


def export_scene_glb(path: Path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0] if objects else None
    if not objects:
        raise RuntimeError(f"No selected objects for {path.name}")
    result = bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                                       use_selection=True, export_yup=True,
                                       export_apply=True, export_texcoords=True,
                                       export_normals=True, export_materials="EXPORT",
                                       export_image_format="AUTO", export_cameras=False,
                                       export_lights=False)
    if "FINISHED" not in result or not path.exists() or path.stat().st_size == 0:
        raise RuntimeError(f"glTF export failed: {result} -> {path}")


def mesh_summary(objects):
    vertices = triangles = 0
    bounds_min = [float("inf")] * 3
    bounds_max = [float("-inf")] * 3
    names = []
    for ob in objects:
        mesh = ob.data
        names.append(ob.name)
        vertices += len(mesh.vertices)
        triangles += sum(max(1, len(p.vertices) - 2) for p in mesh.polygons)
        for vertex in mesh.vertices:
            for axis in range(3):
                bounds_min[axis] = min(bounds_min[axis], vertex.co[axis])
                bounds_max[axis] = max(bounds_max[axis], vertex.co[axis])
    bounds = [bounds_max[i] - bounds_min[i] for i in range(3)]
    return {"objects": sorted(names), "vertices": vertices, "triangles": triangles,
            "bounds_blender_xyz_m": [round(v, 6) for v in bounds],
            "bounds_min_blender_xyz_m": [round(v, 6) for v in bounds_min],
            "bounds_max_blender_xyz_m": [round(v, 6) for v in bounds_max]}


def export_asset(asset_id: str, source: Path, stem: str, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    source_hash = sha256(source)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    render_records = evaluated_objects("render")
    collision_records = evaluated_objects("collision")
    # Remove source meshes from this temporary export scene after evaluation so
    # stable authored names remain stable and no `.001` suffixes leak to glTF.
    for source_object in list(bpy.context.scene.objects):
        if source_object.type == "MESH" and source_object.get("asset_role") in {"render", "collision"}:
            bpy.data.objects.remove(source_object, do_unlink=True)
    render_objs, collision_objs = [], []
    for name, mesh, _mats in render_records:
        mesh.name = f"{name}_EvaluatedMesh"
        ob = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(ob)
        ob["asset_id"] = asset_id
        ob["asset_role"] = "render"
        ob["units"] = "meters"
        render_objs.append(ob)
    for name, mesh, _mats in collision_records:
        mesh.name = f"{name}_CollisionMesh"
        ob = bpy.data.objects.new(f"{name}-colonly", mesh)
        bpy.context.scene.collection.objects.link(ob)
        ob["asset_id"] = asset_id
        ob["asset_role"] = "collision"
        ob["collision_source_name"] = name
        ob["collision_semantics"] = "static concave proxy; doorway uses separate left/right/header/threshold proxies"
        collision_objs.append(ob)
    if not render_objs or not collision_objs:
        raise RuntimeError(f"{asset_id} missing render or collision objects")
    atlas = make_atlas(asset_id, render_records, out_dir)
    # Transfer the atlas material to our exported evaluated objects.
    baked_mat = next(iter(render_records[0][1].materials))
    for ob in render_objs:
        ob.data.materials.clear()
        ob.data.materials.append(baked_mat)
    render_glb = out_dir / f"{stem}.glb"
    collision_glb = out_dir / f"{stem}_collision.glb"
    export_scene_glb(render_glb, render_objs)
    export_scene_glb(collision_glb, collision_objs)
    summary = mesh_summary(render_objs)
    collision_summary = mesh_summary(collision_objs)
    metadata = {
        "asset_id": asset_id, "source_file": source.name, "source_sha256": source_hash,
        "blender_version": bpy.app.version_string, "export_settings": EXPORT_SETTINGS,
        "render_glb": render_glb.name, "render_glb_sha256": sha256(render_glb),
        "collision_glb": collision_glb.name, "collision_glb_sha256": sha256(collision_glb),
        "textures": {"basecolor": {"file": atlas["basecolor"].name, "sha256": sha256(atlas["basecolor"]),
                                    "colorspace": "sRGB", "resolution": [RESOLUTION, RESOLUTION]},
                     "orm": {"file": atlas["orm"].name, "sha256": sha256(atlas["orm"]),
                             "colorspace": "Non-Color", "resolution": [RESOLUTION, RESOLUTION],
                             "channels": EXPORT_SETTINGS["atlas_channels"]["packed_orm"]}},
        "render": summary, "collision": collision_summary,
        "materials_source_constants": atlas["materials"],
        "atlas_layout": {"face_count": atlas["face_count"], "grid": atlas["grid"],
                         "gutter_px": atlas["gutter_px"], "uv_in_0_1": True,
                         "per_face_nonoverlap": True, "per_object": atlas["uv_layout"]},
        "notes": ["Asset-root pivot is the source coordinate origin.",
                  "Collision is a separate GLB and is not rendered by the beauty asset.",
                  "Wall collision keeps left pier, right pier, header and threshold as separate proxies; center opening remains empty.",
                  "R occlusion is constant white because these source materials have no occlusion bake input."],
    }
    meta_path = out_dir / f"{stem}.metadata.json"
    meta_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    # Drop the per-object working meshes/data before the next input file opens.
    return metadata, meta_path


def compare_semantics(first, second, tolerance=1e-6):
    """Compare structural fields, excluding output hashes and filenames."""
    ignored = {"render_glb_sha256", "collision_glb_sha256"}
    def normalized(value, path=""):
        if isinstance(value, dict):
            return {k: normalized(v, f"{path}.{k}") for k, v in value.items()
                    if k not in ignored}
        if isinstance(value, list):
            return [normalized(v, path) for v in value]
        if isinstance(value, float):
            return round(value / tolerance) * tolerance
        return value
    a, b = normalized(first), normalized(second)
    if a != b:
        raise RuntimeError("repeat export semantic metadata differs")


def display_path(path: Path) -> str:
    """Prefer repository-relative output paths, while supporting external output dirs."""
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="game/assets/reference")
    parser.add_argument("--repeat-check", action="store_true",
                        help="export twice in scratch folders and compare semantic metadata before writing final outputs")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    out_dir = (ROOT / args.out_dir).resolve()
    if args.repeat_check:
        with tempfile.TemporaryDirectory(prefix="asset03_repeat_") as temp:
            base = Path(temp)
            for asset_id, source, stem in ASSETS:
                meta_a, _ = export_asset(asset_id, source, stem, base / "first")
                meta_b, _ = export_asset(asset_id, source, stem, base / "second")
                compare_semantics(meta_a, meta_b)
                print(json.dumps({"repeat": "PASS", "asset_id": asset_id,
                                  "semantic_meshes": meta_a["render"],
                                  "basecolor_sha256_equal": meta_a["textures"]["basecolor"]["sha256"] == meta_b["textures"]["basecolor"]["sha256"],
                                  "orm_sha256_equal": meta_a["textures"]["orm"]["sha256"] == meta_b["textures"]["orm"]["sha256"],
                                  "render_glb_bytes_equal": (base / "first" / f"{stem}.glb").read_bytes() == (base / "second" / f"{stem}.glb").read_bytes(),
                                  "collision_glb_bytes_equal": (base / "first" / f"{stem}_collision.glb").read_bytes() == (base / "second" / f"{stem}_collision.glb").read_bytes()}))
    results = []
    for asset_id, source, stem in ASSETS:
        meta, meta_path = export_asset(asset_id, source, stem, out_dir)
        results.append({"asset_id": asset_id, "metadata": display_path(meta_path),
                        "render": meta["render"], "collision": meta["collision"],
                        "files": [meta["render_glb"], meta["collision_glb"],
                                  meta["textures"]["basecolor"]["file"], meta["textures"]["orm"]["file"]]})
    print(json.dumps({"status": "PASS", "blender": bpy.app.version_string,
                      "repeat_checked": args.repeat_check, "out_dir": str(out_dir),
                      "assets": results}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
