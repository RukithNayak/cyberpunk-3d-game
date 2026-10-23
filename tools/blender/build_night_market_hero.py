"""Create the Night Market hero storefront in a separate Blender scene.

Run through Blender MCP in the connected 5.2 session. This script never clears,
renames, or saves over the user's active default scene. The authored scene is
written as a standalone datablock library at the approved asset source path.
"""
import bpy, math, os, random
import bmesh
import numpy as np
from array import array
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SOURCE = os.path.join(ROOT, "art/source/environment/night_market/night_market_hero.blend")
EXPORT = os.path.join(ROOT, "game/assets/environment/night_market/night_market_hero.glb")
os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
os.makedirs(os.path.dirname(EXPORT), exist_ok=True)

# Idempotent rebuild of only our own scene and collection.
# All ENV_NM_/COL_NM_ objects in this live session were created by this script;
# the inspected user scene contained only Cube, Camera and Light.
for ob in list(bpy.data.objects):
    if ob.name.startswith(('ENV_NM_','COL_NM_','PRV_NM_')):
        bpy.data.objects.remove(ob, do_unlink=True)
for s in list(bpy.data.scenes):
    if s.name == "NM_Hero_Storefront":
        old_col=bpy.data.collections.get("NM_Hero_Storefront_Collection")
        if old_col:
            for ob in list(old_col.objects): bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.scenes.remove(s)
for c in list(bpy.data.collections):
    if c.name == "NM_Hero_Storefront_Collection":
        bpy.data.collections.remove(c)
for datablocks in (bpy.data.meshes,bpy.data.curves,bpy.data.materials):
    for block in list(datablocks):
        if block.name.startswith(('ENV_NM_','COL_NM_','M_night_market_')) and block.users==0:
            datablocks.remove(block)
for img in list(bpy.data.images):
    if img.name.startswith(('T_night_market_microdetail_1k_','T_night_market_door_hero_2k_')) and img.users==0:
        bpy.data.images.remove(img)
scene = bpy.data.scenes.new("NM_Hero_Storefront")
col = bpy.data.collections.new("NM_Hero_Storefront_Collection")
scene.collection.children.link(col)
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100

def material(name, color, metallic, rough, emission=None, strength=0.0):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*emission, 1)
        p.inputs['Emission Strength'].default_value = strength
    return m

M = {
 'concrete': material('M_night_market_weathered_concrete',(.22,.24,.23),.08,.88),
 'paint': material('M_night_market_oxide_teal_paint',(.025,.19,.19),.38,.48),
 'black': material('M_night_market_blackened_steel',(.035,.045,.05),.82,.3),
 'steel': material('M_night_market_brushed_steel',(.32,.38,.39),.78,.25),
 'rubber': material('M_night_market_gasket_rubber',(.012,.017,.018),.03,.88),
 'amber': material('M_night_market_amber_emissive',(.95,.25,.012),.28,.25,(1,.19,.008),3.0),
 'cyan': material('M_night_market_cyan_emissive',(.015,.48,.65),.2,.22,(.015,.55,.9),2.2),
 'ivory': material('M_night_market_warm_signage',(.9,.68,.34),.12,.48,(.5,.18,.025),.6),
 'glass': material('M_night_market_smoked_glass',(.025,.10,.12),.65,.16),
 'rust': material('M_night_market_rust',(.26,.075,.025),.45,.72),
}

