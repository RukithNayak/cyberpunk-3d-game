extends SceneTree

const ASSET_PATH := "res://assets/environment/night_market/neon_market_district.glb"

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var packed := load(ASSET_PATH) as PackedScene
	if packed == null:
		push_error("ASSET08_IMPORT failed to load district GLB")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	instance.force_update_transform()
	var mesh_nodes := instance.find_children("*", "MeshInstance3D", true, false)
	var material_ids: Dictionary = {}
	var total_bounds := AABB()
	var has_bounds := false
	for candidate in mesh_nodes:
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.get_aabb()
		var world_bounds := local_bounds * mesh_instance.global_transform
		total_bounds = world_bounds if not has_bounds else total_bounds.merge(world_bounds)
		has_bounds = true
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface)
			if material != null:
				material_ids[material.get_instance_id()] = material
	if mesh_nodes.size() < 100 or not has_bounds:
		push_error("ASSET08_IMPORT found too little district geometry")
		quit(1)
		return
	var d := total_bounds.size
	if maxf(d.x, maxf(d.y, d.z)) > 305.0:
		push_error("ASSET08_IMPORT bounds exceed the 300 m source crop tolerance: %s" % d)
		quit(1)
	print("ASSET08_IMPORT meshes=%d materials=%d bounds_m=%s" % [
		mesh_nodes.size(), material_ids.size(), d])
	print("ASSET08_IMPORT PASS")
	quit(0)
