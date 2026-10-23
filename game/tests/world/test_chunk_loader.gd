extends RefCounted

const LOADER_PATH: String = "res://world/chunk_loader.gd"
const MANIFEST_PATH: String = "res://world/chunk_manifest.gd"
const MANAGER_PATH: String = "res://world/world_manager.gd"
const CHUNK_A: String = "res://world/fixtures/chunk_a.tscn"
const CHUNK_B: String = "res://world/fixtures/chunk_b.tscn"

var clock_msec: int = 0


func run(check: Callable) -> void:
	var loader_script: Script = load(LOADER_PATH) as Script
	check.call(loader_script != null, "chunk loader script compiles and is available")
	if loader_script == null:
		return
	_test_delayed_duplicate_budget_and_cleanup(check, loader_script)
	_test_out_of_order_completion(check, loader_script)
	_test_active_reentry(check, loader_script)
	_test_stale_completion_and_retry(check, loader_script)
	_test_timeout_retry(check, loader_script)
	_test_missing_resource_retry(check, loader_script)
	_test_retained_terrain_barrier(check, loader_script)
	await _test_ready_callback_invalidates_activation(check, loader_script)
	_test_manager_callback_invalidates_activation(check, loader_script)
	_test_retained_callback_invalidates_activation(check, loader_script)
	_test_recursive_pump_preserves_budget(check, loader_script)
	await _test_threaded_resource_progress(check, loader_script)
	await _test_native_backend_coalesces_loaded_retry(check)
	await _test_cancelled_native_request_cleanup(check, loader_script)


func _test_delayed_duplicate_budget_and_cleanup(check: Callable, loader_script: Script) -> void:
	var context: Dictionary = _make_context(loader_script, FakeBackend.new(), 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	var backend: FakeBackend = context["backend"]
	manager.call("update_player_position", Vector3(-1.0, 0.0, 0.0))
	loader.call("pump_frame")
	check.call(backend.request_count[CHUNK_A] == 1 and backend.request_count[CHUNK_B] == 1, "desired chunk requests start once")
	loader.call("pump_frame")
	check.call(backend.request_count[CHUNK_A] == 1 and backend.request_count[CHUNK_B] == 1, "repeated desired state coalesces duplicate requests")
	backend.complete(CHUNK_B)
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") != null and loader.call("get_active_instance", "chunk_b") == null, "activation budget limits simultaneously ready scenes to one per frame")
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_b") != null, "remaining ready scene activates on following frame")
	check.call((context["root"] as Node).find_children("ChunkA", "Node3D", true, false).size() == 1, "duplicate requests produce exactly one instance for each chunk")
	check.call(manager.call("get_load_state", "chunk_a") == 2 and manager.call("get_load_state", "chunk_b") == 2, "successful activation is acknowledged with current generations")
	manager.call("update_player_position", Vector3(40.0, 0.0, 0.0))
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") == null and loader.call("get_active_instance", "chunk_b") == null, "leaving desired set frees both transient instances")
	check.call(loader.call("get_pending_request_count") == 0 and manager.call("get_load_state", "chunk_a") == 0 and manager.call("get_load_state", "chunk_b") == 0, "unload cleans pending work and acknowledges deactivation")
	_free_context(context)


func _test_out_of_order_completion(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	manager.call("update_player_position", Vector3(-1.0, 0.0, 0.0))
	loader.call("pump_frame")
	backend.complete(CHUNK_B)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_b") != null and loader.call("get_active_instance", "chunk_a") == null, "later chunk request can complete and activate before earlier request")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") != null, "earlier request activates when its own resource completes")
	_free_context(context)