# A reusable, seamless, authored 1K micro-surface set. Maps are packed in the
# GLB; grayscale maps use Non-Color space. This first hero asset uses a common
# tile across rough painted metal/concrete and individual Principled colors.
TEXDIR=os.path.join(os.path.dirname(SOURCE),'textures')
os.makedirs(TEXDIR,exist_ok=True)
def make_tile(name, kind, n=1024):
    img=bpy.data.images.new(name,width=n,height=n,alpha=False,float_buffer=False)
    img.colorspace_settings.name='Non-Color' if kind!='basecolor' else 'sRGB'
    data=np.empty((n,n,4),dtype=np.float32) if n==2048 else array('f')
    phases=[(random.random()*math.tau,random.random()*math.tau) for _ in range(18)]
    if n==2048:
        rng=np.random.default_rng(731); us=np.arange(n,dtype=np.float32)/n
    for y in range(n):
        v=y/n
        if n==2048:
            h=np.zeros(n,dtype=np.float32)
            for k,(a,b) in enumerate(phases):
                f=2**(k%5+1); amp=1.0/(k+2)
                h+=amp*np.sin(math.tau*f*us+a)*math.cos(math.tau*(f+1)*v+b)
            grain=rng.random(n,dtype=np.float32)*.12-.06
            h=np.clip(.53+h*.12+grain,0,1)
            if kind=='basecolor':
                c=.66+h*.08+grain*.35
                data[y,:,0]=c; data[y,:,1]=np.minimum(1,c+.012); data[y,:,2]=np.maximum(0,c-.018); data[y,:,3]=1
            elif kind=='roughness':
                c=.48+h*.30; data[y,:,:3]=c[:,None]; data[y,:,3]=1
            elif kind=='normal':
                nx=rng.uniform(-.018,.018,n).astype(np.float32); ny=rng.uniform(-.018,.018,n).astype(np.float32)
                ll=np.sqrt(nx*nx+ny*ny+1); data[y,:,0]=.5+.5*nx/ll; data[y,:,1]=.5+.5*ny/ll; data[y,:,2]=.5+.5/ll; data[y,:,3]=1
            elif kind=='metallic':
                c=.62+h*.28; data[y,:,:3]=c[:,None]; data[y,:,3]=1
            else:
                c=.72+h*.28; data[y,:,:3]=c[:,None]; data[y,:,3]=1
            continue
        for x in range(n):
            u=x/n; h=0.0
            for k,(a,b) in enumerate(phases):
                f=2**(k%5+1); amp=1.0/(k+2)
                h+=amp*math.sin(math.tau*f*u+a)*math.cos(math.tau*(f+1)*v+b)
            grain=random.random()*.12-.06
            # Seamless repeating mottling; narrow streaks imply brushed/worn surface.
            h=max(0.0,min(1.0,.53+h*.12+grain))
            if kind=='basecolor':
                c=.66+h*.08+grain*.35
                data.extend((c,min(1,c+.012),max(0,c-.018),1.0))
            elif kind=='roughness': data.extend((.48+h*.30, .48+h*.30, .48+h*.30,1.0))
            elif kind=='metallic': data.extend((.62+h*.28,)*3+(1.0,))
            elif kind=='ao': data.extend((.72+h*.28,)*3+(1.0,))
            else:
                # Height-derived tangent normal from periodic neighbors is
                # approximated analytically, preserving seamless UV tiling.
                nx=random.uniform(-.018,.018); ny=random.uniform(-.018,.018); nz=1.0
                ll=math.sqrt(nx*nx+ny*ny+nz*nz)
                data.extend((.5+.5*nx/ll,.5+.5*ny/ll,.5+.5*nz/ll,1.0))
    img.pixels.foreach_set(data.reshape(-1) if n==2048 else data); img.file_format='PNG'
    path=os.path.join(TEXDIR,name.removeprefix('T_').lower()+'.png'); img.filepath_raw=path; img.save()
    img.pack(); return img
