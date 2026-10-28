"""Build a reusable detailed Night Market modular kit in a separate Blender scene."""
import bpy, math, os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SRC_DIR = os.path.join(ROOT, "art/source/environment/night_market")
OUT_DIR = os.path.join(ROOT, "game/assets/environment/night_market")
BLEND = os.path.join(SRC_DIR, "night_market_modular_kit.blend")
GLB = os.path.join(OUT_DIR, "night_market_modular_kit.glb")
os.makedirs(OUT_DIR, exist_ok=True)

# Remove only this script's prior generated scene and objects. The hero and default
# Blender scene are untouched.
for s in list(bpy.data.scenes):
    if s.name == "NM_Modular_Kit":
        bpy.data.scenes.remove(s)
for ob in list(bpy.data.objects):
    if ob.name.startswith(("ENV_NMK_", "COL_NMK_", "PRV_NMK_")):
        bpy.data.objects.remove(ob, do_unlink=True)
for c in list(bpy.data.collections):
    if c.name.startswith("NMK_"):
        bpy.data.collections.remove(c)
for m in list(bpy.data.materials):
    if m.name.startswith("M_NMK_") and m.users == 0:
        bpy.data.materials.remove(m)
scene = bpy.data.scenes.new("NM_Modular_Kit")
root = bpy.data.collections.new("NMK_Export_Kit")
scene.collection.children.link(root)
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
scene.render.engine = "BLENDER_EEVEE"

def family(name):
    c = bpy.data.collections.new("NMK_" + name)
    root.children.link(c)
    return c

active = family("Facade_Bays")
materials = {}
def mat(name, color, metallic, rough, emission=0.0, texkind="microdetail"):
    m = bpy.data.materials.new("M_NMK_" + name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if emission:
        p.inputs["Emission Color"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = emission
    texname = {
      "base": "night_market_hero_night_market_microdetail_1k_basecolor.png",
      "normal": "night_market_hero_night_market_microdetail_1k_normal.png",
      "rough": "night_market_hero_night_market_microdetail_1k_roughness.png",
    }
    basepath = os.path.join(OUT_DIR, texname["base"])
    npath = os.path.join(OUT_DIR, texname["normal"])
    rpath = os.path.join(OUT_DIR, texname["rough"])
    if os.path.exists(basepath):
        im = bpy.data.images.load(basepath, check_existing=True)
        t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = im
        t.name = "T_NightMarket_Shared_BaseColor"
        m.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    if os.path.exists(rpath):
        im = bpy.data.images.load(rpath, check_existing=True); im.colorspace_settings.name = "Non-Color"
        t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = im
        m.node_tree.links.new(t.outputs["Color"], p.inputs["Roughness"])
    if os.path.exists(npath):
        im = bpy.data.images.load(npath, check_existing=True); im.colorspace_settings.name = "Non-Color"
        t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = im
        nm = m.node_tree.nodes.new("ShaderNodeNormalMap")
        m.node_tree.links.new(t.outputs["Color"], nm.inputs["Color"])
        m.node_tree.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    materials[name] = m
    return m

mat("RainConcrete", (.26,.29,.28), .08, .83)
mat("OxideTeal", (.028,.23,.22), .48, .43)
mat("BlackenedSteel", (.025,.036,.041), .82, .28)
mat("BrushedSteel", (.43,.49,.48), .77, .24)
mat("AmberGlass", (1.0,.25,.018), .24, .2, 3.2)
mat("CyanGlass", (.012,.58,.74), .2, .19, 2.5)
mat("SmokedGlass", (.018,.09,.12), .55, .14)
mat("Canvas", (.47,.13,.045), .02, .78)
mat("WarmIvory", (.9,.64,.31), .1, .4, .45)
mat("Rubber", (.012,.016,.018), .02, .9)
mat("Rust", (.29,.068,.018), .45, .72)

def box(name, loc, size, material, bevel=.025, coll=None):
    coll = coll or active
    x,y,z=(v*.5 for v in size)
    verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name+"_Mesh"); me.from_pydata(verts,[],faces); me.update()
    uv=me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for i,li in enumerate(poly.loop_indices):
            uv.data[li].uv=((0,0),(1,0),(1,1),(0,1))[i%4]
    o=bpy.data.objects.new(name,me); coll.objects.link(o); o.location=loc
    o.data.materials.append(material if material else materials["Rubber"])
    if bevel:
        b=o.modifiers.new("Machined edges", "BEVEL"); b.width=min(bevel,min(size)*.18); b.segments=2
        o.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    o["asset_family"] = coll.name.removeprefix("NMK_")
    return o

def rod(name, a, b, radius, material, coll=None, vertices=10):
    coll=coll or active
    v1,v2=Vector(a),Vector(b); d=v2-v1
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=d.length, location=(v1+v2)*.5)
    o=bpy.context.object
    for c in list(o.users_collection): c.objects.unlink(o)
    coll.objects.link(o); o.name=name; o.rotation_mode="QUATERNION"; o.rotation_quaternion=d.to_track_quat("Z","Y")
    o.data.materials.append(material); o["asset_family"]=coll.name.removeprefix("NMK_")
    return o

