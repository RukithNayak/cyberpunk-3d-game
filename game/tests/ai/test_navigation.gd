extends Node3D
## Isolated real-physics/navmesh check for AI-03.

const GOON_SCENE_PATH: String = "res://features/npcs/goon.tscn"
const WALL_ROUTE_TIMEOUT_FRAMES: int = 360
const RECOVERY_TIMEOUT_FRAMES: int = 90
var _last_recovery_reason: StringName = &""
@export var launch_demo: bool = true


func _ready() -> void:
	if launch_demo:
		_start_demo.call_deferred()


func _start_demo() -> void:
	var region: NavigationRegion3D = get_node("NavigationRegion3D") as NavigationRegion3D
	region.navigation_mesh = _make_wall_route_mesh()
	var world_map: RID = get_world_3d().navigation_map
	NavigationServer3D.map_set_active(world_map, true)
	NavigationServer3D.map_force_update(world_map)
	var goon: CharacterBody3D = (load(GOON_SCENE_PATH) as PackedScene).instantiate() as CharacterBody3D
	goon.name = "Goon"
	goon.position = Vector3(-2.0, 0.0, 0.0)
	add_child(goon)
	var factions: FactionState = FactionState.new(["gang_a", "player"])
	goon.call("configure", factions, "gang_a")
	var overlay_layer: CanvasLayer = CanvasLayer.new()
	overlay_layer.name = "DebugOverlayLayer"
	add_child(overlay_layer)
	var overlay: AiDebugOverlay = AiDebugOverlay.new()
	overlay.name = "AiDebugOverlay"
	overlay.navigation_driver_path = NodePath("../../Goon/NavigationDriver")
	overlay_layer.add_child(overlay)
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(goon) and not goon.is_queued_for_deletion():
		var perception: NpcPerception = goon.get_node("Perception") as NpcPerception
		perception.notify_sound_event(Vector3(2.0, 0.0, 0.0), 6.0, "player")


