extends Node
class_name ChunkLoader

## Owns transient chunk requests, instances and temporary seam collision.
## Resource polling is non-blocking; at most max_activations_per_frame scenes
## are instantiated by each pump_frame() call.

signal chunk_activated(payload: Dictionary, instance: Node3D)
signal chunk_failed(payload: Dictionary, reason: String)
signal chunk_unloaded(payload: Dictionary)

const DEFAULT_TIMEOUT_MSEC: int = 15000
const TOUCH_EPSILON: float = 0.001
const BARRIER_THICKNESS: float = 0.2

var max_activations_per_frame: int = 1
var request_timeout_msec: int = DEFAULT_TIMEOUT_MSEC

var _manager: WorldManager
var _manifest: ChunkManifest
var _activation_root: Node
var _backend: Object
var _clock: Callable
var _entity_lifecycle: Object
var _configured: bool = false
var _pumping: bool = false
var _requests: Dictionary = {}
var _failed_generation: Dictionary = {}
var _instances: Dictionary = {}
var _instance_generations: Dictionary = {}
var _barriers: Dictionary = {}


func configure(
	manager: WorldManager,
	manifest: ChunkManifest,
	activation_root: Node,
	backend: Object = null,
	configured_activation_budget: int = 1,
	configured_timeout_msec: int = DEFAULT_TIMEOUT_MSEC,
	configured_clock: Callable = Callable(),
	entity_lifecycle: Object = null
) -> bool:
	if _configured or manager == null or manifest == null or activation_root == null:
		return false
	if configured_activation_budget < 1 or configured_timeout_msec < 1:
		return false
	if entity_lifecycle != null:
		for method: String in ["prepare_chunk", "activate_chunk", "retire_chunk"]:
			if not entity_lifecycle.has_method(method):
				return false
	_entity_lifecycle = entity_lifecycle
	_manager = manager
	_manifest = manifest
	_activation_root = activation_root
	_backend = backend if backend != null else _ResourceBackend.new()
	_clock = configured_clock
	max_activations_per_frame = configured_activation_budget
	request_timeout_msec = configured_timeout_msec
	if not _backend.has_method("request") or not _backend.has_method("status") or not _backend.has_method("get_resource"):
		return false
	for chunk_id: String in _manifest.get_chunk_ids():
		var record: Dictionary = _manifest.get_chunk(chunk_id)
		if record.is_empty() or not _manager.has_method("get_desired_chunk_ids"):
			return false
	_configured = true
	set_process(true)
	return true


func _process(_delta: float) -> void:
	pump_frame()


## One deterministic streaming step. The engine calls this once per process frame.
func pump_frame() -> void:
	if not _configured or _pumping:
		return
	_pumping = true
	_sync_lifecycle()
	_poll_requests()
	_activate_ready()
	_release_unused_resources()
	_update_seam_barriers()
	_pumping = false


func retry_chunk(chunk_id: String) -> bool:
	if not _configured or not _manifest.get_chunk_ids().has(chunk_id):
		return false
	if not _manager.get_desired_chunk_ids().has(chunk_id):
		return false
	_failed_generation.erase(chunk_id)
	return true


func get_pending_request_count() -> int:
	return _requests.size()


func get_active_instance(chunk_id: String) -> Node3D:
	return _instances.get(chunk_id) as Node3D


func has_seam_barrier(chunk_id: String, neighbor_id: String) -> bool:
	var edges: Dictionary = _barriers.get(chunk_id, {})
	return edges.has(neighbor_id)


func _sync_lifecycle() -> void:
	var desired: Array[String] = _manager.get_desired_chunk_ids()
	for chunk_id: String in _manifest.get_chunk_ids():
		var is_desired: bool = desired.has(chunk_id)
		var generation: int = _manager.get_lifecycle_generation(chunk_id)
		if is_desired:
			if _instances.has(chunk_id):
				if int(_instance_generations.get(chunk_id, -1)) != generation:
					_instance_generations[chunk_id] = generation
					if not _prepare_entities(chunk_id, generation, _instances[chunk_id]):
						_retire_invalid_activation(chunk_id, generation)
						_fail_request(chunk_id, generation, "entity_preparation_failed")
						continue
					_finish_activation(chunk_id, generation, _instances[chunk_id])
				continue
			if _failed_generation.get(chunk_id, -1) == generation:
				continue
			if not _requests.has(chunk_id) or int(_requests[chunk_id]["generation"]) != generation:
				_start_request(chunk_id, generation)
		else:
			if _requests.has(chunk_id):
				_requests.erase(chunk_id)
			if _instances.has(chunk_id):
				_unload_chunk(chunk_id, generation)


