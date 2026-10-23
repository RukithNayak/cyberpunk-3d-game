extends SceneTree

const PREVIEW_SCENE: String = "res://tests/scenes/night_market_asset_preview.tscn"
const EXPECTED_COLLISION_SHAPES: int = 3
const EXPECTED_RENDER_BOUNDS: Vector3 = Vector3(4.08, 3.24, 0.847)
const DIMENSION_TOLERANCE: float = 0.025


func _initialize() -> void:
	call_deferred("_verify_import")


func _verify_import() -> void:
	var packed_scene: PackedScene = load(PREVIEW_SCENE) as PackedScene
	if packed_scene == null:
		_fail("Could not load %s" % PREVIEW_SCENE)
		return

	var preview_root: Node3D = packed_scene.instantiate() as Node3D
	if preview_root == null:
		_fail("Preview root is not Node3D")
		return
	root.add_child(preview_root)
	await process_frame

	var storefront: Node = preview_root.get_node_or_null("Storefront")
	if storefront == null:
		_fail("Preview is missing its Storefront instance")
		return
	var render_meshes: Array[Node] = storefront.find_children("*", "MeshInstance3D", true, false)
	var collision_shapes: Array[Node] = storefront.find_children("*", "CollisionShape3D", true, false)
	var collision_bodies: Array[Node] = storefront.find_children("*", "StaticBody3D", true, false)
	var render_bounds: AABB
	var has_bounds: bool = false
	for node: Node in render_meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if has_bounds:
			render_bounds = render_bounds.merge(world_aabb)
		else:
			render_bounds = world_aabb
			has_bounds = true
	print("ASSET07_IMPORT render_meshes=%d collision_bodies=%d collision_shapes=%d" % [
		render_meshes.size(), collision_bodies.size(), collision_shapes.size()
	])
	if render_meshes.is_empty():
		_fail("GLB imported without render meshes")
		return
	if not has_bounds:
		_fail("GLB render meshes have no measurable bounds")
		return
	var bounds_error: Vector3 = (render_bounds.size - EXPECTED_RENDER_BOUNDS).abs()
	print("ASSET07_IMPORT bounds_m=%s" % [render_bounds.size])
	if bounds_error.x > DIMENSION_TOLERANCE or bounds_error.y > DIMENSION_TOLERANCE or bounds_error.z > DIMENSION_TOLERANCE:
		_fail("Imported bounds differ from target: got %s expected %s" % [
			render_bounds.size, EXPECTED_RENDER_BOUNDS
		])
		return
	if collision_shapes.size() != EXPECTED_COLLISION_SHAPES:
		_fail("Expected %d imported collision shapes; got %d" % [
			EXPECTED_COLLISION_SHAPES, collision_shapes.size()
		])
		return
	print("ASSET07_IMPORT PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error("ASSET07_IMPORT FAIL: %s" % message)
	quit(1)
