extends SceneTree

func _initialize() -> void:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var path: String = ProjectSettings.globalize_path("res://../art/reference/environment-smoke/environment_smoke.glb")
	var error: Error = document.append_from_file(path, state)
	if error != OK:
		printerr("GLB import failed: ", error)
		quit(1)
		return
	var scene: Node = document.generate_scene(state)
	if scene == null:
		quit(1)
		return
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		printerr("Expected one mesh, got ", meshes.size())
		scene.free()
		quit(1)
		return
	var mesh: MeshInstance3D = meshes[0] as MeshInstance3D
	var bounds: AABB = mesh.get_aabb()
	var material: Material = mesh.mesh.surface_get_material(0)
	var valid: bool = bounds.size.is_equal_approx(Vector3.ONE) and is_equal_approx(bounds.position.y, 0.0) and material != null
	print("GODOT_SMOKE mesh_count=", meshes.size(), " bounds=", bounds, " material=", material.resource_name, " valid=", valid)
	scene.free()
	quit(0 if valid else 1)
