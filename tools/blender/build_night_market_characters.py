"""Create authored Night Market NPCs in Blender 5.2 and export Godot GLBs.

Run from the connected Blender MCP session with:
    exec(open('/abs/repo/tools/blender/build_night_market_characters.py').read(), globals())
    result = build_night_market_characters()

The script adds ASSET-prefixed character collections and datablocks to the active
scene; run it in a fresh Blender 5.2.3 session or background process. It writes
appendable source collections with bpy.data.libraries.write; runtime GLBs embed
the generated PBR textures.
"""

from __future__ import annotations

import math
import os
import random
from dataclasses import dataclass
from typing import Any

import bpy
import bmesh
import numpy as np
from mathutils import Vector


ROOT = "/Users/rukithnayak/Documents/ChatGPT/Cyberpunk 3D Game"
SOURCE_DIR = os.path.join(ROOT, "art/source/characters/night_market")
ASSET_DIR = os.path.join(ROOT, "game/assets/characters/night_market")
EVIDENCE_DIR = os.path.join(ROOT, "docs/evidence/ASSET-09")
CROWD_EVIDENCE_DIR = os.path.join(ROOT, "docs/evidence/ASSET-10")
TEXTURE_DIR = os.path.join(SOURCE_DIR, "textures")

ROLE_DATA: dict[str, dict[str, Any]] = {
    "mara_vega": {
        "task": "ASSET09", "label": "Mara Vega", "height": 1.72,
        "coat": (0.88, 0.08, 0.23, 1), "coat_light": (1.0, 0.19, 0.38, 1),
        "shirt": (0.027, 0.04, 0.055, 1), "pants": (0.055, 0.064, 0.075, 1),
        "armor": (0.12, 0.14, 0.16, 1), "metal": (0.30, 0.34, 0.34, 1),
        "skin": (0.52, 0.29, 0.20, 1), "hair": (0.025, 0.018, 0.024, 1),
        "accent": (0.95, 0.31, 0.025, 1), "glow": (0.025, 0.72, 0.78, 1),
    },
    "market_security": {
        "task": "ASSET09", "label": "Market Security", "height": 1.91,
        "coat": (0.18, 0.28, 0.38, 1), "coat_light": (0.28, 0.42, 0.52, 1),
        "shirt": (0.018, 0.028, 0.037, 1), "pants": (0.035, 0.05, 0.064, 1),
        "armor": (0.10, 0.14, 0.16, 1), "metal": (0.28, 0.34, 0.36, 1),
        "skin": (0.30, 0.18, 0.12, 1), "hair": (0.018, 0.025, 0.031, 1),
        "accent": (0.95, 0.38, 0.035, 1), "glow": (0.85, 0.055, 0.08, 1),
    },
    "market_vendor": {
        "task": "ASSET10", "label": "Night Market Vendor", "height": 1.69,
        "coat": (0.08, 0.72, 0.60, 1), "coat_light": (0.15, 0.90, 0.78, 1),
        "shirt": (0.34, 0.30, 0.22, 1), "pants": (0.07, 0.09, 0.09, 1),
        "armor": (0.11, 0.15, 0.15, 1), "metal": (0.32, 0.37, 0.34, 1),
        "skin": (0.36, 0.21, 0.13, 1), "hair": (0.04, 0.026, 0.02, 1),
        "accent": (0.96, 0.50, 0.055, 1), "glow": (0.02, 0.68, 0.56, 1),
    },
    "market_courier": {
        "task": "ASSET10", "label": "Night Market Courier", "height": 1.76,
        "coat": (0.48, 0.28, 0.76, 1), "coat_light": (0.68, 0.40, 0.92, 1),
        "shirt": (0.026, 0.04, 0.06, 1), "pants": (0.07, 0.08, 0.13, 1),
        "armor": (0.12, 0.14, 0.22, 1), "metal": (0.29, 0.34, 0.42, 1),
        "skin": (0.68, 0.42, 0.29, 1), "hair": (0.045, 0.022, 0.055, 1),
        "accent": (0.97, 0.18, 0.40, 1), "glow": (0.03, 0.77, 0.88, 1),
    },
}


