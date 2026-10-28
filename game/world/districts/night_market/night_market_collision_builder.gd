extends Node3D
class_name NightMarketCollisionBuilder
## Creates low-cost box collision for Blender-authored structural "solid" meshes.

const FLOOR_CENTER := Vector3(34.5, -0.5, -43.8)
const FLOOR_SIZE := Vector3(300.0, 1.0, 300.0)

@export var district_path: NodePath = NodePath("../District")

var structural_shape_count: int = 0


func _ready() -> void:
	var district := get_node_or_null(district_path) as Node3D
	if district == null:
		push_error("Night Market collision builder could not find its district scene")
		return
	var body := StaticBody3D.new()
	body.name = "DistrictCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_add_box(body, "StreetGround", FLOOR_CENTER, FLOOR_SIZE)
	for candidate: Node in district.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.name.to_lower().ends_with("solid"):
			continue
		var local_bounds: AABB = mesh_instance.get_aabb()
		var bounds := AABB(mesh_instance.to_global(local_bounds.get_endpoint(0)), Vector3.ZERO)
		for corner_index in range(1, 8):
			bounds = bounds.expand(mesh_instance.to_global(local_bounds.get_endpoint(corner_index)))
		var size := bounds.size
		if size.x < 0.15 or size.z < 0.15 or size.y < 0.75:
			continue
		_add_box(body, "Structure_%03d" % structural_shape_count, bounds.get_center(), size + Vector3(0.08, 0.0, 0.08))
		structural_shape_count += 1
	body.add_to_group("night_market_collision")
	print("NIGHT_MARKET_COLLISION structural_shapes=%d" % structural_shape_count)


func _add_box(body: StaticBody3D, shape_name: String, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = shape_name
	collision_shape.shape = shape
	collision_shape.position = center
	body.add_child(collision_shape)
