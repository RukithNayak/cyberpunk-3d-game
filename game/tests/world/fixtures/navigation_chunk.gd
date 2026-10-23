extends Node3D
## Tiny navigation half-plane for the WORLD-05 streaming fixture.

@export var min_x: float = -10.0
@export var max_x: float = 0.0
@export var synchronization_delay_frames: int = 0


func _ready() -> void:
	if synchronization_delay_frames > 0:
		for _frame: int in range(synchronization_delay_frames):
			await get_tree().physics_frame
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = _make_halfplane_mesh()
	add_child(region)

	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3((min_x + max_x) * 0.5, -0.1, 0.0)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(max_x - min_x, 0.2, 10.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	add_child(floor_body)


func _make_halfplane_mesh() -> NavigationMesh:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.1
	mesh.vertices = PackedVector3Array([
		Vector3(min_x, 0.0, -5.0),
		Vector3(max_x, 0.0, -5.0),
		Vector3(max_x, 0.0, 5.0),
		Vector3(min_x, 0.0, 5.0),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	return mesh