def text_obj(name, body, loc, size, material, coll=None):
    coll=coll or active
    cv=bpy.data.curves.new(name+"_Curve","FONT"); cv.body=body; cv.size=size; cv.extrude=.0015
    ob=bpy.data.objects.new(name,cv); coll.objects.link(ob); ob.location=loc; ob.rotation_euler[0]=math.pi/2
    cv.materials.append(material); ob["asset_family"]=coll.name.removeprefix("NMK_")
    return ob

def collider(name, loc, size, coll):
    return box("COL_NMK_"+name+"-colonly",loc,size,None,0,coll)

def bay(name, base=0.0, style="teal"):
    global active
    active=family(name)
    concrete=materials["RainConcrete"]; steel=materials["BlackenedSteel"]
    accent=materials["OxideTeal"] if style=="teal" else materials["Canvas"]
    # 4m bay, 4.2m storey, facade depth 0.42m, repeated pilaster / lintel language.
    box("ENV_NMK_"+name+"_Core",(base,0,2.1),(4,.42,4.2),concrete,.045)
    for x in (-1.88,1.88):
        box("ENV_NMK_"+name+"_Pilaster",(base+x,-.255,2.12),(.20,.18,4.22),steel,.025)
        for z in (.22, .42, 3.92):
            box("ENV_NMK_"+name+"_Pilaster_Cap",(base+x,-.36,z),(.27,.08,.07),materials["BrushedSteel"],.01)
    box("ENV_NMK_"+name+"_Sign_Canopy",(base,-.34,3.52),(3.58,.32,.46),steel,.035)
    box("ENV_NMK_"+name+"_Sign_Light",(base,-.52,3.48),(3.15,.025,.06),materials["AmberGlass"],.01)
    text_obj("ENV_NMK_"+name+"_Lettering","NIGHT / MARKET",(base-1.25,-.55,3.59),.17,materials["WarmIvory"])
    # Upper industrial window with deep reveal, mullions and sill drainage.
    box("ENV_NMK_"+name+"_Window_Reveal",(base,-.26,2.40),(2.1,.17,1.40),steel,.035)
    box("ENV_NMK_"+name+"_Window_Glass",(base,-.36,2.41),(1.82,.025,1.10),materials["SmokedGlass"],.01)
    for dx in (-.58,0,.58):
        box("ENV_NMK_"+name+"_Mullion",(base+dx,-.392,2.41),(.045,.035,1.14),materials["BrushedSteel"],.008)
    box("ENV_NMK_"+name+"_Window_Sill",(base,-.38,1.69),(2.25,.34,.10),materials["BrushedSteel"],.025)
    # Wall rain streak ribs and embedded utility trunk.
    for i in range(7):
        x=base-1.55+i*.52
        box("ENV_NMK_"+name+"_Rain_Rib",(x,-.222,.85),(.024,.022,.8),accent,.007)
    box("ENV_NMK_"+name+"_Power_Trunk",(base+1.55,-.34,1.75),(.13,.18,2.2),steel,.025)
    for z in (.85,1.65,2.45):
        box("ENV_NMK_"+name+"_Trunk_Clamp",(base+1.55,-.45,z),(.21,.045,.055),materials["BrushedSteel"],.008)
    # Base kick, drainage grate and chipped repair plates.
    box("ENV_NMK_"+name+"_Kickplate",(base,-.27,.16),(3.65,.16,.32),steel,.025)
    for i in range(13):
        box("ENV_NMK_"+name+"_Drain_Slot",(base-.42+i*.07,-.365,.16),(.026,.008,.17),materials["Rubber"],.002)
    for i in range(5):
        box("ENV_NMK_"+name+"_Repair_Patch",(base-1.45+i*.65,-.226,1.22+(i%2)*.15),(.17,.018,.24),accent,.01)
    # articulated street-side service hatch and real hinge/latch details
    box("ENV_NMK_"+name+"_Service_Hatch",(base-1.2,-.30,.83),(.45,.11,.52),steel,.023)
    for z in (.65,1.00):
        rod("ENV_NMK_"+name+"_Hatch_Hinge",(base-1.43,-.37,z),(base-1.32,-.37,z),.027,materials["BrushedSteel"])
    box("ENV_NMK_"+name+"_Hatch_Latch",(base-.94,-.375,.83),(.06,.04,.14),materials["AmberGlass"],.01)
    # restrained grime/stain plates provide authored, nonprocedural edge variation.
    for x,z,w,h in ((-1.65,.55,.25,.08),(.92,1.12,.33,.06),(-.24,2.03,.19,.05),(1.2,.48,.14,.1)):
        box("ENV_NMK_"+name+"_Wear",(base+x,-.232,z),(w,.006,h),materials["Rust"],.002)
    collider(name+"_SolidWall",(base, .03,2.1),(3.86,.55,4.2),active)
    return active

