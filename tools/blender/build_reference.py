#!/usr/bin/env python3
"""Build two deterministic Stage 0 cyberpunk art references in Blender 5.2.

Run from the repository root:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
    --python-exit-code 1 --python tools/blender/build_reference.py
Creates editable .blend sources and JSON build metrics under art/reference and
player-height review renders under docs/evidence/ASSET-02.
"""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "reference"
EVIDENCE = ROOT / "docs" / "evidence" / "ASSET-02"
PALETTE = {
    "concrete": ((0.115, 0.145, 0.16, 1), 0.0, 0.88),
    "dark_metal": ((0.045, 0.065, 0.075, 1), 0.0, 0.58),
    "paint": ((0.10, 0.23, 0.25, 1), 0.0, 0.48),
    "metal": ((0.52, 0.57, 0.58, 1), 1.0, 0.34),
    "amber": ((0.95, 0.34, 0.055, 1), 0.0, 0.42),
    "teal": ((0.025, 0.48, 0.43, 1), 0.0, 0.32),
    "rubber": ((0.025, 0.032, 0.035, 1), 0.0, 0.82),
    "glass": ((0.025, 0.16, 0.18, 1), 0.0, 0.22),
}

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(datablocks):
            if item.users == 0:
                datablocks.remove(item)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0
    sc.unit_settings.length_unit = "METERS"
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = 1100
    sc.render.resolution_y = 760
    sc.render.resolution_percentage = 100
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "BOTH"
    sc.view_settings.view_transform = "AgX"
    return sc

def material(key, suffix):
    color, metallic, rough = PALETTE[key]
    name = f"M_{suffix}_{key.title()}"
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return mat

def make_object(name, verts, faces, mats, assignments=None, role="render", asset_id=""):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update(calc_edges=True)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    for key in mats:
        ob.data.materials.append(material(key, asset_id))
    if assignments:
        for poly, idx in zip(mesh.polygons, assignments):
            poly.material_index = idx
    ob["asset_id"] = asset_id
    ob["asset_role"] = role
    ob["units"] = "meters"
    # Each polygon receives a distinct, padded atlas cell. This avoids hidden
    # overlaps while keeping a usable 0-1 UV set for later texturing.
    uv = mesh.uv_layers.new(name="UVMap")
    cols = math.ceil(math.sqrt(len(mesh.polygons)))
    rows = math.ceil(len(mesh.polygons) / cols)
    gutter = 0.035
    for i, poly in enumerate(mesh.polygons):
        x, y = i % cols, i // cols
        u0, v0 = x / cols + gutter / cols, y / rows + gutter / rows
        u1, v1 = (x + 1) / cols - gutter / cols, (y + 1) / rows - gutter / rows
        coords = ((u0,v0),(u1,v0),(u1,v1),(u0,v1))
        for j, loop_idx in enumerate(poly.loop_indices):
            uv.data[loop_idx].uv = coords[j % 4]
    return ob

def box(name, center, size, mat, asset_id, role="render", bevel=0.025, segments=2):
    cx, cy, cz = center
    sx, sy, sz = (v / 2 for v in size)
    verts = [(x,y,z) for z in (-sz,sz) for y in (-sy,sy) for x in (-sx,sx)]
    faces = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)]
    ob = make_object(name, verts, faces, [mat], asset_id=asset_id, role=role)
    ob.location=(cx,cy,cz)
    if bevel:
        mod = ob.modifiers.new("EdgeSoftening", "BEVEL")
        mod.width, mod.segments = min(bevel, min(size) * 0.12), segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(25)
        mod.harden_normals = True
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.select_set(False)
    unwrap_object(ob)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob

def unwrap_object(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.015)
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.select_set(False)