func _start_request(chunk_id: String, generation: int) -> void:
	var record: Dictionary = _manifest.get_chunk(chunk_id)
	var scene_path: String = record.get("scene_path", "")
	var started: bool = bool(_backend.call("request", scene_path))
	if not started:
		_fail_request(chunk_id, generation, "request_failed")
		return
	_requests[chunk_id] = {
		"scene_path": scene_path,
		"generation": generation,
		"started_msec": _now_msec(),
		"ready": false
	}


func _poll_requests() -> void:
	var chunk_ids: Array[String] = []
	for key: Variant in _requests:
		chunk_ids.append(String(key))
	chunk_ids.sort()
	for chunk_id: String in chunk_ids:
		if not _requests.has(chunk_id):
			continue
		var request: Dictionary = _requests[chunk_id]
		var generation: int = int(request["generation"])
		if not _is_currently_desired(chunk_id, generation):
			_requests.erase(chunk_id)
			continue
		if _now_msec() - int(request["started_msec"]) >= request_timeout_msec:
			_requests.erase(chunk_id)
			_fail_request(chunk_id, generation, "timeout")
			continue
		var status: int = int(_backend.call("status", request["scene_path"]))
		if status < 0:
			_requests.erase(chunk_id)
			_fail_request(chunk_id, generation, "missing_or_failed_resource")
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			request["ready"] = true
			_requests[chunk_id] = request


func _activate_ready() -> void:
	var ready_ids: Array[String] = []
	for key: Variant in _requests:
		if bool(_requests[key]["ready"]):
			ready_ids.append(String(key))
	ready_ids.sort()
	var activated_count: int = 0
	for chunk_id: String in ready_ids:
		if activated_count >= max_activations_per_frame:
			break
		if not _requests.has(chunk_id):
			continue
		var request: Dictionary = _requests[chunk_id]
		var generation: int = int(request["generation"])
		if not _is_currently_desired(chunk_id, generation):
			_requests.erase(chunk_id)
			continue
		var packed_scene: PackedScene = _backend.call("get_resource", request["scene_path"]) as PackedScene
		if packed_scene == null or not packed_scene.can_instantiate():
			_requests.erase(chunk_id)
			_fail_request(chunk_id, generation, "invalid_packed_scene")
			continue
		var instance: Node3D = packed_scene.instantiate() as Node3D
		if instance == null:
			_requests.erase(chunk_id)
			_fail_request(chunk_id, generation, "invalid_scene_root")
			continue
		activated_count += 1
		if not _prepare_entities(chunk_id, generation, instance):
			if _entity_lifecycle != null and is_instance_valid(instance):
				_entity_lifecycle.call("retire_chunk", chunk_id, generation, instance)
			if is_instance_valid(instance):
				instance.free()
			_requests.erase(chunk_id)
			_fail_request(chunk_id, generation, "entity_preparation_failed")
			continue
		_activation_root.add_child(instance)
		_instances[chunk_id] = instance
		_instance_generations[chunk_id] = generation
		_requests.erase(chunk_id)
		_finish_activation(chunk_id, generation, instance)


func _finish_activation(chunk_id: String, generation: int, instance: Node3D) -> void:
	# Scene entry and manager acknowledgements both invoke synchronous user callbacks.
	# Recheck after each boundary before publishing an accepted loader activation.
	if not _is_currently_desired(chunk_id, generation) or not is_instance_valid(instance) or instance.is_queued_for_deletion():
		_retire_invalid_activation(chunk_id, generation)
		return
	if _entity_lifecycle != null:
		var activated: Variant = _entity_lifecycle.call("activate_chunk", chunk_id, generation, instance)
		if typeof(activated) != TYPE_BOOL or not activated:
			_retire_invalid_activation(chunk_id, generation)
			_fail_request(chunk_id, generation, "entity_activation_failed")
			return
		if not _is_currently_desired(chunk_id, generation) or not is_instance_valid(instance) or instance.is_queued_for_deletion():
			_retire_invalid_activation(chunk_id, generation)
			return
	var acknowledged: bool = _manager.acknowledge_activated(chunk_id, generation)
	if not acknowledged or not _is_currently_desired(chunk_id, generation) or not is_instance_valid(instance) or instance.is_queued_for_deletion():
		_retire_invalid_activation(chunk_id, generation)
		return
	chunk_activated.emit(_payload(chunk_id, generation), instance)
	if not _is_currently_desired(chunk_id, generation):
		_retire_invalid_activation(chunk_id, generation)