@dataclass
class MeshBuilder:
    vertices: list[tuple[float, float, float]]
    faces: list[tuple[int, ...]]
    material_ids: list[int]
    bone_names: list[str]

    @classmethod
    def create(cls) -> "MeshBuilder":
        return cls([], [], [], [])

    def add(self, vertices: list[tuple[float, float, float]], faces: list[tuple[int, ...]], material: int, bone: str) -> None:
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(index + offset for index in face) for face in faces)
        self.material_ids.extend([material] * len(faces))
        self.bone_names.extend([bone] * len(vertices))

    def ellipsoid(self, center: Vector, scale: Vector, material: int, bone: str, segments: int = 16, rings: int = 10) -> None:
        vertices: list[tuple[float, float, float]] = []
        faces: list[tuple[int, ...]] = []
        for ring in range(1, rings + 1):
            theta = math.pi * ring / (rings + 1)
            for segment in range(segments):
                phi = math.tau * segment / segments
                p = Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), math.cos(theta))) * scale + center
                vertices.append(tuple(p))
        top = len(vertices)
        vertices.append(tuple(center + Vector((0, 0, scale.z))))
        bottom = len(vertices)
        vertices.append(tuple(center - Vector((0, 0, scale.z))))
        for ring in range(rings - 1):
            for segment in range(segments):
                a = ring * segments + segment
                b = ring * segments + (segment + 1) % segments
                c = (ring + 1) * segments + (segment + 1) % segments
                d = (ring + 1) * segments + segment
                faces.append((a, b, c, d))
        for segment in range(segments):
            faces.append((top, (segment + 1) % segments, segment))
            a = (rings - 1) * segments + segment
            b = (rings - 1) * segments + (segment + 1) % segments
            faces.append((bottom, a, b))
        self.add(vertices, faces, material, bone)

    def box(self, center: Vector, size: Vector, material: int, bone: str, bevel: float = 0.0) -> None:
        # Slightly bevelled rectangular volumes read as tailored gear at game distance.
        x, y, z = size.x * 0.5, size.y * 0.5, size.z * 0.5
        vertices = [
            (center.x - x, center.y - y, center.z - z), (center.x + x, center.y - y, center.z - z),
            (center.x + x, center.y + y, center.z - z), (center.x - x, center.y + y, center.z - z),
            (center.x - x, center.y - y, center.z + z), (center.x + x, center.y - y, center.z + z),
            (center.x + x, center.y + y, center.z + z), (center.x - x, center.y + y, center.z + z),
        ]
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.add(vertices, faces, material, bone)

    def cylinder_between(self, start: Vector, end: Vector, radius: float, material: int, bone: str, sides: int = 12, end_radius: float | None = None) -> None:
        direction = end - start
        if direction.length < 1e-5:
            return
        axis = direction.normalized()
        reference = Vector((0, 1, 0)) if abs(axis.dot(Vector((0, 0, 1)))) > 0.9 else Vector((0, 0, 1))
        u = axis.cross(reference).normalized()
        v = axis.cross(u).normalized()
        vertices: list[tuple[float, float, float]] = []
        faces: list[tuple[int, ...]] = []
        r_end = radius if end_radius is None else end_radius
        for center, r in ((start, radius), (end, r_end)):
            for side in range(sides):
                angle = math.tau * side / sides
                p = center + r * (math.cos(angle) * u + math.sin(angle) * v)
                vertices.append(tuple(p))
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((side, nxt, sides + nxt, sides + side))
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple(range(sides, sides * 2)))
        self.add(vertices, faces, material, bone)

    def torso(self, rings: list[tuple[float, float, float, float]], material: int, bone: str, sides: int = 16) -> None:
        vertices: list[tuple[float, float, float]] = []
        faces: list[tuple[int, ...]] = []
        for z, width, depth, center_y in rings:
            for side in range(sides):
                angle = math.tau * side / sides
                vertices.append((width * math.cos(angle), center_y + depth * math.sin(angle), z))
        for ring in range(len(rings) - 1):
            for side in range(sides):
                a = ring * sides + side
                b = ring * sides + (side + 1) % sides
                c = (ring + 1) * sides + (side + 1) % sides
                d = (ring + 1) * sides + side
                faces.append((a, b, c, d))
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple((len(rings) - 1) * sides + side for side in range(sides)))
        self.add(vertices, faces, material, bone)


def _make_texture_images(prefix: str) -> dict[str, bpy.types.Image]:
    os.makedirs(TEXTURE_DIR, exist_ok=True)
    size = 512
    rng = np.random.default_rng(97103)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    weave = 0.018 * np.sin(xx * math.tau / 7.0) + 0.013 * np.sin(yy * math.tau / 11.0)
    grain = rng.normal(0.0, 0.012, (size, size)).astype(np.float32)
    base = np.clip(0.91 + weave + grain, 0.72, 1.08)
    rough = np.clip(0.75 + 0.08 * np.sin(xx * math.tau / 41.0) + rng.normal(0.0, 0.035, (size, size)), 0.38, 0.94)
    nx = 0.5 + 0.035 * np.cos(xx * math.tau / 7.0)
    ny = 0.5 + 0.03 * np.cos(yy * math.tau / 11.0)
    normal = np.stack((nx, ny, np.sqrt(np.maximum(0.0, 1.0 - (nx - 0.5) ** 2 - (ny - 0.5) ** 2)) * 0.5 + 0.5), axis=-1).astype(np.float32)
    images: dict[str, bpy.types.Image] = {}
    for name, channels, colorspace in (
        ("fabric_basecolor", np.stack((base, base, base, np.ones_like(base)), axis=-1), "sRGB"),
        ("fabric_roughness", np.stack((rough, rough, rough, np.ones_like(base)), axis=-1), "Non-Color"),
        ("fabric_normal", np.concatenate((normal, np.ones((size, size, 1), dtype=np.float32)), axis=-1), "Non-Color"),
    ):
        path = os.path.join(TEXTURE_DIR, "%s_%s_512.png" % (prefix, name))
        image = bpy.data.images.new("%s_%s" % (prefix, name), width=size, height=size, alpha=True, float_buffer=False)
        image.pixels.foreach_set(channels.astype(np.float32).ravel())
        image.colorspace_settings.name = colorspace
        image.filepath_raw = path
        image.file_format = "PNG"
        image.save()
        image.pack()
        images[name] = image
    return images


