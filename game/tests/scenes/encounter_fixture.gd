extends Node3D
## AI-05 preview and integration fixture. Ambient projections live under streamed chunks.

const NAVIGATION_BOUNDARY_PATH: String = "res://tests/scenes/navigation_boundary.tscn"
const AMBIENT_UPDATE_INTERVAL: float = 0.75
const AMBIENTS_PER_AREA: int = 2

@export var auto_run: bool = true
@export var show_debug_overlay: bool = true
@export var cleanup_after_run: bool = true

var _boundary: Node3D
var _factions: FactionState
var _populated_chunks: Dictionary = {}
var _ambient_agents: Array[WeakRef] = []
var _peak_ambient_count: int = 0
var _previous_ambient_count: int = 0
var _observed_area_crowd_unload: bool = false
var _alert_log: Array[String] = []
var _running_encounter: bool = false
var _overlay: Label
var _debug_visible: bool = false


func _ready() -> void:
	_factions = FactionState.new(["civilian", "gang_a", "player"])
	_factions.set_faction_standing("gang_a", -50)
	_create_preview_presentation()
	set_process(true)
	if auto_run:
		call_deferred("_run_preview")


func _process(_delta: float) -> void:
	if _boundary == null or not is_instance_valid(_boundary):
		return
	if _running_encounter:
		var streamed_chunks: Node = _boundary.get_node_or_null("StreamedChunks")
		if streamed_chunks == null:
			return
		for chunk: Node in streamed_chunks.get_children():
			if not chunk is Node3D:
				continue
			var chunk_node: Node3D = chunk as Node3D
			var area_id: String = "district_a" if chunk_node.name == "NavigationChunkA" else "district_b" if chunk_node.name == "NavigationChunkB" else ""
			if area_id.is_empty() or _populated_chunks.has(chunk_node):
				continue
			_populated_chunks[chunk_node] = area_id
			_populate_area(chunk_node, area_id)
	elif cleanup_after_run:
		return
	var active_count: int = _get_active_ambient_count()
	_peak_ambient_count = maxi(_peak_ambient_count, active_count)
	if _previous_ambient_count > active_count:
		_observed_area_crowd_unload = true
	_previous_ambient_count = active_count
	_refresh_overlay()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		_refresh_overlay()


func run(check: Callable) -> void:
	if _running_encounter:
		check.call(false, "AI-05 encounter fixture runs once")
		return
	_running_encounter = true
	_boundary = (load(NAVIGATION_BOUNDARY_PATH) as PackedScene).instantiate() as Node3D
	_boundary.name = "NavigationBoundaryFixture"
	add_child(_boundary)
	await get_tree().process_frame
	await _boundary.call("run", check)
	await get_tree().process_frame
	var populated_area_ids: Array[String] = []
	for area_variant: Variant in _populated_chunks.values():
		var area_id: String = String(area_variant)
		if not populated_area_ids.has(area_id):
			populated_area_ids.append(area_id)
	populated_area_ids.sort()
	check.call(populated_area_ids == ["district_a", "district_b"], "authored ambient factions populate both configured streamed areas")
	check.call(_peak_ambient_count >= AMBIENTS_PER_AREA, "ambient population coexists with the seam encounter while both chunks are loaded")
	check.call(_observed_area_crowd_unload, "ambient crowd unloads as its streamed area retires during the seam route")
	check.call(_factions.get_faction_standing("gang_a") == -50, "ambient fixture uses live shared faction standing for alert interpretation")
	if cleanup_after_run:
		_boundary.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		check.call(_get_active_ambient_count() == 0, "ambient crowd projections are released with their streamed chunk owners")
	_running_encounter = false
	_refresh_overlay()


func get_active_ambient_count() -> int:
	return _get_active_ambient_count()


func get_peak_ambient_count() -> int:
	return _peak_ambient_count


func observed_area_crowd_unload() -> bool:
	return _observed_area_crowd_unload


func get_populated_area_ids() -> Array[String]:
	var ids: Array[String] = []
	for area_variant: Variant in _populated_chunks.values():
		var area_id: String = String(area_variant)
		if not ids.has(area_id):
			ids.append(area_id)
	ids.sort()
	return ids


func get_alert_log() -> Array[String]:
	return _alert_log.duplicate()