func _test_active_reentry(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	var activation_generations: Array[int] = []
	loader.connect("chunk_activated", func(payload: Dictionary, _instance: Node3D) -> void: activation_generations.append(payload["lifecycle_generation"]))
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	var original_instance: Node3D = loader.call("get_active_instance", "chunk_a") as Node3D
	var original_generation: int = manager.call("get_lifecycle_generation", "chunk_a")
	manager.call("update_player_position", Vector3(40.0, 0.0, 0.0))
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") == original_instance and backend.request_count[CHUNK_A] == 1, "rapid active-chunk re-entry retains one instance without a new resource request")
	check.call(manager.call("get_lifecycle_generation", "chunk_a") > original_generation and manager.call("get_load_state", "chunk_a") == 2, "retained instance is acknowledged under the fresh desired generation")
	check.call(activation_generations.size() == 2 and activation_generations[1] > activation_generations[0], "loader publishes activation for the fresh retained-instance generation")
	_free_context(context)


func _test_stale_completion_and_retry(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	var old_generation: int = manager.call("get_lifecycle_generation", "chunk_a")
	manager.call("update_player_position", Vector3(40.0, 0.0, 0.0))
	loader.call("pump_frame")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") == null and loader.call("get_pending_request_count") == 0, "completion after unload cannot activate obsolete generation")
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	var new_generation: int = manager.call("get_lifecycle_generation", "chunk_a")
	check.call(new_generation > old_generation and backend.request_count[CHUNK_A] == 2, "re-entry starts a fresh generation and retry request")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") != null and manager.call("get_load_state", "chunk_a") == 2, "only the current re-entry generation becomes active")
	_free_context(context)


func _test_timeout_retry(check: Callable, loader_script: Script) -> void:
	clock_msec = 0
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 50)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	var failures: Array[Dictionary] = []
	loader.connect("chunk_failed", func(payload: Dictionary, reason: String) -> void: failures.append({"payload": payload, "reason": reason}))
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	clock_msec = 51
	loader.call("pump_frame")
	check.call(failures.size() == 1 and failures[0]["reason"] == "timeout", "delayed request times out without blocking")
	check.call(loader.call("get_pending_request_count") == 0 and loader.call("get_active_instance", "chunk_a") == null, "timeout clears pending work and preserves active terrain state")
	loader.call("pump_frame")
	check.call(backend.request_count[CHUNK_A] == 1, "timed out generation does not hot-loop retries")
	check.call(loader.call("retry_chunk", "chunk_a"), "desired chunk permits explicit retry after timeout")
	loader.call("pump_frame")
	check.call(backend.request_count[CHUNK_A] == 2, "retry starts another asynchronous request")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") != null, "timed-out chunk can activate after retry")
	_free_context(context)


func _test_missing_resource_retry(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	backend.request_results[CHUNK_A] = false
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	var failures: Array[String] = []
	loader.connect("chunk_failed", func(_payload: Dictionary, reason: String) -> void: failures.append(reason))
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	check.call(failures == ["request_failed"] and loader.call("get_pending_request_count") == 0, "missing resource failure clears request and publishes failure")
	check.call(loader.call("retry_chunk", "chunk_a"), "missing resource can be retried")
	backend.request_results.erase(CHUNK_A)
	loader.call("pump_frame")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") != null, "successful retry recovers missing chunk")
	_free_context(context)


func _test_retained_terrain_barrier(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	backend.request_results[CHUNK_B] = false
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	manager.call("update_player_position", Vector3(-0.5, 0.0, 0.0))
	loader.call("pump_frame")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	var retained: Node3D = loader.call("get_active_instance", "chunk_a") as Node3D
	check.call(retained != null, "already available terrain activates while neighbor remains unavailable")
	check.call(loader.call("has_seam_barrier", "chunk_a", "chunk_b"), "collision barrier blocks unavailable seam")
	check.call(retained != null and is_instance_valid(retained) and retained.get_node_or_null("Ground/Collision") != null, "neighbor failure does not remove valid current floor collision")
	check.call(loader.call("retry_chunk", "chunk_b"), "failed neighbor can be retried while current terrain remains desired")
	backend.request_results.erase(CHUNK_B)
	loader.call("pump_frame")
	backend.complete(CHUNK_B)
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_b") != null and not loader.call("has_seam_barrier", "chunk_a", "chunk_b"), "barrier clears only after neighboring terrain is active")
	_free_context(context)


func _test_ready_callback_invalidates_activation(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	loader.set_process(false)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var events: Array[Dictionary] = []
	loader.connect("chunk_activated", func(payload: Dictionary, _instance: Node3D) -> void: events.append(payload))
	(context["root"] as Node).set_meta("redirect_on_ready", Callable(manager, "update_player_position").bind(Vector3(40.0, 0.0, 0.0)))
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	var source: Node3D = Node3D.new()
	source.name = "RedirectOnReady"
	source.set_script(load("res://tests/world/fixtures/activation_redirect.gd"))
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(source) == OK)
	source.free()
	backend.resources[CHUNK_A] = packed
	backend.states[CHUNK_A] = ResourceLoader.THREAD_LOAD_LOADED
	loader.call("pump_frame")
	check.call(events.is_empty(), "scene ready invalidation cannot publish stale activation")
	check.call(loader.call("get_active_instance", "chunk_a") == null and loader.call("get_pending_request_count") == 0, "scene ready invalidation retires the unwanted instance and request")
	_free_context(context)


func _test_manager_callback_invalidates_activation(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	var events: Array[Dictionary] = []
	loader.connect("chunk_activated", func(payload: Dictionary, _instance: Node3D) -> void: events.append(payload))
	manager.connect("chunk_activated", Callable(manager, "update_player_position").bind(Vector3(40.0, 0.0, 0.0)).unbind(1))
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	check.call(events.is_empty(), "manager activation listener cannot cause a stale loader activation event")
	check.call(loader.call("get_active_instance", "chunk_a") == null and manager.call("get_load_state", "chunk_a") == 0, "manager activation invalidation retires terrain and acknowledges deactivation")
	_free_context(context)


func _test_retained_callback_invalidates_activation(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	backend.complete(CHUNK_A)
	loader.call("pump_frame")
	var events: Array[Dictionary] = []
	loader.connect("chunk_activated", func(payload: Dictionary, _instance: Node3D) -> void: events.append(payload))
	manager.connect("chunk_activated", Callable(manager, "update_player_position").bind(Vector3(40.0, 0.0, 0.0)).unbind(1))
	manager.call("update_player_position", Vector3(40.0, 0.0, 0.0))
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	check.call(events.is_empty() and loader.call("get_active_instance", "chunk_a") == null, "retained-instance callback invalidation cannot publish or retain stale activation")
	_free_context(context)


func _test_recursive_pump_preserves_budget(check: Callable, loader_script: Script) -> void:
	var backend: FakeBackend = FakeBackend.new()
	var context: Dictionary = _make_context(loader_script, backend, 1, 500)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	manager.call("update_player_position", Vector3(-0.5, 0.0, 0.0))
	loader.call("pump_frame")
	backend.complete(CHUNK_A)
	backend.complete(CHUNK_B)
	manager.connect("chunk_activated", func(_payload: Dictionary) -> void: loader.call("pump_frame"))
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_a") != null and loader.call("get_active_instance", "chunk_b") == null, "recursive activation callbacks cannot exceed the outer pump activation budget")
	loader.call("pump_frame")
	check.call(loader.call("get_active_instance", "chunk_b") != null, "recursive pump guard leaves remaining activation eligible for the next frame")
	_free_context(context)


func _test_threaded_resource_progress(check: Callable, loader_script: Script) -> void:
	var context: Dictionary = _make_context(loader_script, null, 1, 5000)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var frame_count_before: int = Engine.get_process_frames()
	var deadline_msec: int = Time.get_ticks_msec() + 5000
	while loader.call("get_active_instance", "chunk_a") == null and Time.get_ticks_msec() < deadline_msec:
		await tree.process_frame
	check.call(Engine.get_process_frames() > frame_count_before, "real threaded ResourceLoader integration advances process frames")
	check.call(loader.call("get_active_instance", "chunk_a") != null, "real ResourceLoader completion activates fixture after frame polling")
	_free_context(context)


func _test_native_backend_coalesces_loaded_retry(check: Callable) -> void:
	var backend: RefCounted = ChunkLoader._ResourceBackend.new()
	var started: bool = backend.call("request", CHUNK_B)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var deadline: int = Time.get_ticks_msec() + 5000
	while backend.call("status", CHUNK_B) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var retried: bool = backend.call("request", CHUNK_B)
	var resource: Resource = backend.call("get_resource", CHUNK_B)
	var after_consume: int = ResourceLoader.load_threaded_get_status(CHUNK_B)
	check.call(started and retried and resource is PackedScene and after_consume == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "native retry coalesces a completed request without leaving an extra engine load token")
	# Drain the known extra token on the unfixed backend so the red fixture itself is clean.
	if after_consume == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(CHUNK_B)


func _test_cancelled_native_request_cleanup(check: Callable, loader_script: Script) -> void:
	var context: Dictionary = _make_context(loader_script, null, 1, 5000)
	var manager: Object = context["manager"]
	var loader: Node = context["loader"]
	loader.set_process(false)
	manager.call("update_player_position", Vector3(-5.0, 0.0, 0.0))
	loader.call("pump_frame")
	manager.call("update_player_position", Vector3(40.0, 0.0, 0.0))
	loader.call("pump_frame")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var deadline: int = Time.get_ticks_msec() + 5000
	while ResourceLoader.load_threaded_get_status(CHUNK_A) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	loader.call("pump_frame")
	var final_status: int = ResourceLoader.load_threaded_get_status(CHUNK_A)
	check.call(final_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and loader.call("get_active_instance", "chunk_a") == null, "cancelled native completion releases its engine token without activating stale terrain")
	if final_status == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(CHUNK_A)
	_free_context(context)


func _make_context(loader_script: Script, backend: Object, activation_budget: int, timeout_msec: int) -> Dictionary:
	var manifest_script: Script = load(MANIFEST_PATH) as Script
	var manager_script: Script = load(MANAGER_PATH) as Script
	var manifest: Object = manifest_script.new()
	var records: Array[Dictionary] = [
		{"id": "chunk_a", "bounds": AABB(Vector3(-10.0, -2.0, -10.0), Vector3(10.0, 8.0, 20.0)), "scene_path": CHUNK_A, "adjacent": ["chunk_b"]},
		{"id": "chunk_b", "bounds": AABB(Vector3(0.0, -2.0, -10.0), Vector3(10.0, 8.0, 20.0)), "scene_path": CHUNK_B, "adjacent": ["chunk_a"]}
	]
	assert(manifest.call("configure", records))
	var manager: Object = manager_script.new()
	assert(manager.call("configure", manifest, 1.0, 0.0))
	var root: Node = Node.new()
	root.name = "ChunkLoaderTestRoot"
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var loader: Node = loader_script.new()
	root.add_child(loader)
	var clock: Callable = Callable(self, "_read_clock")
	var configured: bool = loader.call("configure", manager, manifest, root, backend, activation_budget, timeout_msec, clock)
	assert(configured)
	return {"manager": manager, "manifest": manifest, "root": root, "loader": loader, "backend": backend}


func _free_context(context: Dictionary) -> void:
	var root: Node = context["root"] as Node
	if is_instance_valid(root):
		root.queue_free()


func _read_clock() -> int:
	return clock_msec


class FakeBackend extends RefCounted:
	var states: Dictionary = {}
	var resources: Dictionary = {}
	var request_count: Dictionary = {}
	var request_results: Dictionary = {}

	func request(scene_path: String) -> bool:
		request_count[scene_path] = int(request_count.get(scene_path, 0)) + 1
		states[scene_path] = ResourceLoader.THREAD_LOAD_IN_PROGRESS
		return bool(request_results.get(scene_path, true))

	func status(scene_path: String) -> int:
		return int(states.get(scene_path, ResourceLoader.THREAD_LOAD_IN_PROGRESS))

	func get_resource(scene_path: String) -> Resource:
		return resources.get(scene_path) as Resource

	func complete(scene_path: String) -> void:
		states[scene_path] = ResourceLoader.THREAD_LOAD_LOADED
		resources[scene_path] = load(scene_path)