# Three façade bays form distinct shop, corner and upper-storey variants.
bay("Facade_Shop_A")
bay("Facade_Corner_B",style="paint")
bay("Facade_Upper_C")

# Shutter/window variant with slatted metal gate and framing.
active=family("Shutters_Windows")
box("ENV_NMK_Shutter_Frame",(0,0,1.6),(2.6,.28,3.2),materials["RainConcrete"],.035)
box("ENV_NMK_Shutter_Opening",(0,-.18,1.25),(2.05,.05,2.15),materials["BlackenedSteel"],.015)
for i in range(17):
    box("ENV_NMK_Shutter_Slat",(0,-.224,.28+i*.12),(2.0,.045,.045),materials["BrushedSteel"],.01)
for x in (-1.03,1.03):
    box("ENV_NMK_Shutter_Guide",(x,-.25,1.25),(.09,.10,2.28),materials["BlackenedSteel"],.015)
for i in range(5):
    box("ENV_NMK_Window_Bar",(-.60+i*.30,-.24,2.72),(.035,.06,.86),materials["BlackenedSteel"],.008)
box("ENV_NMK_Window_Lintel",(0,-.21,3.22),(2.55,.30,.14),materials["OxideTeal"],.025)
for x in (-1.12,1.12): box("ENV_NMK_Window_Sill_End",(x,-.26,2.21),(.16,.38,.10),materials["BrushedSteel"],.018)
collider("Shutter_Frame",(0,.02,1.6),(2.7,.5,3.2),active)

# 4m cantilevered awning, striped valance, ribs and tension stays.
active=family("Awnings")
box("ENV_NMK_Awning_Backplate",(0,0,2.55),(3.4,.12,.12),materials["BlackenedSteel"],.02)
box("ENV_NMK_Awning_Canopy",(0,-.75,2.43),(3.55,1.45,.10),materials["Canvas"],.035)
for i in range(10):
    x=-1.59+i*.355
    box("ENV_NMK_Awning_Seam",(x,-.76,2.485),(.018,1.34,.008),materials["WarmIvory"],.003)
    if i not in (0,9):
        rod("ENV_NMK_Awning_Tie",(x,-.1,2.5),(x,-1.40,2.34),.012,materials["BlackenedSteel"])
    box("ENV_NMK_Awning_Valance",(x,-1.48,2.29),(.34,.07,.25),materials["OxideTeal"] if i%2 else materials["Canvas"],.025)