func run(check: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var fixture: Node3D = self
	launch_demo = false
	await tree.process_frame
	var region: NavigationRegion3D = fixture.get_node("NavigationRegion3D") as NavigationRegion3D
	region.navigation_mesh = _make_wall_route_mesh()
	var world_map: RID = fixture.get_world_3d().navigation_map
	NavigationServer3D.map_set_active(world_map, true)
	NavigationServer3D.map_force_update(world_map)
	var goon: CharacterBody3D = (load(GOON_SCENE_PATH) as PackedScene).instantiate() as CharacterBody3D
	goon.position = Vector3(-2.0, 0.0, 0.0)
	goon.set("process_ai", false)
	fixture.add_child(goon)
	var driver: Node = goon.get_node("NavigationDriver")
	driver.get_node("NavigationAgent3D").set_navigation_map(world_map)
	driver.set("stuck_timeout_seconds", 0.6)
	var factions: FactionState = FactionState.new(["gang_a", "player"])
	check.call(bool(goon.call("configure", factions, "gang_a")), "goon configures navigation fixture")
	await tree.physics_frame
	if not is_instance_valid(goon):
		check.call(false, "goon remains alive after initial navigation synchronization")
		return
	await tree.physics_frame
	if not is_instance_valid(goon):
		check.call(false, "goon remains alive while navigation synchronizes")
		return
	NavigationServer3D.map_force_update(world_map)
	var perception: NpcPerception = goon.get_node("Perception") as NpcPerception
	var path_map: RID = driver.get_node("NavigationAgent3D").get_navigation_map()
	var route: PackedVector3Array = PackedVector3Array()
	for _sync_frame: int in range(120):
		var map_synchronized: bool = NavigationServer3D.map_get_iteration_id(path_map) > 0
		var region_synchronized: bool = NavigationServer3D.region_get_iteration_id(region.get_rid()) > 0
		if map_synchronized and region_synchronized:
			var start_point: Vector3 = NavigationServer3D.map_get_closest_point(path_map, Vector3(-2.0, 0.0, 0.0))
			if start_point.distance_to(Vector3(-2.0, 0.0, 0.0)) <= 0.8:
				route = NavigationServer3D.map_get_path(path_map, Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), true)
		if route.size() >= 3:
			break
		await tree.physics_frame
		if not is_instance_valid(goon) or goon.is_queued_for_deletion():
			check.call(false, "goon remains available until navigation geometry synchronizes")
			return
	check.call(route.size() >= 3, "navigation map returns a routed path around the wall")
	if route.size() < 3:
		print("AI_NAV_DIAG map=%s active=%s iteration=%d region_iteration=%d closest=%s regions=%s polygons=%d route=%s" % [world_map, NavigationServer3D.map_is_active(world_map), NavigationServer3D.map_get_iteration_id(world_map), NavigationServer3D.region_get_iteration_id(region.get_rid()), NavigationServer3D.map_get_closest_point(world_map, Vector3(-2.0, 0.0, 0.0)), NavigationServer3D.map_get_regions(world_map), region.navigation_mesh.get_polygon_count(), route])
		queue_free()
		return
	perception.notify_sound_event(Vector3(2.0, 0.0, 0.0), 6.0, "player")
	goon.call("tick", 1.0 / 60.0)
	check.call(String(goon.call("get_state_name")) == "investigate", "heard event behind wall produces investigation intent")
	var initial_z: float = goon.global_position.z
	var maximum_route_offset: float = 0.0
	for _frame: int in range(WALL_ROUTE_TIMEOUT_FRAMES):
		await tree.physics_frame
		if not is_instance_valid(goon) or goon.is_queued_for_deletion():
			break
		maximum_route_offset = maxf(maximum_route_offset, absf(goon.global_position.z - initial_z))
		if goon.global_position.x >= 1.5:
			if goon.global_position.distance_to(Vector3(2.0, 0.0, 0.0)) <= 0.6:
				break
	check.call(is_instance_valid(goon) and goon.global_position.distance_to(Vector3(2.0, 0.0, 0.0)) <= 0.6 and maximum_route_offset >= 1.5, "navigation reaches sound source by routing around wall")
	if not is_instance_valid(goon):
		return
	check.call(String(driver.call("get_perception_summary")).begins_with("heard event"), "debug data exposes heard-event perception")
	check.call(bool(driver.get("has_last_valid_position")), "driver retains last valid navigation position")
	check.call(not String(driver.get("debug_state")).is_empty(), "driver exposes movement state for overlay")
	_last_recovery_reason = &""
	driver.recovered.connect(_on_driver_recovered)
	driver.set("_last_progress_position", goon.global_position)
	driver.call("_check_progress", driver.get("stuck_timeout_seconds"))
	check.call(_last_recovery_reason == &"stuck" and String(driver.get("debug_state")) == "recovered", "stuck recovery resets the agent to its last valid point")
	var overlay: AiDebugOverlay = AiDebugOverlay.new()
	overlay.navigation_driver_path = NodePath("../NavigationDriver")
	goon.add_child(overlay)
	await tree.process_frame
	check.call(overlay.get_child_count() > 0, "debug overlay builds a readout for the driver")
	var readout: Label = overlay.get_node("Readout") as Label
	check.call(readout.text.contains("DEST") and readout.text.contains("LAST") and readout.text.contains("NAV"), "overlay exposes navigation readiness, destination, and last valid point")
	driver.set("unreachable_timeout_seconds", 0.25)
	driver.call("_on_movement_intent_changed", Vector3(20.0, 0.0, 0.0), 2.5, true)
	var saved_recovery_point: Vector3 = driver.get("last_valid_position")
	for _frame: int in range(RECOVERY_TIMEOUT_FRAMES):
		await tree.physics_frame
		if not is_instance_valid(goon) or goon.is_queued_for_deletion():
			break
	check.call(not is_instance_valid(goon) or goon.global_position.distance_to(saved_recovery_point) < 0.1, "unreachable target recovers to a valid point or safely despawns")
	var off_mesh_goon: CharacterBody3D = (load(GOON_SCENE_PATH) as PackedScene).instantiate() as CharacterBody3D
	off_mesh_goon.set("process_ai", false)
	fixture.add_child(off_mesh_goon)
	var off_mesh_driver: Node = off_mesh_goon.get_node("NavigationDriver")
	off_mesh_driver.get_node("NavigationAgent3D").set_navigation_map(world_map)
	check.call(bool(off_mesh_goon.call("configure", factions, "gang_a")), "off-mesh fixture agent configures")
	off_mesh_driver.set("unreachable_timeout_seconds", 0.25)
	for _ready_frame: int in range(60):
		await tree.physics_frame
		if bool(off_mesh_driver.get("has_last_valid_position")):
			break
	var recovery_point: Vector3 = off_mesh_driver.get("last_valid_position")
	check.call(bool(off_mesh_driver.get("has_last_valid_position")), "fresh agent records a point after the map is ready")
	off_mesh_goon.global_position = Vector3(0.0, 5.0, 0.0)
	await tree.physics_frame
	check.call(off_mesh_goon.global_position.distance_to(recovery_point) < 0.1, "off-mesh spawn returns to most recent valid nav point")
	region.queue_free()
	await tree.physics_frame
	var map_point: Vector3 = off_mesh_driver.get("last_valid_position")
	for _frame: int in range(RECOVERY_TIMEOUT_FRAMES):
		await tree.physics_frame
		if not is_instance_valid(off_mesh_goon) or off_mesh_goon.is_queued_for_deletion():
			break
	check.call(not is_instance_valid(off_mesh_goon) or off_mesh_goon.global_position.distance_to(map_point) < 0.1, "navigation map removal recovers to last valid point or safely despawns")
	if is_instance_valid(goon):
		goon.queue_free()
	if is_instance_valid(off_mesh_goon):
		off_mesh_goon.queue_free()
	await tree.physics_frame
	queue_free()