def cylinder(name, center, radius, depth, mat, asset_id, axis="Y", verts=16, role="render"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center)
    ob = bpy.context.object
    ob.name = name
    ob.data.name = name + "_Mesh"
    if axis == "X": ob.rotation_euler[1] = math.pi / 2
    elif axis == "Y": ob.rotation_euler[0] = math.pi / 2
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    ob.data.materials.append(material(mat, asset_id))
    ob["asset_id"], ob["asset_role"], ob["units"] = asset_id, role, "meters"
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    # Existing primitive UVs are replaced by a clean unwrap after beveling.
    cols = math.ceil(math.sqrt(len(ob.data.polygons))); rows = math.ceil(len(ob.data.polygons)/cols)
    for i,p in enumerate(ob.data.polygons):
        x,y=i%cols,i//cols; g=.035
        c=((x/cols+g/cols,y/rows+g/rows),((x+1)/cols-g/cols,y/rows+g/rows),((x+1)/cols-g/cols,(y+1)/rows-g/rows),(x/cols+g/cols,(y+1)/rows-g/rows))
        for j,li in enumerate(p.loop_indices): uv.data[li].uv=c[j%4]
    bevel = ob.modifiers.new("EdgeSoftening", "BEVEL"); bevel.width=min(radius*.08,depth*.12,.018); bevel.segments=2
    bpy.context.view_layer.objects.active=ob; ob.select_set(True); bpy.ops.object.modifier_apply(modifier=bevel.name); ob.select_set(False)
    unwrap_object(ob)
    return ob

def arch_wall(asset_id="env_wall_doorway_a"):
    # One closed, connected wall shell with an actual 1.5 x 2.25 m traversable opening.
    # Coordinates: modular 4.0 x 3.4 m piece, 0.30 m thick, lower SW corner at origin.
    x0,x1,x2,x3=0.0,1.25,2.75,4.0
    z0,z1,z2=0.0,2.25,3.4
    y0,y1=-0.15,0.15
    v=[]
    # Front/back vertex sets: regions left, header, right, sharing perimeter coordinates.
    front=[(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x1,y0,z2),(x0,y0,z2),
           (x2,y0,z1),(x2,y0,z2),(x3,y0,z2),(x3,y0,z0),(x2,y0,z0)]
    back=[(x,y1,z) for x,y,z in front]
    v=front+back
    # Front and back surfaces as three regions; side quads close outer perimeter and aperture.
    # Front tiles split each jamb around a connected header. Triangles avoid n-gons.
    faces=[(0,1,2,3,4),(2,3,6,5),(5,6,7,8,9)]
    for face in list(faces): faces.append(tuple(i+10 for i in reversed(face)))
    boundaries=[(0,1),(9,8),(8,7),(7,6),(6,3),(3,4),(4,0),
                (1,2),(2,5),(5,9)]
    # Correct face split: front rings are left jamb, header, right jamb; side closures include
    # the outer perimeter and doorway reveal. All surfaces meet edge-to-edge.
    for a,b in boundaries:
        faces.append((a,b,b+10,a+10))
    # Build material assignments on front/back/sides. Face normals recalculated after creation.
    assignments=[0]*6 + [1]*len(boundaries)
    wall=make_object("ENV_WallDoorway_A",v,faces,["concrete","dark_metal"],
                     assignments,asset_id=asset_id)
    # Correct normals on closed shell with bmesh before adding non-destructive bevel.
    import bmesh
    bm=bmesh.new(); bm.from_mesh(wall.data); bmesh.ops.triangulate(bm, faces=bm.faces[:]); bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:]); bm.to_mesh(wall.data); bm.free()
    wall.data.update(); unwrap_object(wall)
    # Outer architectural framing with purposeful reveals and painted industrial bands.
    box("ENV_DoorFrame_Left",(1.20,-.205,1.125),(.10,.11,2.25),"dark_metal",asset_id,bevel=.012)
    box("ENV_DoorFrame_Right",(2.80,-.205,1.125),(.10,.11,2.25),"dark_metal",asset_id,bevel=.012)
    box("ENV_DoorLintel",(2.0,-.205,2.30),(1.50,.11,.10),"paint",asset_id,bevel=.012)
    box("ENV_Threshold",(2.0,-.01,.035),(1.50,.46,.07),"metal",asset_id,role="render",bevel=.012)
    # Protected conduit and service plate on the right pier, safely outside opening.
    box("ENV_ServicePlate",(3.57,-.205,1.72),(.56,.045,.66),"dark_metal",asset_id,bevel=.025)
    box("ENV_ServicePlateInset",(3.57,-.238,1.72),(.43,.025,.48),"paint",asset_id,bevel=.018)
    for label,z,col in (("Upper",1.87,"teal"),("Middle",1.72,"amber"),("Lower",1.57,"teal")):
        box(f"ENV_StatusLamp_{label}",(3.57,-.258,z),(.22,.018,.045),col,asset_id,bevel=.006)
    for label,z in zip(("A","B","C"),(.52,.70,.88)):
        cylinder(f"ENV_ConduitCollar_{label}",(3.22,-.155,z),.052,.07,"metal",asset_id,axis="Y",verts=12)
    # A clearly separate, oversized doorway frame assembly is intentional and readable.
    # Render proxy uses solid frame; collision pieces approximate walkable wall masses.
    for proxy in (
        box("COL_Wall_Left",(.625,0,1.7),(1.25,.3,3.4),"rubber",asset_id,"collision",bevel=0),
        box("COL_Wall_Right",(3.375,0,1.7),(1.25,.3,3.4),"rubber",asset_id,"collision",bevel=0),
        box("COL_Wall_Header",(2.0,0,2.825),(1.5,.3,1.15),"rubber",asset_id,"collision",bevel=0),
        box("COL_Threshold",(2.0,0,.025),(1.5,.3,.05),"rubber",asset_id,"collision",bevel=0)):
        proxy.hide_render=True

