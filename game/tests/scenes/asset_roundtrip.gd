extends Node3D
## In-engine smoke checks for both exported reference assets.

const EXPECTED_ASSETS := {
	"WallVisual": {"dimensions": Vector3(4.0, 3.4, 0.487), "triangles": 1428},
	"PropVisual": {"dimensions": Vector3(0.92, 1.28, 0.605), "triangles": 4600},
}
const COLLISION_ROOTS := ["WallCollision", "PropCollision"]


func _ready() -> void:
	var results: Array[Dictionary] = []
	for root_name in EXPECTED_ASSETS:
		var visual_root := get_node_or_null(NodePath(root_name))
		assert(visual_root is Node3D, "%s did not import as a scene root" % root_name)
		var meshes := visual_root.find_children("*", "MeshInstance3D", true, false)
		assert(not meshes.is_empty(), "%s has no imported meshes" % root_name)
		var imported_dimensions := _world_dimensions(meshes)
		var expected: Dictionary = EXPECTED_ASSETS[root_name]
		assert(imported_dimensions.distance_to(expected["dimensions"]) < 0.002,
			"%s dimensions/orientation mismatch: %s" % [root_name, imported_dimensions])
		var textured_materials := 0
		for mesh_instance in meshes:
			var mesh := mesh_instance as MeshInstance3D
			for surface_index in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface_index)
				assert(material is StandardMaterial3D, "%s surface is not a Godot PBR material" % mesh.name)
				var standard := material as StandardMaterial3D
				var arrays := mesh.mesh.surface_get_arrays(surface_index)
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uv0: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				assert(not normals.is_empty(), "%s surface did not import normals" % mesh.name)
				assert(not uv0.is_empty(), "%s surface did not import UV0" % mesh.name)
				for uv in uv0:
					assert(uv.x >= -0.0001 and uv.x <= 1.0001 and uv.y >= -0.0001 and uv.y <= 1.0001,
						"%s has UV outside 0–1" % mesh.name)
				assert(mesh.global_transform.basis.get_scale().distance_to(Vector3.ONE) < 0.001,
					"%s retains non-unit object scale" % mesh.name)
				assert(standard.albedo_texture != null, "%s lacks an imported base-color texture" % mesh.name)
				assert(standard.roughness_texture != null, "%s lacks the packed ORM roughness map" % mesh.name)
				assert(standard.metallic_texture != null, "%s lacks the packed ORM metallic map" % mesh.name)
				assert(standard.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN,
					"%s roughness is not read from ORM green" % mesh.name)
				assert(standard.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE,
					"%s metallic is not read from ORM blue" % mesh.name)
				textured_materials += 1
		results.append({"scene": root_name, "mesh_instances": meshes.size(),
			"textured_materials": textured_materials,
			"dimensions_y_up_m": [snappedf(imported_dimensions.x, 0.001),
				snappedf(imported_dimensions.y, 0.001), snappedf(imported_dimensions.z, 0.001)],
			"source_triangles": expected["triangles"]})

	for collision_name in COLLISION_ROOTS:
		var collision_root := get_node_or_null(NodePath(collision_name))
		assert(collision_root is Node3D, "%s collision scene did not import" % collision_name)
		var bodies := collision_root.find_children("*", "StaticBody3D", true, false)
		var shapes := collision_root.find_children("*", "CollisionShape3D", true, false)
		assert(not bodies.is_empty(), "%s has no imported StaticBody3D" % collision_name)
		assert(not shapes.is_empty(), "%s has no imported CollisionShape3D" % collision_name)
	await get_tree().physics_frame
	var world_state := get_world_3d().direct_space_state
	var pier_hit := world_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(-2.0, 1.4, 1.5), Vector3(-2.0, 1.4, -1.5)))
	assert(not pier_hit.is_empty(), "Wall collision is not blocking at first-person eye height")
	var doorway_hit := world_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(-0.5, 1.4, 1.5), Vector3(-0.5, 1.4, -1.5)))
	assert(doorway_hit.is_empty(), "Doorway collision blocks the intended opening")

	print("ASSET_ROUNDTRIP_OK ", JSON.stringify({"assets": results,
		"collision_roots": COLLISION_ROOTS, "static_bodies": _count_nodes("StaticBody3D"),
		"collision_shapes": _count_nodes("CollisionShape3D"),
		"first_person_ray": {"pier_blocked": true, "doorway_clear": true}}))
	if DisplayServer.get_name() in ["headless", "dummy"]:
		print("ASSET_ROUNDTRIP_CAPTURE_SKIPPED headless rendering backend")
	else:
		await get_tree().create_timer(0.5).timeout
		var evidence_dir := ProjectSettings.globalize_path("res://../docs/evidence/ASSET-03")
		DirAccess.make_dir_recursive_absolute(evidence_dir)
		var capture_path := evidence_dir.path_join("asset_roundtrip.png")
		var capture_error := get_viewport().get_texture().get_image().save_png(capture_path)
		assert(capture_error == OK, "Failed to save fixture capture: %s" % capture_error)
		print("ASSET_ROUNDTRIP_CAPTURE ", capture_path)
	get_tree().quit()


func _world_dimensions(meshes: Array[Node]) -> Vector3:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		var local_bounds := mesh_instance.get_aabb()
		for x in [local_bounds.position.x, local_bounds.end.x]:
			for y in [local_bounds.position.y, local_bounds.end.y]:
				for z in [local_bounds.position.z, local_bounds.end.z]:
					var point := mesh_instance.global_transform * Vector3(x, y, z)
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return maximum - minimum


func _count_nodes(type_name: String) -> int:
	return find_children("*", type_name, true, false).size()