def _material(name: str, rgba: tuple[float, float, float, float], images: dict[str, bpy.types.Image], metallic: float, roughness: float, emission: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = rgba
    material.use_nodes = True
    nodes = material.node_tree.nodes
    principled = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    principled.inputs["Base Color"].default_value = rgba
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Coat Weight"].default_value = 0.16 if metallic < 0.5 else 0.06
    if emission > 0.0:
        principled.inputs["Emission Color"].default_value = rgba
        principled.inputs["Emission Strength"].default_value = emission
    if metallic < 0.5 and "skin" not in name.lower() and emission == 0.0:
        color = nodes.new("ShaderNodeTexImage")
        color.image = images["fabric_basecolor"]
        tint = nodes.new("ShaderNodeMixRGB")
        tint.blend_type = "MULTIPLY"
        tint.inputs["Fac"].default_value = 1.0
        tint.inputs["Color2"].default_value = rgba
        rough = nodes.new("ShaderNodeTexImage")
        rough.image = images["fabric_roughness"]
        rough.image.colorspace_settings.name = "Non-Color"
        normal = nodes.new("ShaderNodeTexImage")
        normal.image = images["fabric_normal"]
        normal.image.colorspace_settings.name = "Non-Color"
        bump = nodes.new("ShaderNodeNormalMap")
        bump.inputs["Strength"].default_value = 0.16
        material.node_tree.links.new(color.outputs["Color"], tint.inputs["Color1"])
        material.node_tree.links.new(tint.outputs["Color"], principled.inputs["Base Color"])
        material.node_tree.links.new(rough.outputs["Color"], principled.inputs["Roughness"])
        material.node_tree.links.new(normal.outputs["Color"], bump.inputs["Color"])
        material.node_tree.links.new(bump.outputs["Normal"], principled.inputs["Normal"])
    return material


def _make_material_set(role: str, data: dict[str, Any]) -> tuple[list[bpy.types.Material], dict[str, int]]:
    images = _make_texture_images(role)
    names = ["skin", "coat", "coat_light", "shirt", "pants", "armor", "metal", "hair", "accent", "glow", "lens", "sole"]
    mats: list[bpy.types.Material] = []
    indices: dict[str, int] = {}
    for name in names:
        color = data.get(name, data["coat"])
        emission = 2.0 if name == "glow" else (0.22 if name == "coat" else 0.12 if name == "coat_light" else 0.0)
        metallic = 1.0 if name in ["metal", "lens"] else (0.15 if name == "armor" else 0.0)
        roughness = 0.29 if name in ["metal", "lens"] else (0.42 if name == "armor" else 0.76)
        indices[name] = len(mats)
        mats.append(_material("%s_%s" % (role, name), color, images, metallic, roughness, emission))
    return mats, indices


def _coords(x: float, y: float, z: float, scale: float) -> Vector:
    return Vector((x * scale, y * scale, z * scale))


def _face(builder: MeshBuilder, role: str, s: float, m: dict[str, int], data: dict[str, Any]) -> None:
    skin, hair, eye = m["skin"], m["hair"], m["lens"]
    builder.cylinder_between(_coords(0, 0, 1.40, s), _coords(0, 0, 1.50, s), 0.055 * s, skin, "neck")
    builder.ellipsoid(_coords(0, 0, 1.615, s), _coords(0.115, 0.103, 0.151, s), skin, "head", 20, 14)
    builder.ellipsoid(_coords(-0.116, 0, 1.61, s), _coords(0.024, 0.027, 0.042, s), skin, "head", 12, 8)
    builder.ellipsoid(_coords(0.116, 0, 1.61, s), _coords(0.024, 0.027, 0.042, s), skin, "head", 12, 8)
    # Forward-facing eyes, brows, nose bridge and mouth keep the face readable in-game.
    for x in (-0.044, 0.044):
        builder.ellipsoid(_coords(x, -0.095, 1.626, s), _coords(0.022, 0.009, 0.012, s), m["shirt"], "head", 12, 8)
        builder.ellipsoid(_coords(x, -0.103, 1.626, s), _coords(0.008, 0.005, 0.008, s), m["glow"] if role == "market_security" and x > 0 else eye, "head", 10, 6)
        builder.ellipsoid(_coords(x, -0.095, 1.651, s), _coords(0.028, 0.013, 0.007, s), hair, "head", 12, 6)
    builder.ellipsoid(_coords(0, -0.109, 1.59, s), _coords(0.018, 0.026, 0.034, s), skin, "head", 12, 8)
    builder.cylinder_between(_coords(-0.027, -0.102, 1.555, s), _coords(0.027, -0.102, 1.555, s), 0.004 * s, m["accent"], "head", 8)
    # Hair cap and role-specific silhouette.
    builder.ellipsoid(_coords(0, 0.0, 1.702, s), _coords(0.126, 0.118, 0.066, s), hair, "head", 18, 8)
    if role == "mara_vega":
        for x in (-0.095, 0.095):
            builder.ellipsoid(_coords(x, 0.006, 1.653, s), _coords(0.035, 0.115, 0.024, s), hair, "head", 12, 8)
        builder.ellipsoid(_coords(-0.065, -0.07, 1.704, s), _coords(0.052, 0.045, 0.026, s), hair, "head", 14, 8)
    elif role == "market_security":
        builder.ellipsoid(_coords(0, -0.04, 1.62, s), _coords(0.128, 0.094, 0.105, s), m["armor"], "head", 20, 10)
        builder.box(_coords(0, -0.118, 1.627, s), _coords(0.19, 0.025, 0.040, s), m["glow"], "head")
        builder.box(_coords(0, -0.10, 1.565, s), _coords(0.105, 0.028, 0.05, s), m["shirt"], "head")
        for x in (-0.035, 0.0, 0.035):
            builder.box(_coords(x, -0.117, 1.565, s), _coords(0.012, 0.012, 0.026, s), m["metal"], "head")
    elif role == "market_vendor":
        builder.ellipsoid(_coords(0, 0, 1.728, s), _coords(0.14, 0.125, 0.045, s), m["accent"], "head", 16, 8)
        builder.box(_coords(0, 0, 1.689, s), _coords(0.26, 0.20, 0.022, s), m["accent"], "head")
        builder.box(_coords(0, -0.104, 1.598, s), _coords(0.10, 0.018, 0.032, s), m["shirt"], "head")
    else:
        for side in (-1, 1):
            builder.cylinder_between(_coords(side * 0.12, 0.0, 1.65, s), _coords(side * 0.14, 0.0, 1.58, s), 0.009 * s, m["metal"], "head", 8)
            builder.ellipsoid(_coords(side * 0.14, 0, 1.58, s), _coords(0.035, 0.035, 0.03, s), m["metal"], "head", 12, 8)
    # Mara's asymmetrical comms implant is a small, distinct face marker.
    if role == "mara_vega":
        builder.ellipsoid(_coords(0.115, -0.006, 1.635, s), _coords(0.034, 0.028, 0.045, s), m["metal"], "head", 12, 8)
        builder.ellipsoid(_coords(0.137, -0.029, 1.635, s), _coords(0.013, 0.008, 0.018, s), m["glow"], "head", 12, 8)


def _add_person(builder: MeshBuilder, role: str, s: float, m: dict[str, int], data: dict[str, Any]) -> None:
    # Unified humanoid underlayer.
    builder.torso([(0.82, 0.16, 0.105, 0.0), (0.96, 0.22, 0.13, 0.0), (1.13, 0.25, 0.145, 0.0), (1.30, 0.305, 0.135, 0.0), (1.39, 0.23, 0.10, 0.0)], m["shirt"], "spine_02")
    # Leg silhouette: trouser volumes, joint seams and grounded boots.
    for side, suffix in ((-1, ".L"), (1, ".R")):
        x = side * 0.115
        builder.cylinder_between(_coords(x, 0, 0.86, s), _coords(x * 1.05, 0.002, 0.50, s), 0.092 * s, m["pants"], "thigh" + suffix, 14, 0.078 * s)
        builder.ellipsoid(_coords(x * 1.05, 0, 0.49, s), _coords(0.079, 0.083, 0.078, s), m["pants"], "shin" + suffix, 14, 8)
        builder.cylinder_between(_coords(x * 1.05, 0.0, 0.46, s), _coords(x * 1.02, -0.004, 0.16, s), 0.070 * s, m["pants"], "shin" + suffix, 14, 0.053 * s)
        builder.box(_coords(x, -0.018, 0.09, s), _coords(0.125, 0.25, 0.11, s), m["armor"] if role == "market_security" else m["pants"], "foot" + suffix)
        builder.box(_coords(x, -0.092, 0.07, s), _coords(0.128, 0.12, 0.04, s), m["sole"], "foot" + suffix)
        builder.box(_coords(x, -0.035, 0.22, s), _coords(0.12, 0.12, 0.045, s), m["armor"], "shin" + suffix)
        for seam_z in (0.35, 0.62):
            builder.cylinder_between(_coords(x - 0.062, -0.02, seam_z, s), _coords(x + 0.062, -0.02, seam_z, s), 0.008 * s, m["metal"], "shin" + suffix, 8)
    # Arms are separate rigged pieces, with articulated shoulder/elbow cuffs.
    for side, suffix in ((-1, ".L"), (1, ".R")):
        shoulder = _coords(side * 0.285, 0, 1.34, s)
        elbow = _coords(side * 0.345, -0.008, 1.08, s)
        wrist = _coords(side * 0.37, -0.02, 0.87, s)
        hand = _coords(side * 0.37, -0.04, 0.80, s)
        builder.ellipsoid(shoulder, _coords(0.09, 0.11, 0.095, s), m["armor"] if role == "market_security" else m["coat"], "upper_arm" + suffix, 14, 8)
        builder.cylinder_between(shoulder, elbow, 0.076 * s, m["coat"], "upper_arm" + suffix, 14, 0.066 * s)
        builder.ellipsoid(elbow, _coords(0.069, 0.075, 0.066, s), m["armor"], "forearm" + suffix, 14, 8)
        builder.cylinder_between(elbow, wrist, 0.061 * s, m["coat_light"], "forearm" + suffix, 14, 0.045 * s)
        builder.box(_coords(side * 0.36, -0.026, 0.95, s), _coords(0.115, 0.14, 0.055, s), m["armor"], "forearm" + suffix)
        builder.cylinder_between(_coords(side * 0.36, -0.02, 0.90, s), _coords(side * 0.38, -0.02, 0.90, s), 0.054 * s, m["metal"], "hand" + suffix, 10)
        builder.ellipsoid(hand, _coords(0.052, 0.035, 0.060, s), m["skin"] if role != "market_security" else m["armor"], "hand" + suffix, 14, 8)
        for finger in range(4):
            fx = side * (0.344 + finger * 0.015)
            builder.cylinder_between(_coords(fx, -0.046, 0.79, s), _coords(fx, -0.045, 0.75, s), 0.009 * s, m["skin"], "hand" + suffix, 7, 0.007 * s)
        builder.cylinder_between(_coords(side * 0.36, -0.02, 1.11, s), _coords(side * 0.36, -0.02, 1.15, s), 0.069 * s, m["metal"], "upper_arm" + suffix, 10)
    _face(builder, role, s, m, data)

    # Tailored outer garment, custom waist/chest profile and layered front panels.
    if role == "mara_vega":
        builder.torso([(0.42, 0.265, 0.15, 0.004), (0.70, 0.275, 0.15, 0.004), (0.88, 0.244, 0.16, 0.0), (1.10, 0.29, 0.17, 0.0), (1.30, 0.35, 0.15, 0.0), (1.42, 0.28, 0.115, 0.0)], m["coat"], "spine_02")
        builder.box(_coords(0, -0.145, 1.44, s), _coords(0.36, 0.12, 0.13, s), m["coat_light"], "spine_02")
        builder.box(_coords(0, -0.164, 1.40, s), _coords(0.18, 0.032, 0.08, s), m["shirt"], "spine_02")
        for side in (-1, 1):
            builder.box(_coords(side * 0.105, -0.177, 1.24, s), _coords(0.13, 0.036, 0.33, s), m["coat_light"], "spine_02")
            builder.cylinder_between(_coords(side * 0.10, -0.201, 1.05, s), _coords(side * 0.10, -0.202, 1.33, s), 0.009 * s, m["accent"], "spine_02", 6)
            builder.box(_coords(side * 0.24, -0.04, 0.57, s), _coords(0.08, 0.13, 0.43, s), m["coat"], "pelvis")
            builder.box(_coords(side * 0.25, -0.11, 0.57, s), _coords(0.045, 0.02, 0.31, s), m["coat_light"], "pelvis")
        # Belt, clasp, asymmetrical radio and leg holster.
        builder.box(_coords(0, -0.145, 0.88, s), _coords(0.46, 0.055, 0.07, s), m["metal"], "pelvis")
        builder.box(_coords(0, -0.181, 0.88, s), _coords(0.09, 0.02, 0.052, s), m["accent"], "pelvis")
        builder.box(_coords(0.25, -0.12, 1.16, s), _coords(0.085, 0.065, 0.15, s), m["armor"], "spine_02")
        for z in (1.11, 1.17, 1.22):
            builder.box(_coords(0.25, -0.157, z, s), _coords(0.049, 0.01, 0.012, s), m["glow"] if z == 1.17 else m["metal"], "spine_02")
        builder.box(_coords(-0.12, -0.16, 1.03, s), _coords(0.10, 0.055, 0.095, s), m["armor"], "spine_02")
        builder.box(_coords(0.08, -0.161, 1.00, s), _coords(0.10, 0.045, 0.11, s), m["armor"], "spine_02")
        for x in (-0.21, 0.21):
            for z in (0.82, 1.31):
                builder.ellipsoid(_coords(x, -0.185, z, s), _coords(0.012, 0.009, 0.012, s), m["metal"], "spine_02", 8, 6)
    elif role == "market_security":
        builder.torso([(0.68, 0.29, 0.19, 0.0), (0.90, 0.31, 0.20, 0.0), (1.12, 0.34, 0.20, 0.0), (1.34, 0.39, 0.18, 0.0), (1.48, 0.29, 0.13, 0.0)], m["coat"], "spine_02")
        builder.box(_coords(0, -0.202, 1.20, s), _coords(0.49, 0.05, 0.36, s), m["armor"], "spine_02")
        builder.box(_coords(0, -0.234, 1.20, s), _coords(0.38, 0.025, 0.24, s), m["coat_light"], "spine_02")
        for side in (-1, 1):
            builder.box(_coords(side * 0.09, -0.254, 1.19, s), _coords(0.12, 0.025, 0.17, s), m["armor"], "spine_02")
            builder.box(_coords(side * 0.24, -0.155, 1.39, s), _coords(0.20, 0.19, 0.12, s), m["armor"], "spine_02")
            builder.box(_coords(side * 0.28, -0.12, 0.96, s), _coords(0.13, 0.18, 0.20, s), m["armor"], "pelvis")
            for z in (0.95, 1.02, 1.09):
                builder.box(_coords(side * 0.28, -0.252, z, s), _coords(0.08, 0.018, 0.022, s), m["metal"], "pelvis")
        builder.box(_coords(0, -0.265, 1.19, s), _coords(0.11, 0.022, 0.08, s), m["glow"], "spine_02")
        builder.box(_coords(0, -0.235, 0.88, s), _coords(0.62, 0.075, 0.075, s), m["metal"], "pelvis")
        for x in (-0.22, -0.11, 0.11, 0.22):
            builder.box(_coords(x, -0.28, 0.88, s), _coords(0.075, 0.035, 0.09, s), m["armor"], "pelvis")
        # Tall shoulder marking, left arm serial patch, forearm shield and radio whip.
        builder.box(_coords(-0.04, -0.274, 1.31, s), _coords(0.055, 0.016, 0.17, s), m["accent"], "spine_02")
        builder.box(_coords(-0.37, -0.091, 1.23, s), _coords(0.055, 0.02, 0.10, s), m["glow"], "upper_arm.L")
        builder.cylinder_between(_coords(0.22, 0.04, 1.36, s), _coords(0.23, 0.04, 1.72, s), 0.006 * s, m["metal"], "spine_02", 6)
    elif role == "market_vendor":
        builder.torso([(0.60, 0.25, 0.15, 0.0), (0.85, 0.25, 0.15, 0.0), (1.05, 0.255, 0.14, 0.0), (1.30, 0.295, 0.13, 0.0), (1.41, 0.24, 0.12, 0.0)], m["coat_light"], "spine_02")
        builder.torso([(0.48, 0.24, 0.036, -0.14), (0.53, 0.24, 0.04, -0.145), (1.20, 0.21, 0.035, -0.14), (1.25, 0.19, 0.035, -0.14)], m["coat"], "spine_02", 12)
        builder.box(_coords(0, -0.188, 0.79, s), _coords(0.28, 0.032, 0.22, s), m["coat"], "spine_02")
        builder.box(_coords(0, -0.211, 0.87, s), _coords(0.16, 0.018, 0.055, s), m["accent"], "spine_02")
        builder.box(_coords(0, -0.184, 0.48, s), _coords(0.16, 0.025, 0.12, s), m["shirt"], "spine_02")
        builder.box(_coords(0.18, -0.19, 1.13, s), _coords(0.09, 0.06, 0.12, s), m["metal"], "spine_02")
        for z in (1.11, 1.15):
            builder.ellipsoid(_coords(0.18, -0.226, z, s), _coords(0.009, 0.006, 0.009, s), m["glow"], "spine_02", 8, 6)
        for side in (-1, 1):
            builder.box(_coords(side * 0.16, -0.17, 1.04, s), _coords(0.06, 0.035, 0.12, s), m["accent"], "spine_02")
    else:
        # Courier bomber jacket, visible diagonal strap and hard-shell sling bag.
        builder.torso([(0.56, 0.26, 0.16, 0.0), (0.86, 0.27, 0.17, 0.0), (1.10, 0.29, 0.17, 0.0), (1.31, 0.34, 0.15, 0.0), (1.42, 0.26, 0.12, 0.0)], m["coat"], "spine_02")
        builder.box(_coords(-0.13, -0.193, 0.98, s), _coords(0.11, 0.025, 0.21, s), m["coat_light"], "spine_02")
        builder.box(_coords(0.08, -0.197, 1.01, s), _coords(0.13, 0.027, 0.14, s), m["armor"], "spine_02")
        builder.box(_coords(0, -0.196, 1.29, s), _coords(0.06, 0.025, 0.20, s), m["accent"], "spine_02")
        builder.box(_coords(0.22, 0.125, 1.15, s), _coords(0.22, 0.20, 0.32, s), m["armor"], "spine_02")
        builder.box(_coords(0.22, 0.018, 1.16, s), _coords(0.18, 0.026, 0.22, s), m["coat_light"], "spine_02")
        builder.cylinder_between(_coords(-0.23, -0.20, 1.38, s), _coords(0.22, -0.18, 0.87, s), 0.025 * s, m["accent"], "spine_02", 10)
        builder.box(_coords(0.19, -0.216, 1.03, s), _coords(0.07, 0.027, 0.09, s), m["glow"], "spine_02")

    # Common seam and hardware details: visible at torso and weapon distance.
    for side in (-1, 1):
        builder.box(_coords(side * 0.22, -0.177, 0.77, s), _coords(0.075, 0.028, 0.11, s), m["armor"], "pelvis")
        for z in (0.74, 0.79, 0.84):
            builder.ellipsoid(_coords(side * 0.22, -0.195, z, s), _coords(0.009, 0.006, 0.009, s), m["metal"], "pelvis", 8, 6)
        builder.cylinder_between(_coords(side * 0.28, -0.12, 0.44, s), _coords(side * 0.17, -0.14, 0.44, s), 0.005 * s, m["accent"], "thigh" + (".L" if side < 0 else ".R"), 6)


def _skeleton(scene: bpy.types.Scene, role: str, s: float, collection: bpy.types.Collection) -> bpy.types.Object:
    arm_data = bpy.data.armatures.new("ASSET_%s_Skeleton" % role)
    arm = bpy.data.objects.new("ASSET_%s_Rig" % role, arm_data)
    collection.objects.link(arm)
    arm.show_in_front = True
    arm_data.display_type = "STICK"
    window = bpy.context.window
    previous_scene = window.scene if window is not None else None
    if window is not None:
        window.scene = scene
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bones: dict[str, tuple[tuple[float, float, float], tuple[float, float, float], str | None]] = {
        "root": ((0, 0, 0.0), (0, 0, 0.78), None),
        "pelvis": ((0, 0, 0.73), (0, 0, 0.96), "root"),
        "spine_01": ((0, 0, 0.92), (0, 0, 1.13), "pelvis"),
        "spine_02": ((0, 0, 1.12), (0, 0, 1.40), "spine_01"),
        "neck": ((0, 0, 1.38), (0, 0, 1.51), "spine_02"),
        "head": ((0, 0, 1.49), (0, 0, 1.74), "neck"),
    }
    for side, suffix in ((-1, ".L"), (1, ".R")):
        bones["clavicle" + suffix] = ((side * 0.13, 0, 1.34), (side * 0.29, 0, 1.35), "spine_02")
        bones["upper_arm" + suffix] = ((side * 0.29, 0, 1.35), (side * 0.345, 0, 1.08), "clavicle" + suffix)
        bones["forearm" + suffix] = ((side * 0.345, 0, 1.08), (side * 0.37, 0, 0.89), "upper_arm" + suffix)
        bones["hand" + suffix] = ((side * 0.37, 0, 0.89), (side * 0.37, -0.10, 0.77), "forearm" + suffix)
        bones["thigh" + suffix] = ((side * 0.11, 0, 0.85), (side * 0.12, 0, 0.50), "pelvis")
        bones["shin" + suffix] = ((side * 0.12, 0, 0.50), (side * 0.11, 0, 0.15), "thigh" + suffix)
        bones["foot" + suffix] = ((side * 0.11, 0, 0.15), (side * 0.11, -0.18, 0.08), "shin" + suffix)
    edit: dict[str, bpy.types.EditBone] = {}
    for name, (head, tail, parent) in bones.items():
        bone = arm_data.edit_bones.new(name)
        bone.head = Vector(head) * s
        bone.tail = Vector(tail) * s
        if parent is not None:
            bone.parent = edit[parent]
        edit[name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    if window is not None and previous_scene is not None:
        window.scene = previous_scene
    return arm


def _build_animation(arm: bpy.types.Object, scene: bpy.types.Scene, role: str) -> list[str]:
    clips: list[tuple[str, int, dict[int, dict[str, tuple[float, float, float]]]]] = [
        ("Idle", 24, {1: {}, 12: {"spine_02": (math.radians(-1.1), 0, 0), "head": (0, 0, math.radians(1.5))}, 24: {}}),
        ("Walk", 24, {
            1: {"thigh.L": (math.radians(22), 0, 0), "thigh.R": (math.radians(-22), 0, 0), "upper_arm.L": (math.radians(-16), 0, 0), "upper_arm.R": (math.radians(16), 0, 0)},
            7: {"thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0), "upper_arm.L": (0, 0, 0), "upper_arm.R": (0, 0, 0)},
            13: {"thigh.L": (math.radians(-22), 0, 0), "thigh.R": (math.radians(22), 0, 0), "upper_arm.L": (math.radians(16), 0, 0), "upper_arm.R": (math.radians(-16), 0, 0)},
            19: {"thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0), "upper_arm.L": (0, 0, 0), "upper_arm.R": (0, 0, 0)},
            24: {"thigh.L": (math.radians(22), 0, 0), "thigh.R": (math.radians(-22), 0, 0), "upper_arm.L": (math.radians(-16), 0, 0), "upper_arm.R": (math.radians(16), 0, 0)},
        }),
        ("Interact", 32, {
            1: {}, 12: {"upper_arm.R": (math.radians(-24), 0, math.radians(-8)), "forearm.R": (math.radians(-38), 0, 0), "head": (math.radians(3), 0, 0)},
            22: {"upper_arm.R": (math.radians(-18), 0, math.radians(4)), "forearm.R": (math.radians(-25), 0, 0)}, 32: {},
        }),
        ("Combat", 24, {
            1: {"upper_arm.R": (math.radians(-48), 0, math.radians(-8)), "forearm.R": (math.radians(-32), 0, 0), "upper_arm.L": (math.radians(-28), 0, math.radians(8)), "forearm.L": (math.radians(-42), 0, 0)},
            24: {"upper_arm.R": (math.radians(-48), 0, math.radians(-8)), "forearm.R": (math.radians(-32), 0, 0), "upper_arm.L": (math.radians(-28), 0, math.radians(8)), "forearm.L": (math.radians(-42), 0, 0)},
        }),
        ("Death", 24, {
            1: {}, 10: {"root": (math.radians(22), 0, 0), "upper_arm.L": (math.radians(-35), 0, math.radians(24)), "upper_arm.R": (math.radians(-18), 0, math.radians(-20))},
            24: {"root": (math.radians(72), 0, 0), "upper_arm.L": (math.radians(-62), 0, math.radians(50)), "upper_arm.R": (math.radians(-40), 0, math.radians(-36))},
        }),
    ]
    actions: list[str] = []
    arm.animation_data_create()
    for clip_name, end_frame, keys in clips:
        arm.animation_data.action = None
        for frame, bone_values in keys.items():
            scene.frame_set(frame)
            for pose_bone in arm.pose.bones:
                pose_bone.rotation_mode = "XYZ"
                pose_bone.rotation_euler = bone_values.get(pose_bone.name, (0, 0, 0))
                pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=pose_bone.name)
        action = arm.animation_data.action
        if action is None:
            continue
        action.name = "%s_%s" % (role, clip_name)
        action.use_fake_user = True
        for layer in action.layers:
            for strip in layer.strips:
                for slot in action.slots:
                    try:
                        channelbag = strip.channelbag(slot)
                    except (AttributeError, TypeError):
                        channelbag = None
                    if channelbag is not None:
                        for curve in channelbag.fcurves:
                            for point in curve.keyframe_points:
                                point.interpolation = "BEZIER"
        actions.append(action.name)
    arm.animation_data.action = None
    scene.frame_set(1)
    return actions


def _look_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def _set_preview(scene: bpy.types.Scene, collection: bpy.types.Collection, role: str, data: dict[str, Any], arm: bpy.types.Object, mesh_obj: bpy.types.Object) -> None:
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = os.path.join(EVIDENCE_DIR if data["task"] == "ASSET09" else CROWD_EVIDENCE_DIR, role + "_front.png")
    world = scene.world or bpy.data.worlds.new("PRV_%s_World" % role)
    scene.world = world
    world.color = (0.035, 0.045, 0.065)
    scene.view_settings.view_transform = "AgX"
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.09, 0.11, 0.16, 1)
    background.inputs["Strength"].default_value = 0.45
    camera_data = bpy.data.cameras.new("PRV_%s_Camera" % role)
    camera = bpy.data.objects.new("PRV_%s_Camera" % role, camera_data)
    collection.objects.link(camera)
    camera.location = (0.18, -6.5, 1.28)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.2 if data["height"] < 1.85 else 2.42
    _look_at(camera, Vector((0, 0, data["height"] * 0.51)))
    scene.camera = camera
    for name, location, power, color, size in (
        ("Key", (-3.4, -4.0, 5.2), 520, (0.65, 0.86, 1.0), 3.8),
        ("Warm", (3.0, -1.8, 2.8), 360, (1.0, 0.45, 0.21), 2.3),
        ("Rim", (0.3, 2.2, 4.0), 640, (0.12, 0.65, 0.86), 2.8),
    ):
        light_data = bpy.data.lights.new("PRV_%s_%s" % (role, name), "AREA")
        light_data.energy = power
        light_data.color = color
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(light_data.name, light_data)
        light.location = location
        _look_at(light, Vector((0, 0, 1.0)))
        collection.objects.link(light)
    scene.camera.data.lens = 50


def _make_rigged_character(role: str) -> tuple[bpy.types.Scene, bpy.types.Object, bpy.types.Object, dict[str, Any]]:
    data = ROLE_DATA[role]
    s = data["height"] / 1.72
    scene = bpy.context.scene
    collection = bpy.data.collections.new("ASSET_%s_Character" % role.upper())
    scene.collection.children.link(collection)
    mats, material_indices = _make_material_set(role, data)
    builder = MeshBuilder.create()
    _add_person(builder, role, s, material_indices, data)
    mesh = bpy.data.meshes.new("CHR_%s_Mesh" % role.upper())
    mesh.from_pydata(builder.vertices, [], builder.faces)
    mesh.update()
    for material in mats:
        mesh.materials.append(material)
    bmesh_data = bmesh.new()
    bmesh_data.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bmesh_data, faces=list(bmesh_data.faces))
    bmesh_data.to_mesh(mesh)
    bmesh_data.free()
    for polygon, mat_index in zip(mesh.polygons, builder.material_ids):
        polygon.material_index = mat_index
        polygon.use_smooth = True
    mesh.uv_layers.new(name="UV0")
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    mesh_obj = bpy.data.objects.new("CHR_%s_Render" % role.upper(), mesh)
    collection.objects.link(mesh_obj)
    bpy.context.view_layer.objects.active = mesh_obj
    mesh_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.004, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    arm = _skeleton(scene, role, s, collection)
    arm.location.z = -0.035
    mesh_obj.parent = arm
    mesh_obj.parent = arm
    groups: dict[str, bpy.types.VertexGroup] = {}
    for bone_name in set(builder.bone_names):
        groups[bone_name] = mesh_obj.vertex_groups.new(name=bone_name)
    indices_by_bone: dict[str, list[int]] = {}
    for index, bone_name in enumerate(builder.bone_names):
        indices_by_bone.setdefault(bone_name, []).append(index)
    for bone_name, indices in indices_by_bone.items():
        groups[bone_name].add(indices, 1.0, "REPLACE")
    skin = mesh_obj.modifiers.new("SKIN_%s" % role, "ARMATURE")
    skin.object = arm
    # A small post-skin bevel softens armor panel edges while retaining game scale.
    bevel = mesh_obj.modifiers.new("EDGE_SOFTEN_%s" % role, "BEVEL")
    bevel.width = 0.006 * s
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(38)
    scene.frame_start = 1
    scene.frame_end = 24
    scene.render.fps = 24
    actions = _build_animation(arm, scene, role)
    _set_preview(scene, collection, role, data, arm, mesh_obj)
    tris = sum(len(polygon.vertices) - 2 for polygon in mesh.polygons)
    result = {
        "role": role, "label": data["label"], "height_m": round(data["height"], 3),
        "vertices": len(mesh.vertices), "faces": len(mesh.polygons), "triangles": tris,
        "materials": [material.name for material in mats], "clips": actions,
        "uv_layers": len(mesh.uv_layers),
    }
    return scene, arm, mesh_obj, result


def _export_scene_glb(scene: bpy.types.Scene, output_path: str, arm: bpy.types.Object, mesh_obj: bpy.types.Object) -> dict[str, Any]:
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    window = bpy.context.window
    old_scene = window.scene if window is not None else None
    if window is not None:
        window.scene = scene
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    arm.select_set(True)
    mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    result = bpy.ops.export_scene.gltf(
        filepath=output_path, export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
        export_apply=False, export_force_sampling=True,
        export_cameras=False, export_lights=False, export_materials="EXPORT",
        export_image_format="AUTO", export_texcoords=True, export_normals=True,
        export_tangents=False, export_attributes=False,
    )
    if window is not None and old_scene is not None:
        window.scene = old_scene
    if "FINISHED" not in result:
        raise RuntimeError("glTF export failed for %s: %s" % (scene.name, result))
    return {"path": output_path, "bytes": os.path.getsize(output_path)}


def _write_sources(groups: dict[str, list[bpy.types.Collection]]) -> list[dict[str, Any]]:
    sources: list[dict[str, Any]] = []
    for filename, scenes in groups.items():
        path = os.path.join(SOURCE_DIR, "crowd", filename) if "crowd" in filename else os.path.join(SOURCE_DIR, filename)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        included: set[Any] = set(scenes)
        for collection in scenes:
            objects = set(collection.all_objects)
            included.update(objects)
            included.update(obj.data for obj in objects if obj.data is not None)
            included.update(material for obj in objects if obj.type == "MESH" for material in obj.data.materials if material is not None)
            included.update(image for material in bpy.data.materials if material.users > 0 for node in material.node_tree.nodes if node.type == "TEX_IMAGE" for image in [node.image] if image is not None)
            prefix = collection.name.removesuffix("_Character").replace("ASSET_", "").lower()
            included.update(action for action in bpy.data.actions if action.name.startswith(prefix + "_"))
        bpy.data.libraries.write(path, included, fake_user=True, path_remap="RELATIVE_ALL")
        sources.append({"path": path, "bytes": os.path.getsize(path)})
    return sources


def _render_previews(records: list[tuple[bpy.types.Scene, str, str]]) -> list[dict[str, Any]]:
    previews: list[dict[str, Any]] = []
    window = bpy.context.window
    old_scene = window.scene if window is not None else None
    for scene, role, task in records:
        output_dir = EVIDENCE_DIR if task == "ASSET09" else CROWD_EVIDENCE_DIR
        os.makedirs(output_dir, exist_ok=True)
        scene.render.filepath = os.path.join(output_dir, "%s_material.png" % role)
        scene.camera = bpy.data.objects.get("PRV_%s_Camera" % role)
        active_collection = bpy.data.collections.get("ASSET_%s_Character" % role.upper())
        visible_objects = set(active_collection.all_objects) if active_collection is not None else set()
        previous_visibility = {obj: obj.hide_render for obj in scene.objects}
        for obj in scene.objects:
            obj.hide_render = obj not in visible_objects
        if window is not None:
            window.scene = scene
        scene.frame_set(1)
        bpy.ops.render.render(write_still=True)
        for obj, hidden in previous_visibility.items():
            obj.hide_render = hidden
        previews.append({"path": scene.render.filepath, "bytes": os.path.getsize(scene.render.filepath)})
    if window is not None and old_scene is not None:
        window.scene = old_scene
    return previews


def build_night_market_characters() -> dict[str, Any]:
    os.makedirs(SOURCE_DIR, exist_ok=True)
    os.makedirs(ASSET_DIR, exist_ok=True)
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    os.makedirs(CROWD_EVIDENCE_DIR, exist_ok=True)
    roles = ["mara_vega", "market_security", "market_vendor", "market_courier"]
    scene = bpy.context.scene
    # Re-runs replace only builder-owned character collections and prefixed actions.
    for collection in list(bpy.data.collections):
        if collection.name.startswith("ASSET_") and collection.name.endswith("_Character"):
            for obj in list(collection.all_objects):
                bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.collections.remove(collection, do_unlink=True)
    for action in list(bpy.data.actions):
        if any(action.name.startswith(role + "_") for role in roles):
            bpy.data.actions.remove(action)
    for material in list(bpy.data.materials):
        if any(material.name.startswith(role + "_") for role in roles):
            bpy.data.materials.remove(material)
    for image in list(bpy.data.images):
        if any(image.name.startswith(role + "_") for role in roles):
            bpy.data.images.remove(image)
    collections: dict[str, bpy.types.Collection] = {}
    arms: dict[str, bpy.types.Object] = {}
    results: list[dict[str, Any]] = []
    exports: list[dict[str, Any]] = []
    previews: list[tuple[bpy.types.Scene, str, str]] = []
    source_groups: dict[str, list[bpy.types.Collection]] = {"night_market_characters.blend": [], "night_market_crowd.blend": []}
    for role in roles:
        _character_scene, arm, _mesh, facts = _make_rigged_character(role)
        collection = bpy.data.collections.get("ASSET_%s_Character" % role.upper())
        collections[role] = collection
        arms[role] = arm
        results.append(facts)
        task = ROLE_DATA[role]["task"]
        source_groups["night_market_characters.blend" if task == "ASSET09" else "night_market_crowd.blend"].append(collection)
        output_dir = ASSET_DIR if task == "ASSET09" else os.path.join(ASSET_DIR, "crowd")
        exports.append(_export_scene_glb(bpy.context.scene, os.path.join(output_dir, "%s.glb" % role), arm, _mesh))
        previews.append((bpy.context.scene, role, task))
    sources = _write_sources(source_groups)
    preview_results = _render_previews(previews)
    return {
        "blender": bpy.app.version_string,
        "roles": results,
        "source_files": sources,
        "glb_files": exports,
        "previews": preview_results,
    }


if __name__ == "__main__":
    print(build_night_market_characters())