func _make_wall_route_mesh() -> NavigationMesh:
	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_radius = 0.1
	var vertices: PackedVector3Array = PackedVector3Array()
	var vertex_ids: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	for low_z: float in [-4.0, -2.0, 2.0]:
		var high_z: float = low_z + 2.0
		polygons.append(_rectangle_vertices(vertices, vertex_ids, Vector2(-4.0, low_z), Vector2(-1.0, high_z)))
		polygons.append(_rectangle_vertices(vertices, vertex_ids, Vector2(1.0, low_z), Vector2(4.0, high_z)))
	polygons.append(_rectangle_vertices(vertices, vertex_ids, Vector2(-1.0, 2.0), Vector2(1.0, 4.0)))
	polygons.append(_rectangle_vertices(vertices, vertex_ids, Vector2(-1.0, -4.0), Vector2(1.0, -2.0)))
	nav_mesh.vertices = vertices
	for polygon: PackedInt32Array in polygons:
		nav_mesh.add_polygon(polygon)
	return nav_mesh


func _rectangle_vertices(vertices: PackedVector3Array, ids: Dictionary, low: Vector2, high: Vector2) -> PackedInt32Array:
	var a: int = _vertex_id(Vector3(low.x, 0.0, high.y), vertices, ids)
	var b: int = _vertex_id(Vector3(high.x, 0.0, high.y), vertices, ids)
	var c: int = _vertex_id(Vector3(high.x, 0.0, low.y), vertices, ids)
	var d: int = _vertex_id(Vector3(low.x, 0.0, low.y), vertices, ids)
	return PackedInt32Array([a, b, c, d])


func _vertex_id(point: Vector3, vertices: PackedVector3Array, ids: Dictionary) -> int:
	var key: Vector3i = Vector3i(roundi(point.x * 100.0), roundi(point.y * 100.0), roundi(point.z * 100.0))
	if ids.has(key):
		return int(ids[key])
	var index: int = vertices.size()
	vertices.append(point)
	ids[key] = index
	return index


func _on_driver_recovered(reason: StringName, _position: Vector3) -> void:
	_last_recovery_reason = reason