func _prepare_entities(chunk_id: String, generation: int, instance: Node3D) -> bool:
	if _entity_lifecycle == null:
		return true
	var prepared: Variant = _entity_lifecycle.call("prepare_chunk", chunk_id, generation, instance)
	return typeof(prepared) == TYPE_BOOL and prepared and _is_currently_desired(chunk_id, generation) \
		and is_instance_valid(instance) and not instance.is_queued_for_deletion()


func _retire_invalid_activation(chunk_id: String, generation: int) -> void:
	var retired_generation: int = generation
	if not _manager.get_desired_chunk_ids().has(chunk_id):
		retired_generation = _manager.get_lifecycle_generation(chunk_id)
	_unload_chunk(chunk_id, retired_generation)


func _unload_chunk(chunk_id: String, generation: int) -> void:
	var instance: Node3D = _instances[chunk_id]
	_instances.erase(chunk_id)
	_instance_generations.erase(chunk_id)
	if _entity_lifecycle != null and is_instance_valid(instance):
		_entity_lifecycle.call("retire_chunk", chunk_id, generation, instance)
	if is_instance_valid(instance):
		instance.queue_free()
	_manager.acknowledge_deactivated(chunk_id, generation)
	chunk_unloaded.emit(_payload(chunk_id, generation))


func _fail_request(chunk_id: String, generation: int, reason: String) -> void:
	if not _is_currently_desired(chunk_id, generation):
		return
	_failed_generation[chunk_id] = generation
	chunk_failed.emit(_payload(chunk_id, generation), reason)


func _is_currently_desired(chunk_id: String, generation: int) -> bool:
	return _manager.get_desired_chunk_ids().has(chunk_id) \
		and _manager.get_lifecycle_generation(chunk_id) == generation


func _now_msec() -> int:
	if _clock.is_valid():
		return int(_clock.call())
	return Time.get_ticks_msec()


func _release_unused_resources() -> void:
	if not _backend.has_method("release_unused"):
		return
	var pending_paths: Array[String] = []
	for request: Dictionary in _requests.values():
		pending_paths.append(request["scene_path"])
	_backend.call("release_unused", pending_paths)


func _payload(chunk_id: String, generation: int) -> Dictionary:
	return {"chunk_id": chunk_id, "lifecycle_generation": generation}


func _update_seam_barriers() -> void:
	for chunk_id: String in _manifest.get_chunk_ids():
		if not _instances.has(chunk_id):
			_clear_barriers(chunk_id)
			continue
		var record: Dictionary = _manifest.get_chunk(chunk_id)
		var bounds: AABB = record["bounds"]
		var neighbors: Array = record["adjacent"]
		var desired_edges: Dictionary = {}
		for raw_neighbor: Variant in neighbors:
			var neighbor_id: String = String(raw_neighbor)
			if _instances.has(neighbor_id):
				continue
			var neighbor_bounds: AABB = _manifest.get_chunk(neighbor_id)["bounds"]
			var shape_size: Vector3 = Vector3.ZERO
			var center: Vector3 = Vector3.ZERO
			if _touches_x(bounds, neighbor_bounds):
				shape_size = Vector3(BARRIER_THICKNESS, bounds.size.y, minf(bounds.size.z, neighbor_bounds.size.z))
				center = Vector3(_shared_x(bounds, neighbor_bounds), bounds.position.y + bounds.size.y * 0.5, maxf(bounds.position.z, neighbor_bounds.position.z) + shape_size.z * 0.5)
			elif _touches_z(bounds, neighbor_bounds):
				shape_size = Vector3(minf(bounds.size.x, neighbor_bounds.size.x), bounds.size.y, BARRIER_THICKNESS)
				center = Vector3(maxf(bounds.position.x, neighbor_bounds.position.x) + shape_size.x * 0.5, bounds.position.y + bounds.size.y * 0.5, _shared_z(bounds, neighbor_bounds))
			if shape_size == Vector3.ZERO:
				continue
			desired_edges[neighbor_id] = {"size": shape_size, "center": center}
		var existing: Dictionary = _barriers.get(chunk_id, {})
		for neighbor_id: String in existing:
			if not desired_edges.has(neighbor_id):
				var old_barrier: StaticBody3D = existing[neighbor_id] as StaticBody3D
				if is_instance_valid(old_barrier):
					old_barrier.queue_free()
				existing.erase(neighbor_id)
		for neighbor_id: String in desired_edges:
			if existing.has(neighbor_id):
				continue
			var barrier: StaticBody3D = _make_barrier(desired_edges[neighbor_id])
			_activation_root.add_child(barrier)
			existing[neighbor_id] = barrier
		_barriers[chunk_id] = existing


