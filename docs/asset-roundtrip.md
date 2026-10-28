# ASSET-03 Blender → Godot round-trip

ASSET-03 exports the two editable ASSET-02 references as evaluated, meter-scale
GLBs with non-overlapping per-face UV atlases, image-backed base color and ORM
materials, and separate collision-only GLBs. The exporter opens source files but
does not save or rewrite them.

## Rebuild and open the fixture

From the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 \
  --python tools/blender/export_modular_kit.py -- --out-dir game/assets/reference --repeat-check
godot --headless --path game --editor --import
godot --path game --scene res://tests/scenes/asset_roundtrip.tscn
```

`--repeat-check` makes two scratch exports per reference before writing the
canonical output, compares the semantic metadata at 1e-6 tolerance, and prints
whether the maps and GLBs are byte-identical. The fixture reports
`ASSET_ROUNDTRIP_OK`, captures `docs/evidence/ASSET-03/asset_roundtrip.png` on a
rendering backend, and exits. A headless/dummy renderer skips the PNG capture but
still runs material, dimensions, collision and first-person ray assertions.

## Export contract and observed result

| Asset | Render mesh | Collision proxy | Godot Y-up dimensions |
|---|---:|---:|---|
| `wall_doorway` | 1,428 tris / 13 objects | 48 tris / 4 boxes | 4.000 × 3.400 × 0.487 m |
| `mechanical_prop` | 4,600 tris / 30 objects | 24 tris / 2 boxes | 0.920 × 1.280 × 0.605 m |

Base color is written to an sRGB PNG and connected through the Godot Standard
Material albedo texture. ORM is a Non-Color PNG: red is constant white AO, green
is roughness, and blue is metallic. The fixture checks all imported render
surfaces use image-backed StandardMaterial3D values and read roughness/metallic
from green/blue respectively.

Collision objects end in `-colonly`; Godot imports them as static bodies with
collision shapes while excluding them from the beauty mesh. The fixture verifies
six bodies/shapes and casts a ray at 1.4 m eye height: it hits the wall pier and
passes through the doorway. The screenshot is a visual smoke check, not final art
direction or production lighting acceptance.

The mesh geometry is evaluated from each source with world transforms baked into
the exported mesh and each evaluated face assigned a padded, non-overlapping UV
cell. The current ASSET-02 source materials are constant Principled values, so
the image maps bake those constants; linked image/procedural source inputs are
intentionally rejected rather than silently flattened incorrectly. There are
no Geometry Nodes graphs in these source assets.