for x in (-1.62,1.62):
    rod("ENV_NMK_Awning_Brace",(x,-.12,2.51),(x,-1.4,2.4),.035,materials["BrushedSteel"])
collider("Awning",(0,-.72,2.50),(3.5,1.4,.12),active)

# Fire escape: landing, perforated grating, guardrail, ladder, stairs and brackets.
active=family("FireEscape")
box("ENV_NMK_FireEscape_Landing",(0,0,2.65),(2.6,1.25,.14),materials["BlackenedSteel"],.02)
for x in [i*.13125-1.05 for i in range(17)]:
    box("ENV_NMK_FireEscape_Grate",(x,-.02,2.726),(.035,1.12,.012),materials["BrushedSteel"],.002)
for x in (-1.2,1.2):
    rod("ENV_NMK_FireEscape_Post",(x,-.50,2.72),(x,-.50,3.72),.035,materials["BlackenedSteel"])
    rod("ENV_NMK_FireEscape_Rail",(x,-.50,3.72),(x,.48,3.72),.03,materials["BrushedSteel"])
for i in range(7):
    y=-.4+i*.14
    rod("ENV_NMK_FireEscape_Baluster",(-1.2,y,2.75),(-1.2,y,3.72),.012,materials["BrushedSteel"])
    rod("ENV_NMK_FireEscape_Baluster",(1.2,y,2.75),(1.2,y,3.72),.012,materials["BrushedSteel"])
for x in (-.8,.8):
    box("ENV_NMK_FireEscape_Wall_Bracket",(x,.52,2.4),(.12,.50,.42),materials["BlackenedSteel"],.02)
# 9-step exterior stair run with solid stringers and ribbed nosings.
for i in range(9):
    z=2.5-i*.24; y=-.75-i*.23
    box("ENV_NMK_FireEscape_Step",(0,y,z),(1.25,.29,.075),materials["BrushedSteel"],.014)
    box("ENV_NMK_FireEscape_Nosing",(0,y-.13,z+.04),(1.25,.045,.028),materials["AmberGlass"],.006)
rod("ENV_NMK_FireEscape_Stringer",(-.7,-.55,2.7),(-.7,-2.55,.65),.055,materials["BlackenedSteel"])
rod("ENV_NMK_FireEscape_Stringer",(.7,-.55,2.7),(.7,-2.55,.65),.055,materials["BlackenedSteel"])
collider("FireEscape_Landing",(0,0,2.65),(2.6,1.25,.14),active)

# Night Market food stall, stainless counter, canopy, display glass, lanterns and stock crates.
active=family("MarketStall")
box("ENV_NMK_Stall_Base",(0,0,.68),(2.4,1.2,1.36),materials["OxideTeal"],.045)
box("ENV_NMK_Stall_Counter",(0,-.04,1.38),(2.58,1.32,.13),materials["BrushedSteel"],.025)
box("ENV_NMK_Stall_Counter_Front",(0,-.64,1.05),(2.32,.04,.40),materials["BlackenedSteel"],.018)
for x in (-.86,-.43,0,.43,.86):
    box("ENV_NMK_Stall_Panel_Inlay",(x,-.668,1.05),(.24,.012,.22),materials["WarmIvory"],.01)
box("ENV_NMK_Stall_Display_Glass",(0,-.32,1.70),(1.9,.035,.48),materials["SmokedGlass"],.012)
for x in (-1.04,1.04):
    box("ENV_NMK_Stall_Canopy_Post",(x,0,2.0),(.08,.08,1.5),materials["BlackenedSteel"],.012)
box("ENV_NMK_Stall_Canopy",(0,0,2.78),(2.75,1.45,.12),materials["Canvas"],.035)
for i in range(7):
    x=-1.1+i*.36
    box("ENV_NMK_Stall_Canopy_Stripe",(x,-.02,2.85),(.18,1.24,.012),materials["WarmIvory"],.004)