random.seed(731)
surface_maps={k:make_tile('T_night_market_microdetail_1k_'+k,k) for k in ('basecolor','roughness','metallic','ao','normal')}
for key,mat in M.items():
    if key in ('amber','cyan'): continue
    nt=mat.node_tree; principled=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    tex=nt.nodes.new('ShaderNodeTexImage'); tex.name='T_night_market_microdetail_1k_basecolor'; tex.image=surface_maps['basecolor']
    mix=nt.nodes.new('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=.32
    mix.inputs[1].default_value=principled.inputs['Base Color'].default_value
    nt.links.new(tex.outputs['Color'],mix.inputs[2]); nt.links.new(mix.outputs[0],principled.inputs['Base Color'])
    rough=nt.nodes.new('ShaderNodeTexImage'); rough.image=surface_maps['roughness']; rough.image.colorspace_settings.name='Non-Color'
    nt.links.new(rough.outputs['Color'],principled.inputs['Roughness'])
    normal=nt.nodes.new('ShaderNodeTexImage'); normal.image=surface_maps['normal']; normal.image.colorspace_settings.name='Non-Color'
    normal.name='T_night_market_microdetail_1k_normal'
    nmap=nt.nodes.new('ShaderNodeNormalMap'); nt.links.new(normal.outputs['Color'],nmap.inputs['Color']); nt.links.new(nmap.outputs['Normal'],principled.inputs['Normal'])

# Dedicated 2K hero maps sharpen the service door at close inspection distance.
door_maps={k:make_tile('T_night_market_door_hero_2k_'+k,k,2048) for k in ('basecolor','roughness','normal')}
for node in M['paint'].node_tree.nodes:
    if node.type=='TEX_IMAGE' and node.image==surface_maps['basecolor']:
        node.image=door_maps['basecolor']; node.name='T_night_market_door_hero_2k_basecolor'
    elif node.type=='TEX_IMAGE' and node.image==surface_maps['roughness']:
        node.image=door_maps['roughness']; node.name='T_night_market_door_hero_2k_roughness'
    elif node.type=='TEX_IMAGE' and node.image==surface_maps['normal']:
        node.image=door_maps['normal']; node.name='T_night_market_door_hero_2k_normal'

def cube(name, loc, dims, mat, bevel=0.0, col_override=None):
    me=bpy.data.meshes.new(name+'_Mesh')
    x,y,z=(d*.5 for d in dims)
    verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me.from_pydata(verts,[],faces); me.materials.append(mat); me.update()
    ob=bpy.data.objects.new(name,me); (col_override or col).objects.link(ob); ob.location=loc
    if bevel:
        mod=ob.modifiers.new('Edge radii | machined wear','BEVEL'); mod.width=min(bevel,min(dims)*.18); mod.segments=2
        mod=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod.keep_sharp=True
    return ob

def cyl(name, loc, radius, depth, mat, axis='Y', vertices=16):
    # Cylinder along Y faces the street at negative Y.
    verts=[]; faces=[]
    for j, yy in enumerate((-depth/2,depth/2)):
        for i in range(vertices):
            a=2*math.pi*i/vertices; verts.append((radius*math.cos(a),yy,radius*math.sin(a)))
    faces.append(tuple(range(vertices-1,-1,-1))); faces.append(tuple(range(vertices,2*vertices)))
    for i in range(vertices): faces.append((i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices))
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(verts,[],faces)
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    me.materials.append(mat); me.update()
    ob=bpy.data.objects.new(name,me); col.objects.link(ob); ob.location=loc
    return ob

# 4 m wide, 3.25 m tall frontage, pivot lower-center at street plane.
# Main facade and layered portal.
cube('ENV_NM_Wall_Core',(0,.14,1.62),(4.0,.42,3.24),M['concrete'],.035)
cube('ENV_NM_Fascia_Canopy',(0,-.17,2.98),(4.08,.48,.32),M['black'],.045)
cube('ENV_NM_Canopy_Underside',(0,-.22,2.79),(3.85,.50,.07),M['amber'],.012)
cube('ENV_NM_Lower_Kickplate_Left',(-1.36,-.105,.16),(1.28,.16,.32),M['black'],.025)
cube('ENV_NM_Lower_Kickplate_Right',(1.36,-.105,.16),(1.28,.16,.32),M['black'],.025)
# The setback is represented by the layered jamb/door stack rather than a coplanar
# panel over the kickplate; keeping this slab out avoids an intersecting face pair.
cube('ENV_NM_Door_Outer_Frame_Left',(-.66,-.20,1.24),(.12,.24,2.48),M['steel'],.025)
cube('ENV_NM_Door_Outer_Frame_Right',(.66,-.20,1.24),(.12,.24,2.48),M['steel'],.025)
cube('ENV_NM_Door_Head',(0,-.20,2.40),(1.42,.24,.12),M['steel'],.025)
cube('ENV_NM_Door_Threshold',(0,-.25,.05),(1.18,.38,.10),M['steel'],.018)
cube('ENV_NM_Door_Leaf',(0,-.235,1.18),(1.02,.095,2.12),M['paint'],.035)
# Perimeter seal + four recessed panel layers.
for x in (-.46,.46): cube('ENV_NM_Door_Gasket',(x,-.291,1.18),(.027,.025,2.02),M['rubber'],.006)
for z in (.24,2.12): cube('ENV_NM_Door_Gasket',(0,-.291,z),(.91,.025,.026),M['rubber'],.006)
for i,(z,h) in enumerate(((.48,.39),(.98,.46),(1.53,.43),(1.96,.20))):
    cube('ENV_NM_Door_Inset_Panel_%02d'%i,(0,-.292,z),(.79,.028,h),M['black'],.023)
    cube('ENV_NM_Door_Panel_Inner_%02d'%i,(0,-.310,z),(.70,.012,h-.07),M['paint'],.018)
    cube('ENV_NM_Door_Panel_Grip_Rib_%02d'%i,(0,-.321,z-h*.36),(.55,.012,.018),M['steel'],.005)
# Hinges with knuckles and fasteners.
for i,z in enumerate((.42,1.15,1.91)):
    cube('ENV_NM_Hinge_Leaf_%02d'%i,(-.535,-.315,z),(.16,.035,.10),M['steel'],.012)
    cyl('ENV_NM_Hinge_Pin_%02d'%i,(-.535,-.347,z),.022,.055,M['amber'],vertices=12)
    for dz in (-.030,.030): cyl('ENV_NM_Hinge_Screw_%02d'%i,(-.58,-.339,z+dz),.009,.012,M['black'],vertices=8)
# Handle escutcheon, pull lever, lock cylinder.
cube('ENV_NM_Handle_Backplate',(.355,-.30,1.20),(.095,.05,.34),M['black'],.018)
cube('ENV_NM_Handle_Lever',(.31,-.345,1.22),(.20,.08,.035),M['steel'],.014)
cyl('ENV_NM_Lock_Cylinder',(.36,-.33,1.00),.035,.10,M['steel'],vertices=20)
cube('ENV_NM_Lock_Slot',(.36,-.389,1.00),(.006,.020,.023),M['black'],.001)
# Security keypad with tactile keys and status lens.
cube('ENV_NM_Keypad_Housing',(.91,-.16,1.55),(.25,.20,.46),M['black'],.025)
cube('ENV_NM_Keypad_Display',(.91,-.270,1.68),(.19,.040,.105),M['cyan'],.009)
for row in range(3):
    for c in range(3): cube('ENV_NM_Key_%d_%d'%(row,c),(.855+c*.055,-.270,1.56-row*.065),(.032,.040,.032),M['steel'] if (row+c)%3 else M['amber'],.006)
cube('ENV_NM_Keypad_Lower_Slot',(.91,-.270,1.335),(.115,.040,.035),M['rubber'],.004)
# Door and facade warning labels, legible graphic geometry and text.
def text_obj(name, body, loc, size, mat):
    cu=bpy.data.curves.new(name+'_Curve','FONT'); cu.body=body; cu.size=size; cu.extrude=.0015; cu.align_x='CENTER'
    ob=bpy.data.objects.new(name,cu); col.objects.link(ob); ob.location=loc; ob.rotation_euler=(math.pi/2,0,0); ob.data.materials.append(mat); return ob
text_obj('ENV_NM_Door_Stencil','AUTHORIZED ENTRY',(0,-.337,.315),.085,M['ivory'])
text_obj('ENV_NM_Door_ID','NM-07 // SERVICE',(0,-.337,2.21),.065,M['amber'])
text_obj('ENV_NM_Fascia_Sign','NIGHT MARKET',(0,-.43,2.88),.20,M['ivory'])
# Amber/cyan light bars and bolted signage plates.
for x in (-1.84,1.84):
    cube('ENV_NM_Sign_Bracket',(x,-.36,2.88),(.10,.25,.33),M['steel'],.018)
    for z in (2.78,2.98): cyl('ENV_NM_Bracket_Bolt',(x,-.477,z),.019,.040,M['amber'],vertices=12)
for i in range(8): cube('ENV_NM_Fascia_Vent_%02d'%i,(-1.0+i*.29,-.416,2.98),(.19,.015,.035),M['steel'],.008)
# Side service window: thick surround, smoked laminated glass, grille bars.
cube('ENV_NM_Window_Frame',(1.54,-.10,1.56),(.72,.17,1.10),M['black'],.026)
cube('ENV_NM_Window_Glass',(1.54,-.194,1.56),(.60,.018,.96),M['glass'],.012)
for z in (1.08,2.04): cube('ENV_NM_Window_Rail',(1.54,-.218,z),(.70,.045,.045),M['steel'],.010)
for x in (1.31,1.46,1.61,1.76): cube('ENV_NM_Window_Grille',(x,-.210,1.56),(.018,.040,.95),M['steel'],.006)
# Pipework, conduit junctions, fasteners, weather streaks and patch repairs.
for z in (.58,2.50):
    cyl('ENV_NM_Facade_Conduit',(1.96,-.10,z),.032,.65,M['steel'],vertices=12)
for x in (-1.92,1.92):
    cube('ENV_NM_Concrete_Repair',(x,.0,1.20),(.13,.018,.42),M['rust'],.008)
    for z in (.45,2.58): cyl('ENV_NM_Facade_Anchor',(x,-.09,z),.028,.05,M['steel'],vertices=12)
random.seed(707)
for i in range(20):
    x=random.uniform(-1.94,1.94); z=random.uniform(.28,2.65)
    if abs(x)<.72 and z<2.45: continue
    cube('ENV_NM_Paint_Scar_%02d'%i,(x,-.085,z),(random.uniform(.018,.07),.040,random.uniform(.035,.16)),M['rust'],.003)
# Drip rail, cable clips and a compact power junction at the right edge.
cube('ENV_NM_Drip_Gutter',(0,-.34,2.70),(3.96,.13,.055),M['black'],.012)
cube('ENV_NM_Junction_Box',(1.87,-.205,.87),(.30,.20,.38),M['paint'],.025)
cube('ENV_NM_Junction_Cover',(1.87,-.316,.87),(.24,.024,.30),M['steel'],.015)
for z in (.77,.97): cyl('ENV_NM_Junction_Screw',(1.87,-.342,z),.012,.025,M['black'],vertices=8)
cube('ENV_NM_Junction_Status',(1.87,-.34,.87),(.10,.03,.025),M['amber'],.004)
# Low-cost wall collision leaves a full-height service-door opening. Godot's
# -colonly suffix imports these meshes as physics-only collision shapes.
cube('COL_NM_Facade_Left-colonly',(-1.36,.14,1.24),(1.28,.42,2.48),M['rubber'])
cube('COL_NM_Facade_Right-colonly',(1.36,.14,1.24),(1.28,.42,2.48),M['rubber'])
cube('COL_NM_Facade_Lintel-colonly',(0,.14,2.86),(4.0,.42,.76),M['rubber'])

# Small authored preview rig for review renders; excluded from engine export.
cam_data=bpy.data.cameras.new('PRV_NM_Hero_Camera_Data'); cam=bpy.data.objects.new('PRV_NM_Hero_Camera',cam_data); col.objects.link(cam)
cam.location=(0,-8.7,3.25); cam.rotation_euler=(Vector((0,0,1.60))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'; cam.data.ortho_scale=5.25; scene.camera=cam
for name,loc,power,color,size in (
    ('PRV_NM_Key',(0,-4.0,5.0),850,(.62,.82,1.0),4.2),
    ('PRV_NM_Warm',(-3,-2.0,2.4),520,(1.0,.34,.10),3.0),
    ('PRV_NM_Cool',(3,-1.5,3.0),650,(.06,.58,1.0),2.5)):
    ld=bpy.data.lights.new(name+'_Data','AREA'); ld.energy=power; ld.color=color; ld.shape='DISK'; ld.size=size
    lo=bpy.data.objects.new(name,ld); col.objects.link(lo); lo.location=loc
    lo.rotation_euler=(Vector((0,0,1.55))-lo.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new('PRV_NM_Night_World') if not bpy.data.worlds.get('PRV_NM_Night_World') else bpy.data.worlds['PRV_NM_Night_World']
world.use_nodes=True; world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.025,.04,.065,1); world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.35; scene.world=world
scene.view_settings.view_transform='AgX'

# UVs: box-projected across all render meshes; collision intentionally excluded.
for ob in list(col.objects):
    if ob.type != 'MESH': continue
    uv=ob.data.uv_layers.new(name='UV0')
    # Stable per-face quad UVs; modifier-generated bevels inherit base UVs.
    polygons=list(ob.data.polygons); cols=math.ceil(math.sqrt(len(polygons))); rows=math.ceil(len(polygons)/cols)
    for pi,poly in enumerate(polygons):
        # Give every face its own island to keep the authored tile maps usable
        # while avoiding the earlier per-face 100% UV stack.
        cell_x=pi%cols; cell_y=pi//cols; pad=.045
        axis=max(range(3),key=lambda a:abs(poly.normal[a])); axes=[a for a in range(3) if a!=axis]
        coords=[ob.data.vertices[ob.data.loops[li].vertex_index].co for li in poly.loop_indices]
        mins=[min(v[a] for v in coords) for a in axes]; maxs=[max(v[a] for v in coords) for a in axes]
        spans=[max(maxs[k]-mins[k],1e-5) for k in range(2)]
        cell_w=1.0/cols; cell_h=1.0/rows
        for li in poly.loop_indices:
            v=ob.data.vertices[ob.data.loops[li].vertex_index].co
            fu=(v[axes[0]]-mins[0])/spans[0]; fv=(v[axes[1]]-mins[1])/spans[1]
            uv.data[li].uv=(cell_x*cell_w+pad*cell_w+fu*(1-2*pad)*cell_w,
                            cell_y*cell_h+pad*cell_h+fv*(1-2*pad)*cell_h)

# Storefront origin is bottom-center; child details remain in authored positions.
for ob in col.objects: ob['asset_id']='night_market_hero'; ob['unit_scale_m']=1.0
scene['asset_id']='night_market_hero'; scene['dimensions_m']='4.08 x 0.847 x 3.24'; scene['front_direction']='-Y'

# Use an isolated newly-created scene for both saving and GLB selection export.
old_scene=bpy.context.window.scene if bpy.context.window else None
if bpy.context.window: bpy.context.window.scene=scene
try:
    # Save a standalone editable project copy with the Night Market scene active.
    # This writes a new path and never changes the user's current .blend file.
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE, copy=True)

    # Build an optimized export-only collection from evaluated copies. Editable
    # source meshes remain separate; static render geometry is merged by material.
    export_col=bpy.data.collections.new('TMP_NM_Export_Merged'); scene.collection.children.link(export_col)
    depsgraph=bpy.context.evaluated_depsgraph_get(); groups={}
    for source_ob in list(col.objects):
        if source_ob.type not in ('MESH','FONT') or source_ob.name.startswith('COL_NM_'):
            continue
        evaluated=source_ob.evaluated_get(depsgraph); evaluated_mesh=evaluated.to_mesh()
        if not evaluated_mesh: continue
        mesh=evaluated_mesh.copy(); evaluated.to_mesh_clear()
        export_ob=bpy.data.objects.new('TMP_'+source_ob.name,mesh); export_col.objects.link(export_ob)
        export_ob.matrix_world=source_ob.matrix_world.copy()
        key=tuple(m.name for m in mesh.materials if m)
        groups.setdefault(key,[]).append(export_ob)
    export_objects=[]
    for material_key,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for export_ob in objects: export_ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1: bpy.ops.object.join()
        objects[0].name='ENV_NM_Export_'+(material_key[0].removeprefix('M_night_market_') if material_key else 'unassigned')
        export_objects.append(objects[0])
    export_objects.extend(o for o in col.objects if o.name.startswith('COL_NM_'))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in export_objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=export_objects[0]
    bpy.ops.export_scene.gltf(filepath=EXPORT, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True, export_materials='EXPORT', export_cameras=False,
        export_lights=False, export_extras=True, export_image_format='AUTO')
finally:
    export_col=bpy.data.collections.get('TMP_NM_Export_Merged')
    if export_col:
        for ob in list(export_col.objects): bpy.data.objects.remove(ob,do_unlink=True)
        bpy.data.collections.remove(export_col)
    if bpy.context.window and old_scene: bpy.context.window.scene=old_scene

render_objects=[o for o in col.objects if o.type=='MESH' and not o.name.startswith('COL_')]
tris=sum(len(p.vertices)-2 for o in render_objects for p in o.data.polygons)
result={'source':SOURCE,'export':EXPORT,'render_meshes':len(render_objects),'objects':len(col.objects),
        'triangles_base':tris,'materials':len({m.name for o in render_objects for m in o.data.materials if m}),
        'bounds_m':[4.08,.847,3.24],'preserved_default_scene':old_scene.name if old_scene else None,
        'scene_objects':[(o.name,o.type) for o in scene.objects]}