def build_wall():
    clear_scene(); arch_wall()
    save=OUT/"wall_doorway.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(save))
    return save

def build_prop():
    asset_id="prop_utility_junction_a"
    clear_scene()
    # 0.92 x 0.60 x 1.28 m wall-mounted service junction, pivot at ground center.
    # Chassis back panel; all components are solid and intentionally seated/intersected.
    box("PRP_Junction_Chassis",(0,0.02,.64),(.92,.34,1.28),"dark_metal",asset_id,bevel=.055)
    box("PRP_FrontFace",(0,-.165,.66),(.82,.055,1.13),"paint",asset_id,bevel=.035)
    box("PRP_ServiceDoor",(-.205,-.207,.68),(.39,.045,.79),"dark_metal",asset_id,bevel=.025)
    box("PRP_DoorInset",(-.205,-.235,.68),(.31,.025,.66),"paint",asset_id,bevel=.018)
    # Gasket strips, fasteners and access catch.
    for i,(x,z) in enumerate(((-.37,.34),(-.04,.34),(-.37,1.02),(-.04,1.02)),1):
        cylinder(f"PRP_Fastener_{i:02d}",(x,-.258,z),.018,.02,"metal",asset_id,axis="Y",verts=10)
    box("PRP_Latch",(-.02,-.245,.68),(.035,.06,.15),"metal",asset_id,bevel=.008)
    # Right side gauge bay, lens bezel, glass face, and radial needle.
    cylinder("PRP_GaugeBezel",(.215,-.225,.82),.205,.08,"metal",asset_id,axis="Y",verts=32)
    cylinder("PRP_GaugeFace",(.215,-.273,.82),.166,.025,"glass",asset_id,axis="Y",verts=32)
    cylinder("PRP_GaugeHub",(.215,-.291,.82),.025,.014,"amber",asset_id,axis="Y",verts=12)
    # Gauge ticks as small, discrete solid bars on the face.
    for i in range(9):
        a=math.radians(-130+i*32.5)
        x=.215+math.sin(a)*.125; z=.82+math.cos(a)*.125
        tick=box(f"PRP_GaugeTick_{i+1:02d}",(x,-.293,z),(.012,.012,.037),"metal",asset_id,bevel=.003)
        tick.rotation_euler[1]=a
    # Heavy lower cable gland and protected conduit; closed, gameplay-safe silhouette.
    cylinder("PRP_CableGland",(.22,-.205,.12),.105,.16,"metal",asset_id,axis="Y",verts=16)
    cylinder("PRP_Conduit",(.22,-.335,.12),.058,.16,"rubber",asset_id,axis="Y",verts=12)
    # Top vent and distinct protective hood; slots remain readable at close-up scale.
    box("PRP_VentBlock",(-.2,-.21,1.13),(.36,.07,.18),"dark_metal",asset_id,bevel=.018)
    for label,z in zip(("A","B","C"),(1.085,1.125,1.165)):
        box(f"PRP_VentSlot_{label}",(-.2,-.252,z),(.26,.015,.012),"metal",asset_id,bevel=.004)
    # Three-column status strip with intentional teal/amber status hierarchy.
    for label,z,col in (("Lower",.39,"teal"),("Middle",.46,"teal"),("Upper",.53,"amber")):
        box(f"PRP_StatusLamp_{label}",(.205,-.205,z),(.09,.05,.036),col,asset_id,bevel=.007)
    # Separate, named collision proxies: chassis mass and cable exclusion volume.
    for proxy in (
        box("COL_Junction_Body",(0,0,.64),(.92,.34,1.28),"rubber",asset_id,"collision",bevel=0),
        box("COL_Junction_Cable",(.22,-.28,.12),(.16,.44,.16),"rubber",asset_id,"collision",bevel=0)):
        proxy.hide_render=True
    # Assign stable bottom-center origin to the assembly without changing world geometry.
    root=bpy.data.objects.new("PRP_UtilityJunction_Pivot",None); bpy.context.collection.objects.link(root)
    root.location=(0,0,0); root.empty_display_type="PLAIN_AXES"; root.empty_display_size=.16
    root["asset_id"]=asset_id; root["asset_role"]="pivot_marker"
    save=OUT/"mechanical_prop.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(save))
    return save

