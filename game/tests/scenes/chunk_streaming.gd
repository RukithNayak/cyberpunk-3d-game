extends Node3D
## Automated physical traversal evidence for WORLD-02; not the player controller.

enum Phase { APPROACH, BLOCKED, FAILURE, CROSS, RETURN, FINISHED }

const CHUNK_A: String = "res://world/fixtures/chunk_a.tscn"
const CHUNK_B: String = "res://world/fixtures/chunk_b.tscn"
const EVIDENCE: String = "res://../docs/evidence/WORLD-02"

var _phase: Phase = Phase.APPROACH
var _elapsed: float = 0.0
var _phase_elapsed: float = 0.0
var _manager: WorldManager = WorldManager.new()
var _loader: ChunkLoader = ChunkLoader.new()
var _backend: DelayedNeighborBackend = DelayedNeighborBackend.new()
var _chunks: Node3D = Node3D.new()
var _body: CharacterBody3D = CharacterBody3D.new()
var _camera: Camera3D = Camera3D.new()
var _overview: Camera3D = Camera3D.new()
var _label: Label = Label.new()
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _initial_floor_id: int = 0


func _ready() -> void:
	var manifest: ChunkManifest = ChunkManifest.new()
	var records: Array[Dictionary] = [
		{"id": "chunk_a", "bounds": AABB(Vector3(-10, -2, -10), Vector3(10, 8, 20)), "scene_path": CHUNK_A, "adjacent": ["chunk_b"]},
		{"id": "chunk_b", "bounds": AABB(Vector3(0, -2, -10), Vector3(10, 8, 20)), "scene_path": CHUNK_B, "adjacent": ["chunk_a"]}
	]
	assert(manifest.configure(records))
	assert(_manager.configure(manifest, 1.0, 0.0))
	_chunks.name = "ActiveChunks"
	add_child(_chunks)
	add_child(_loader)
	assert(_loader.configure(_manager, manifest, _chunks, _backend, 1, 10000))
	_loader.chunk_failed.connect(_on_chunk_failed)
	_body.name = "TraversalProbe"
	_body.position = Vector3(-2.0, 0.85, 2.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	collision.shape = capsule
	_body.add_child(collision)
	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: CapsuleMesh = CapsuleMesh.new()
	marker_mesh.radius = 0.25
	marker_mesh.height = 1.6
	marker.mesh = marker_mesh
	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.68, 0.16)
	marker.material_override = marker_material
	_body.add_child(marker)
	_camera.position.y = 0.8
	_camera.rotation.y = -PI * 0.5
	_camera.current = true
	_body.add_child(_camera)
	add_child(_body)
	_overview.position = Vector3(0, 11, 13)
	add_child(_overview)
	_overview.look_at(Vector3(0, 0, 2))
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.09, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.75, 1.0)
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	add_child(environment_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	var canvas: CanvasLayer = CanvasLayer.new()
	_label.position = Vector2(24, 22)
	_label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(_label)
	add_child(canvas)
	_manager.update_player_position(_body.position)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_phase_elapsed += delta
	if _phase == Phase.FINISHED:
		return
	if _elapsed > 18.0:
		_check(false, "streaming traversal completes before watchdog")
		_finish()
		return
	_manager.update_player_position(_body.position)
	if _loader.get_active_instance("chunk_a") == null and _phase == Phase.APPROACH:
		return
	_body.velocity.x = -1.8 if _phase == Phase.RETURN else 1.8
	_body.velocity.y -= 18.0 * delta
	_body.move_and_slide()
	_label.text = "WORLD-02  /  STREAMING BOUNDARY\n%s\nx %.2f m   y %.2f m" % [Phase.keys()[_phase], _body.position.x, _body.position.y]
	match _phase:
		Phase.APPROACH:
			if _body.position.x > -0.6 and _loader.has_seam_barrier("chunk_a", "chunk_b"):
				_initial_floor_id = _loader.get_active_instance("chunk_a").get_instance_id()
				_transition(Phase.BLOCKED)
		Phase.BLOCKED:
			if _phase_elapsed >= 1.0:
				_check(_body.position.x < -0.25 and _body.is_on_floor(), "real capsule cannot cross the unavailable seam or fall through")
				_transition(Phase.FAILURE)
				await _capture("blocked-seam")
				_backend.fail_neighbor = true
		Phase.FAILURE:
			if not _failures.is_empty():
				_check(_loader.get_active_instance("chunk_a").get_instance_id() == _initial_floor_id and _body.is_on_floor(), "neighbor resource failure preserves current terrain and physical support")
				_backend.fail_neighbor = false
				_backend.allow_neighbor = true
				_check(_loader.retry_chunk("chunk_b"), "failed neighbor permits an explicit retry")
				_transition(Phase.CROSS)
		Phase.CROSS:
			if _body.position.x >= 2.4:
				_check(_loader.get_active_instance("chunk_b") != null and _body.is_on_floor(), "retry opens the seam and capsule walks onto loaded neighbor")
				_check(_loader.get_active_instance("chunk_a") == null, "departure unloads the old chunk while destination remains solid")
				_camera.rotation.y = PI * 0.5
				_transition(Phase.RETURN)
				await _capture("crossed-seam")
		Phase.RETURN:
			if _body.position.x <= -2.2:
				_check(_loader.get_active_instance("chunk_a") != null and _body.is_on_floor(), "capsule backtracks across the reloaded seam without falling")
				_check(_chunks.find_children("ChunkA", "Node3D", true, false).size() == 1 and _chunks.find_children("ChunkB", "Node3D", true, false).size() <= 1, "backtracking retains at most one scene instance per chunk")
				_finish()


func _transition(next_phase: Phase) -> void:
	_phase = next_phase
	_phase_elapsed = 0.0


func _on_chunk_failed(payload: Dictionary, reason: String) -> void:
	if payload["chunk_id"] == "chunk_b":
		_failures.append(reason)


func _check(passed: bool, description: String) -> void:
	_checks.append({"passed": passed, "description": description})
	print("WORLD-02 %s: %s" % ["PASS" if passed else "FAIL", description])


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_overview.current = true
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(EVIDENCE).path_join(label + ".png")
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	_camera.current = true
	_check(error == OK, "rendered capture saved: " + label)


func _finish() -> void:
	_phase = Phase.FINISHED
	set_physics_process(false)
	var passed: bool = true
	for result: Dictionary in _checks:
		passed = passed and result["passed"]
	_label.text = "WORLD-02  /  %s\nBlocked seam, failure, retry and backtracking verified" % ["PASS" if passed else "FAIL"]
	await _capture("returned-seam")
	for result: Dictionary in _checks:
		passed = passed and result["passed"]
	var mode: String = "headless" if DisplayServer.get_name() == "headless" else "rendered"
	var path: String = ProjectSettings.globalize_path(EVIDENCE).path_join("runtime-" + mode + ".json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("WORLD-02 could not write traversal evidence")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": _checks, "duration_seconds": _elapsed, "neighbor_failures": _failures, "godot": Engine.get_version_info()["string"], "display_server": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "resolution": get_viewport().get_visible_rect().size, "physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT")}, "\t"))
	file.close()
	print("WORLD-02 traversal %s: %d checks; %s" % ["PASS" if passed else "FAIL", _checks.size(), mode])
	if mode == "headless" or OS.get_cmdline_user_args().has("--verify"):
		get_tree().quit(0 if passed else 1)


class DelayedNeighborBackend extends RefCounted:
	## Real threaded resources; only neighbor status is delayed/failed for the scenario.
	var allow_neighbor: bool = false
	var fail_neighbor: bool = false
	var _backend: RefCounted = ChunkLoader._ResourceBackend.new()

	func request(path: String) -> bool:
		return _backend.call("request", path)

	func status(path: String) -> int:
		if path == CHUNK_B:
			if fail_neighbor:
				return -1
			if not allow_neighbor:
				return ResourceLoader.THREAD_LOAD_IN_PROGRESS
		return _backend.call("status", path)

	func get_resource(path: String) -> Resource:
		return _backend.call("get_resource", path)
