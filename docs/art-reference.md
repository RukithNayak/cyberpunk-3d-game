# Stage 0 cyberpunk asset references

Status: engineering/art-direction proposal for Main Agent and human visual review. The palette and budgets below come from the two authored references and remain provisional; they are not human-ratified production art direction. Scope is one wall module with a traversable opening and one close-up utility junction. No city batch, exports, or image textures are included.

## Reference set

| Asset | Source | Render mesh | Simplified collision | Dimensions and pivot |
| --- | --- | ---: | ---: | --- |
| `env_wall_doorway_a` | [`wall_doorway.blend`](../art/reference/wall_doorway.blend) | 1,428 tris across 13 objects | 48 tris across 4 boxes | Main wall 4.0 × 0.30 × 3.40 m; visible assembly bounds approximately 4.0 × 0.49 × 3.40 m. Lower southwest corner at `(0, 0, 0)`; depth is centered on Y. Door opening 1.50 × 2.25 m. |
| `prop_utility_junction_a` | [`mechanical_prop.blend`](../art/reference/mechanical_prop.blend) | 4,600 tris across 30 objects | 24 tris across 2 boxes | Chassis 0.92 × 0.34 × 1.28 m; visible assembly bounds approximately 0.92 × 0.61 × 1.28 m including cable. Bottom-center pivot at `(0, 0, 0)`. |

The wall reference is a continuous closed mesh around the opening, with separate frame, threshold, status plate and conduit collars. Its player view is rendered from Z = 1.65 m. The prop has a close-up player-eye view from Z = 1.65 m, with a layered gauge, service door, fasteners, vent, status lights and a forward cable connection. Object-level render meshes and collision proxies have stable role tags in the editable scenes; collision objects use the `COL_` prefix and are hidden in the beauty view.

## Provisional visual language

The references use muted blue-grey concrete, charcoal enclosures, restrained teal-painted panels and indicator light, a single amber status cue, and neutral exposed metal. Principled materials are authored as reusable material slots without image textures. Approximate sRGB swatches are:

| Use | sRGB |
| --- | --- |
| Concrete | `#5F6A6F` |
| Dark enclosure | `#3C484D` |
| Muted teal paint | `#598489` |
| Exposed metal | `#BFC7C8` |
| Teal indicator | `#2CB8AF` |
| Amber indicator | `#F99E42` |
| Rubber | `#2C3235` |
| Tinted glass | `#2C6F76` |

Color is deliberately localized to small controls and frame surfaces. The proposal is suited to a night-city scene with readable silhouettes at player scale; no lighting, renderer, or in-engine appearance acceptance is implied by the Blender captures.

## Provisional budgets for follow-on references

Budgets are engineering limits suggested by these actual meshes, not measured platform performance:

- Wall module: at most 2,000 render triangles and 100 collision triangles. The current reference uses 1,428 and 48 respectively.
- Close-up utility prop: at most 5,000 render triangles and 100 collision triangles. The current reference uses 4,600 and 24 respectively.
- Texture target: at most two 1,024² maps per asset for an authored base-color atlas and packed ORM; add a 1,024² tangent-space normal map only if later detail requires it. A 1,024 px / 2 m trim or atlas tile suggests a provisional 512 px/m density. No maps are authored in this task.
- UVs are present per mesh and fit the 0–1 tile. Current layouts use separate object UVs; they have not been packed or normalized against one shared atlas, and the 512 px/m target is not a claim about current pixel density.

## Review and evidence

- [Player-eye wall render](evidence/ASSET-02/wall_player_eye.png), [four-angle wall sheet](evidence/ASSET-02/wall_contact.png), [wall collision sheet](evidence/ASSET-02/wall_collision.png), and [wall shell UV layout](evidence/ASSET-02/wall_uv.png).
- [Player-eye prop render](evidence/ASSET-02/prop_player_eye.png), [four-angle prop sheet](evidence/ASSET-02/prop_contact.png), [prop collision sheet](evidence/ASSET-02/prop_collision.png), and [chassis UV layout](evidence/ASSET-02/prop_chassis_uv.png).
- QA skill review: [random-color assembly sheets](evidence/ASSET-02/wall_parts_random.png) and [prop parts](evidence/ASSET-02/prop_parts_random.png); [wall wireframe](evidence/ASSET-02/wall_mesh_wire.png) and [prop wireframe](evidence/ASSET-02/prop_mesh_wire.png). These show connected, intentionally seated parts with no unexplained detached geometry.
- Automated geometry findings: [wall render QA](evidence/ASSET-02/wall_qa.json), [wall collision QA](evidence/ASSET-02/wall_collision_qa.json), [prop render QA](evidence/ASSET-02/prop_qa.json), [prop collision QA](evidence/ASSET-02/prop_collision_qa.json). The QA tool reports intentional embedded assembly contacts/back-to-back faces; none overlap with same-facing coplanar triangles, and no floating component, inverted island, non-manifold edge or degenerate face remains. Cylinder end caps use flat n-gons by design.
- Reproduce the Blender game-profile check with [`run_qa.py`](evidence/ASSET-02/run_qa.py); exact invocations and results are recorded in the [ASSET-02 worker report](reports/ASSET-02-worker.md).

The editable sources and deterministic build script are the authority for geometry. Captures are review evidence, not substitutes for 3D source or an engine round trip. GLB export and Godot import are assigned to ASSET-03.