func _populate_area(chunk: Node3D, area_id: String) -> void:
	var faction_id: String = "civilian" if area_id == "district_a" else "gang_a"
	var center_x: float = -5.0 if area_id == "district_a" else 5.0
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "EncounterFloorVisual"
	floor_mesh.position = Vector3(center_x, -0.22, 0.0)
	var plane: BoxMesh = BoxMesh.new()
	plane.size = Vector3(9.8, 0.15, 9.8)
	var asphalt: StandardMaterial3D = StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.12, 0.16, 0.19, 1.0) if area_id == "district_a" else Color(0.2, 0.12, 0.16, 1.0)
	asphalt.roughness = 0.9
	plane.material = asphalt
	floor_mesh.mesh = plane
	chunk.add_child(floor_mesh)
	for index: int in range(AMBIENTS_PER_AREA):
		var agent: AmbientAgent = AmbientAgent.new()
		agent.name = "%s_%02d" % [area_id, index + 1]
		agent.position = Vector3(center_x + (float(index) - 0.5) * 1.4, 0.0, 2.5 + float(index % 2))
		agent.debug_enabled = _debug_visible
		chunk.add_child(agent)
		if agent.configure(_factions, faction_id, area_id, AMBIENT_UPDATE_INTERVAL):
			agent.status_changed.connect(_on_ambient_status_changed.bind(area_id, agent.name))
			_ambient_agents.append(weakref(agent))
			if index == 0:
				agent.notify_sound_event(agent.global_position + Vector3(0.0, 0.0, -2.5), 4.0, "player")
		else:
			push_warning("Ambient fixture actor failed configuration: %s" % agent.name)


func _on_ambient_status_changed(_status: int, message: String, area_id: String, agent_id: String) -> void:
	var line: String = "%s / %s / %s" % [area_id.to_upper(), agent_id.to_upper(), message]
	_alert_log.append(line)
	if _alert_log.size() > 6:
		_alert_log.pop_front()
	_refresh_overlay()


func _get_active_ambient_count() -> int:
	var count: int = 0
	for weak_agent: WeakRef in _ambient_agents:
		var agent: AmbientAgent = weak_agent.get_ref() as AmbientAgent
		if agent != null and is_instance_valid(agent) and agent.is_inside_tree() and not agent.is_queued_for_deletion():
			count += 1
	return count


func _create_preview_presentation() -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.035, 0.06, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.42, 0.58, 1.0)
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	add_child(environment_node)
	var camera: Camera3D = Camera3D.new()
	camera.name = "EncounterCamera"
	camera.position = Vector3(0.0, 13.0, 20.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	light.light_energy = 2.0
	add_child(light)
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "EncounterHUD"
	add_child(canvas)
	_overlay = Label.new()
	_overlay.name = "EncounterReadout"
	_overlay.position = Vector2(24.0, 24.0)
	_overlay.add_theme_font_size_override("font_size", 18)
	_overlay.add_theme_color_override("font_color", Color(1.0, 0.83, 0.38, 1.0))
	_overlay.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.06, 0.9))
	_overlay.add_theme_constant_override("shadow_offset_x", 2)
	_overlay.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_overlay)
	_refresh_overlay()


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	_overlay.visible = show_debug_overlay
	var lines: Array[String] = ["DISTRICT WATCH  /  AMBIENT SIMULATION", "F3  DEBUG %s  |  ACTIVE %d  |  PEAK %d" % ["ON" if _debug_visible else "OFF", _get_active_ambient_count(), _peak_ambient_count]]
	if _debug_visible:
		for weak_agent: WeakRef in _ambient_agents:
			var agent: AmbientAgent = weak_agent.get_ref() as AmbientAgent
			if agent != null and is_instance_valid(agent) and agent.is_inside_tree():
				agent.debug_enabled = true
				lines.append("%s / %s  UPDATES %d" % [agent.area_id.to_upper(), agent.faction_id.to_upper(), agent.get_update_count()])
	else:
		for index: int in range(_alert_log.size()):
			lines.append(_alert_log[index])
		for weak_agent: WeakRef in _ambient_agents:
			var agent: AmbientAgent = weak_agent.get_ref() as AmbientAgent
			if agent != null and is_instance_valid(agent) and agent.is_inside_tree():
				agent.debug_enabled = false
	_overlay.text = "\n".join(lines)


func _run_preview() -> void:
	await run(Callable(self, "_preview_check"))


func _preview_check(passed: bool, message: String) -> void:
	print("%s AI-05 %s" % ["PASS:" if passed else "FAIL:", message])