for x in (-.7,0,.7):
    box("ENV_NMK_Stall_Food_Tray",(x,-.31,1.97),(.44,.35,.12),materials["BlackenedSteel"],.02)
    for j in range(3):
        box("ENV_NMK_Stall_Stock",(x-.10+j*.10,-.31,2.09),(.07,.10,.12),materials["AmberGlass"] if j==1 else materials["Rust"],.018)
box("ENV_NMK_Stall_Menu",(0,-.72,2.33),(1.35,.045,.42),materials["BlackenedSteel"],.018)
text_obj("ENV_NMK_Stall_Menu_Text","RAMEN  //  24H",( -.58,-.75,2.30),.105,materials["WarmIvory"])
for x in (-.9,.9):
    box("ENV_NMK_Stall_Lantern",(x,-.69,2.46),(.16,.13,.22),materials["AmberGlass"],.025)
collider("MarketStall",(0,0,1.4),(2.65,1.45,2.8),active)

# Street sign cluster and detailed illuminated blades.
active=family("StreetSigns")
rod("ENV_NMK_Sign_Post",(0,0,.1),(0,0,4.8),.075,materials["BlackenedSteel"],vertices=12)
for i,(z,body,label,col) in enumerate(((4.1,"NIGHT MARKET","夜市",materials["CyanGlass"]),(3.35,"KABUKI / 09","BLOCK 09",materials["AmberGlass"]),(2.6,"SERVICE ALLEY","KEEP CLEAR",materials["CyanGlass"]))):
    box("ENV_NMK_Sign_Blade",(0,-.18,z),(1.55,.16,.48),materials["BlackenedSteel"],.035)
    box("ENV_NMK_Sign_Diffuser",(0,-.272,z),(1.35,.018,.30),col,.012)
    text_obj("ENV_NMK_Sign_Label",body,(-.58,-.292,z-.025),.14,materials["WarmIvory"])
    for x in (-.64,.64):
        rod("ENV_NMK_Sign_Rivet",(x,-.30,z-.15),(x,-.30,z+.15),.012,materials["BrushedSteel"])
for z in (.4,.55):
    box("ENV_NMK_Sign_Base_Bolt",(0,-.10,z),(.20,.08,.07),materials["BrushedSteel"],.01)
collider("SignPost",(0,0,2.4),(.16,.16,4.8),active)

# Streetlight with rain hood, lens cap, junction box and cable drops.
active=family("StreetLighting")
rod("ENV_NMK_Lamp_Pole",(0,0,.1),(0,0,5.8),.09,materials["BlackenedSteel"],vertices=14)
rod("ENV_NMK_Lamp_Arm",(0,0,5.55),(1.35,-.1,5.55),.055,materials["BrushedSteel"])
box("ENV_NMK_Lamp_Housing",(1.45,-.1,5.42),(.75,.42,.28),materials["BlackenedSteel"],.06)
box("ENV_NMK_Lamp_Diffuser",(1.45,-.32,5.37),(.60,.035,.08),materials["CyanGlass"],.018)
box("ENV_NMK_Lamp_Rain_Hood",(1.45,-.14,5.61),(.86,.53,.08),materials["BrushedSteel"],.035)
box("ENV_NMK_Lamp_Junction",(0,-.12,1.25),(.38,.22,.58),materials["OxideTeal"],.03)
box("ENV_NMK_Lamp_Hatch",(0,-.245,1.25),(.22,.025,.36),materials["BlackenedSteel"],.015)
for z in (1.08,1.21,1.34):
    box("ENV_NMK_Lamp_Status",(0,-.27,z),(.06,.015,.035),materials["AmberGlass"],.008)
for i in range(6):
    box("ENV_NMK_Lamp_Base_Rib",(0,0,.2+i*.06),(.19+i*.018,.19+i*.018,.025),materials["BrushedSteel"],.006)
collider("Streetlight",(0,0,2.95),(.2,.2,5.9),active)

