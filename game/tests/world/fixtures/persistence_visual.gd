extends "res://tests/world/fixtures/persistent_projection.gd"
## Greybox state projection only; no door/loot/NPC gameplay rules.

func apply_persistent_state(state: Dictionary) -> void:
	super.apply_persistent_state(state)
	var visual: MeshInstance3D = get_node_or_null("Visual") as MeshInstance3D
	if visual == null:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if state.has("locked"):
		material.albedo_color = Color(0.9, 0.22, 0.2) if state["locked"] else Color(0.18, 0.9, 0.45)
	elif state.has("trust"):
		material.albedo_color = Color(0.15, 0.8, 0.95) if state["trust"] >= 4 else Color(0.65, 0.35, 0.8)
	else:
		material.albedo_color = Color(1.0, 0.7, 0.15)
	visual.material_override = material
