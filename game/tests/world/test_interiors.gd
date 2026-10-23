extends RefCounted

const INTERIOR_PATH: String = "res://world/fixtures/interior.tscn"
const SOURCE_PATH: String = "res://world/fixtures/exterior.tscn"


func run(check: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	var source: PackedScene = load(SOURCE_PATH) as PackedScene
	check.call(source != null, "test exterior scene is available")
	if source == null:
		return
	var source_instance: Node = source.instantiate()
	tree.root.add_child(source_instance)
	tree.current_scene = source_instance
	var exterior_player: Node = source_instance.find_child("Player", true, false)
	if exterior_player is Node3D:
		(exterior_player as Node3D).position = Vector3(3.0, 0.0, 4.0)
	var service: Node = tree.root.get_node_or_null("InteriorTransition")
	check.call(service != null, "interior transition autoload is registered")
	if service == null:
		return
	service.set("fade_seconds", 0.01)
	var registry: Object = load("res://persistence/entity_registry.gd").new()
	registry.call("register_entity", "123e4567-e89b-42d3-a456-426614174000", {"open": false})
	var failures: Array[String] = []
	var finished: Array[String] = []
	service.transition_failed.connect(func(path: String, reason: String) -> void:
		failures.append(path + ":" + reason)
	)
	service.transition_finished.connect(func(path: String) -> void:
		finished.append(path)
	)

	service.call("request_interior_transition", "res://world/fixtures/missing.tscn")
	await _wait_for(tree, service, check)
	check.call(service.get("state") == 0 and failures.size() == 1 and exterior_player != null and not exterior_player.call("is_control_locked"), "missing interior keeps exterior active and restores controls (%s)" % str(failures))

	for cycle: int in range(2):
		service.call("request_interior_transition", INTERIOR_PATH)
		service.call("request_interior_transition", INTERIOR_PATH)
		check.call(service.get("state") != 0, "interior request enters a transition state")
		var active_player: Node = tree.current_scene.find_child("Player", true, false)
		check.call(active_player != null and active_player.call("is_control_locked"), "exterior interaction locks during preload")
		await _wait_for(tree, service, check)
		check.call(tree.current_scene.scene_file_path == INTERIOR_PATH, "interior scene loads asynchronously")
		var interior_player: Node = tree.current_scene.find_child("Player", true, false)
		check.call(interior_player is Node3D and (interior_player as Node3D).global_position.is_equal_approx(Vector3(0, 0, 2)), "interior player uses authored spawn marker (%s)" % (str((interior_player as Node3D).global_position) if interior_player is Node3D else "missing"))
		check.call(registry.call("get_entity_state", "123e4567-e89b-42d3-a456-426614174000") == {"open": false}, "authoritative persistent data survives scene replacement")
		service.call("return_from_interior")
		await _wait_for(tree, service, check)
		check.call(tree.current_scene.scene_file_path == SOURCE_PATH, "return transition restores exterior scene")
		var restored_player: Node = tree.current_scene.find_child("Player", true, false)
		check.call(restored_player is Node3D and (restored_player as Node3D).global_position.is_equal_approx(Vector3(3, 0, 4)), "return transition restores exterior player position")
	check.call(failures.size() >= 3, "duplicate requests are rejected without replacing an active transition")
	check.call(finished.size() == 4, "two enter/exit cycles complete with fades")
	service.call("set_backend_for_testing", PendingBackend.new())
	service.set("load_timeout_msec", 1)
	service.call("request_interior_transition", INTERIOR_PATH)
	for _frame: int in range(5):
		await tree.process_frame
	check.call(service.get("state") == 0 and failures.back().contains("timed out"), "timed-out load restores controls and leaves the current scene active")
	check.call(service.call("reset_backend"), "transition coordinator restores its native resource backend")


func _wait_for(tree: SceneTree, service: Node, check: Callable) -> void:
	for _frame: int in range(240):
		if int(service.get("state")) == 0:
			return
		await tree.process_frame
	check.call(false, "interior transition finishes within timeout")


class PendingBackend extends RefCounted:
	func request(_path: String) -> int:
		return OK

	func status(_path: String) -> int:
		return ResourceLoader.THREAD_LOAD_IN_PROGRESS

	func get_scene(_path: String) -> PackedScene:
		return null