# Roofline/corner parapet kit and rooftop service details.
active=family("Roofline")
box("ENV_NMK_Roof_Parapet",(0,0,1.45),(4,.42,2.9),materials["RainConcrete"],.045)
box("ENV_NMK_Roof_Cap",(0,-.02,2.92),(4.2,.60,.14),materials["BlackenedSteel"],.025)
for x in (-1.72,-1.25,-.78,-.31,.16,.63,1.10,1.57):
    box("ENV_NMK_Roof_Coping_Clamp",(x,-.16,3.03),(.13,.26,.08),materials["BrushedSteel"],.012)
box("ENV_NMK_Roof_Duct",(1.05,.02,3.55),(.64,.64,1.0),materials["BlackenedSteel"],.045)
for z in (3.18,3.35,3.52,3.69,3.86):
    box("ENV_NMK_Roof_Duct_Louver",(1.05,-.31,z),(.46,.04,.045),materials["BrushedSteel"],.01)
for x in (-1.15,-.65,-.15,.35):
    rod("ENV_NMK_Roof_Pipe",(x,.20,2.9),(x,.20,4.0),.035,materials["OxideTeal"],vertices=10)
box("ENV_NMK_Roof_Service_Hatch",(0,-.02,3.55),(1.0,.78,.12),materials["BrushedSteel"],.025)
collider("Roofline",(0,0,1.45),(4,.55,2.9),active)

# All source mesh modules stay distinct. Export colliders separately with Godot
# recognized naming; no source objects are joined or destructively merged.
window=bpy.context.window
previous_scene=window.scene if window else None
if window: window.scene=scene
bpy.ops.wm.save_as_mainfile(filepath=BLEND, copy=False)
exports=[]
for collection in list(root.children):
    members=list(collection.all_objects)
    if not members: continue
    bpy.ops.object.select_all(action="DESELECT")
    for ob in members: ob.select_set(True)
    bpy.context.view_layer.objects.active=next((o for o in members if o.type=="MESH"),members[0])
    slug=collection.name.removeprefix("NMK_").lower()
    out=os.path.join(OUT_DIR,"night_market_"+slug+".glb")
    # Remove only this script's generated output/versioned collisions so each
    # build has stable, readable asset paths.
    prefix="night_market_"+slug
    for filename in os.listdir(OUT_DIR):
        if filename.startswith(prefix) and filename.endswith(".glb"):
            os.remove(os.path.join(OUT_DIR,filename))
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True,
        export_apply=True,
        export_cameras=False, export_lights=False,
        export_materials="EXPORT", export_image_format="AUTO",
        export_yup=True, export_animations=False
    )
    actual=out
    if not os.path.exists(actual):
        candidates=[os.path.join(OUT_DIR,n) for n in os.listdir(OUT_DIR) if n.startswith("night_market_"+slug) and n.endswith(".glb")]
        if not candidates: raise RuntimeError("No GLB written for "+collection.name)
        actual=max(candidates,key=os.path.getmtime)
        os.replace(actual,out)
    exports.append({"family":collection.name,"glb":out,"bytes":os.path.getsize(out),"objects":len(members)})
deps=bpy.context.evaluated_depsgraph_get()
tri=sum(len(p.vertices)-2 for o in scene.objects if o.type=="MESH" and o.name.startswith("ENV_NMK_") for p in o.data.polygons)
bounds=[]
for o in scene.objects:
    if o.type=="MESH" and o.name.startswith("ENV_NMK_"):
        deps.update(); bounds.extend([o.matrix_world @ Vector(c) for c in o.bound_box])
mins=[min(v[i] for v in bounds) for i in range(3)]
maxs=[max(v[i] for v in bounds) for i in range(3)]
result={"blender":bpy.app.version_string,"source":BLEND,"exports":exports,"families":[c.name for c in root.children],"objects":len(scene.objects),"render_meshes":sum(1 for o in scene.objects if o.type=="MESH" and o.name.startswith("ENV_NMK_")),"colliders":sum(1 for o in scene.objects if o.type=="MESH" and o.name.startswith("COL_NMK_")),"triangles":tri,"materials":len(materials),"glb_bytes":sum(e["bytes"] for e in exports)}
if window and previous_scene: window.scene=previous_scene