def render_player_view(path, kind):
    sc=bpy.context.scene
    camera_data=bpy.data.cameras.new("Review_PlayerEye_Camera")
    camera=bpy.data.objects.new("Review_PlayerEye_Camera",camera_data); sc.collection.objects.link(camera)
    sc.camera=camera
    camera_data.lens=46
    if kind=="wall":
        camera.location=(2.0,-5.6,1.65); target=Vector((2.0,0,1.65)); camera_data.lens=38
    else:
        camera.location=(1.55,-2.25,1.65); target=Vector((0,-.05,.67)); camera_data.lens=52
    camera.rotation_euler=(target- camera.location).to_track_quat("-Z","Y").to_euler()
    # Soft, neutral review light; a secondary teal/amber bounce separates materials.
    for name, loc, power, color, size in (("Key",(2,-4,5),900,(.76,.86,1.0),4.0),("WarmFill",(-3,-2,2.6),450,(1,.39,.17),2.5)):
        data=bpy.data.lights.new(name,"AREA"); data.energy=power; data.color=color; data.shape="DISK"; data.size=size
        light=bpy.data.objects.new(name,data); sc.collection.objects.link(light); light.location=loc
        light.rotation_euler=(Vector((2,0,1.6))-light.location).to_track_quat("-Z","Y").to_euler()
    sc.render.engine="BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in {i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items} else "BLENDER_EEVEE"
    sc.render.resolution_x,sc.render.resolution_y,sc.render.resolution_percentage=1280,900,100
    sc.render.image_settings.file_format="PNG"; sc.render.filepath=str(path)
    sc.render.film_transparent=False
    sc.world.color=(.055,.065,.075)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera,do_unlink=True); bpy.data.cameras.remove(camera_data)
    for name in ("Key","WarmFill"):
        obj=bpy.data.objects.get(name)
        if obj:
            data=obj.data; bpy.data.objects.remove(obj,do_unlink=True); bpy.data.lights.remove(data)

def metrics(path):
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    deps=bpy.context.evaluated_depsgraph_get()
    out=[]
    for ob in meshes:
        ev=ob.evaluated_get(deps); me=ev.to_mesh()
        tris=sum(len(p.vertices)-2 for p in me.polygons)
        dims=tuple(round(v,4) for v in ob.dimensions)
        ev.to_mesh_clear()
        out.append({"object":ob.name,"role":ob.get("asset_role","render"),"dims_m":dims,
                    "tris_evaluated":tris,"materials":len(ob.material_slots),"uv_maps":len(ob.data.uv_layers)})
    return {"blender":bpy.app.version_string,"source":str(path),"objects":out,
            "triangles_total":sum(o["tris_evaluated"] for o in out),
            "mesh_objects":len(meshes),"materials":len({m.name for o in meshes for m in o.data.materials})}

if __name__=="__main__":
    OUT.mkdir(parents=True,exist_ok=True); EVIDENCE.mkdir(parents=True,exist_ok=True)
    for kind,builder in (("wall",build_wall),("prop",build_prop)):
        src=builder()
        render_player_view(EVIDENCE/("wall_player_eye.png" if kind=="wall" else "prop_player_eye.png"),kind)
        info=metrics(src)
        (EVIDENCE/(kind+"_metrics.json")).write_text(json.dumps(info,indent=2)+"\n")
        print("REFERENCE_BUILD "+json.dumps({"kind":kind,"source":str(src),"bytes":src.stat().st_size,
              "triangles":info["triangles_total"],"objects":info["mesh_objects"],"materials":info["materials"]},sort_keys=True))