func _make_barrier(definition: Dictionary) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "UnavailableChunkBarrier"
	body.position = definition["center"]
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = definition["size"]
	collision.shape = shape
	body.add_child(collision)
	return body


func _clear_barriers(chunk_id: String) -> void:
	var existing: Dictionary = _barriers.get(chunk_id, {})
	for raw_barrier: Variant in existing.values():
		var barrier: StaticBody3D = raw_barrier as StaticBody3D
		if is_instance_valid(barrier):
			barrier.queue_free()
	_barriers.erase(chunk_id)


func _touches_x(first: AABB, second: AABB) -> bool:
	var x_touch: bool = absf(first.end.x - second.position.x) <= TOUCH_EPSILON or absf(second.end.x - first.position.x) <= TOUCH_EPSILON
	return x_touch and _overlap_positive(first.position.y, first.end.y, second.position.y, second.end.y) \
		and _overlap_positive(first.position.z, first.end.z, second.position.z, second.end.z)


func _touches_z(first: AABB, second: AABB) -> bool:
	var z_touch: bool = absf(first.end.z - second.position.z) <= TOUCH_EPSILON or absf(second.end.z - first.position.z) <= TOUCH_EPSILON
	return z_touch and _overlap_positive(first.position.y, first.end.y, second.position.y, second.end.y) \
		and _overlap_positive(first.position.x, first.end.x, second.position.x, second.end.x)


func _shared_x(first: AABB, second: AABB) -> float:
	return first.end.x if absf(first.end.x - second.position.x) <= TOUCH_EPSILON else second.end.x


func _shared_z(first: AABB, second: AABB) -> float:
	return first.end.z if absf(first.end.z - second.position.z) <= TOUCH_EPSILON else second.end.z


func _overlap_positive(first_min: float, first_max: float, second_min: float, second_max: float) -> bool:
	return minf(first_max, second_max) - maxf(first_min, second_min) > TOUCH_EPSILON


class _ResourceBackend extends RefCounted:
	var _requested_paths: Dictionary = {}

	func request(scene_path: String) -> bool:
		if _requested_paths.has(scene_path):
			var existing_status: int = ResourceLoader.load_threaded_get_status(scene_path)
			if existing_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or existing_status == ResourceLoader.THREAD_LOAD_LOADED:
				return true
			_requested_paths.erase(scene_path)
		var result: Error = ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
		if result == OK:
			_requested_paths[scene_path] = true
			return true
		if result == ERR_BUSY:
			var in_progress: bool = ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
			if in_progress:
				_requested_paths[scene_path] = true
			return in_progress
		return false

	func status(scene_path: String) -> int:
		var status_code: int = ResourceLoader.load_threaded_get_status(scene_path)
		if status_code == ResourceLoader.THREAD_LOAD_FAILED or status_code == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return -1
		return status_code

	func get_resource(scene_path: String) -> Resource:
		if ResourceLoader.load_threaded_get_status(scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
			return null
		var resource: Resource = ResourceLoader.load_threaded_get(scene_path)
		_requested_paths.erase(scene_path)
		return resource

	func release_unused(pending_paths: Array[String]) -> void:
		for scene_path: String in _requested_paths.keys():
			if pending_paths.has(scene_path):
				continue
			var status_code: int = ResourceLoader.load_threaded_get_status(scene_path)
			if status_code == ResourceLoader.THREAD_LOAD_LOADED:
				get_resource(scene_path)
			elif status_code == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status_code == ResourceLoader.THREAD_LOAD_FAILED:
				_requested_paths.erase(scene_path)
