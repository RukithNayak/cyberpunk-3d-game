extends Node
class_name NavigationHandoff
## Coordinates synchronized chunk navigation and stable NPC ownership at seams.

signal navigation_readiness_changed(chunk_id: String, lifecycle_generation: int, ready: bool)
signal actor_transferred(uuid: String, source_chunk_id: String, destination_chunk_id: String)

var _manager: WorldManager
var _manifest: ChunkManifest
var _loader: ChunkLoader
var _simulation: NpcSimulationRecord
var _persistent_actor_root: Node3D
var _configured: bool = false
var _chunk_roots: Dictionary = {}
var _tracked_actors: Dictionary = {}
var _transfer_counts: Dictionary = {}
var _published_readiness: Dictionary = {}


func configure(manager: WorldManager, manifest: ChunkManifest, loader: ChunkLoader, simulation: NpcSimulationRecord, persistent_actor_root: Node3D) -> bool:
	if _configured or manager == null or manifest == null or loader == null or simulation == null or persistent_actor_root == null:
		return false
	if manifest.get_chunk_ids().is_empty() or not persistent_actor_root.is_inside_tree():
		return false
	_manager = manager
	_manifest = manifest
	_loader = loader
	_simulation = simulation
	_persistent_actor_root = persistent_actor_root
	if not _loader.chunk_activated.is_connected(_on_chunk_activated):
		_loader.chunk_activated.connect(_on_chunk_activated)
	if not _loader.chunk_unloaded.is_connected(_on_chunk_unloaded):
		_loader.chunk_unloaded.connect(_on_chunk_unloaded)
	_configured = true
	set_process(true)
	return true


func attach_actor(uuid: String, chunk_id: String, generation: int, actor: TacticalAgent) -> bool:
	if not _configured or uuid.is_empty() or _tracked_actors.has(uuid) or not _is_current_chunk(chunk_id, generation):
		return false
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree():
		return false
	var existing_actor: TacticalAgent = _simulation.call("get_active_actor", uuid) as TacticalAgent
	if existing_actor != null and existing_actor != actor:
		return false
	var chunk: Dictionary = _chunk_roots.get(chunk_id, {})
	var chunk_root: Node3D = chunk.get("instance") as Node3D
	if int(chunk.get("generation", -1)) != generation or chunk_root == null or not chunk_root.is_ancestor_of(actor):
		return false
	var driver: Node = actor.get_node_or_null("NavigationDriver")
	var navigation_agent: NavigationAgent3D = actor.get_node_or_null("NavigationDriver/NavigationAgent3D") as NavigationAgent3D
	if driver == null or navigation_agent == null or not driver.has_method("set_readiness_provider"):
		return false
	var world: World3D = actor.get_world_3d()
	if world == null:
		return false
	navigation_agent.set_navigation_map(world.navigation_map)
	if not bool(driver.call("set_readiness_provider", Callable(self, "_is_actor_navigation_ready").bind(actor))):
		return false
	actor.process_ai = false
	driver.set("process_navigation", false)
	_tracked_actors[uuid] = {
		"actor": actor,
		"chunk_id": chunk_id,
		"generation": generation,
		"registered": false,
	}
	return true


func is_navigation_ready_for_actor(actor: Node) -> bool:
	return _is_actor_navigation_ready(actor)


func get_actor_chunk_id(uuid: String) -> String:
	return String((_tracked_actors.get(uuid, {}) as Dictionary).get("chunk_id", ""))


func get_transfer_count(uuid: String) -> int:
	return int(_transfer_counts.get(uuid, 0))


func get_navigation_debug_state() -> Dictionary:
	var state: Dictionary = {}
	if not _configured:
		return state
	for chunk_id: String in _manifest.get_chunk_ids():
		var entry: Dictionary = _chunk_roots.get(chunk_id, {})
		var region_iterations: Array[int] = []
		for region_variant: Variant in entry.get("regions", []):
			var region: NavigationRegion3D = region_variant as NavigationRegion3D
			region_iterations.append(NavigationServer3D.region_get_iteration_id(region.get_rid()) if region != null and is_instance_valid(region) else -1)
		state[chunk_id] = {"generation": entry.get("generation", -1), "load_state": _manager.get_load_state(chunk_id), "region_iterations": region_iterations}
	return state


func _process(_delta: float) -> void:
	if not _configured:
		return
	_refresh_navigation_regions()
	_publish_readiness_changes()
	var uuids: Array[String] = []
	for uuid_variant: Variant in _tracked_actors:
		uuids.append(String(uuid_variant))
	uuids.sort()
	for uuid: String in uuids:
		if not _tracked_actors.has(uuid):
			continue
		var entry: Dictionary = _tracked_actors[uuid]
		var actor: TacticalAgent = entry.get("actor") as TacticalAgent
		if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
			_tracked_actors.erase(uuid)
			continue
		var ready: bool = _is_actor_navigation_ready(actor)
		var driver: Node = actor.get_node_or_null("NavigationDriver")
		actor.process_ai = ready and bool(entry.get("registered", false))
		if driver != null:
			driver.set("process_navigation", ready)
		if not ready or driver == null or not bool(driver.get("navigation_ready")):
			continue
		if not bool(entry.get("registered", false)):
			if not bool(_simulation.call("register_actor", uuid, entry["chunk_id"], int(entry["generation"]), actor)):
				continue
			entry["registered"] = true
			_tracked_actors[uuid] = entry
			actor.process_ai = true
		_try_transfer_actor(uuid, entry, actor)


func _refresh_navigation_regions() -> void:
	for chunk_id_variant: Variant in _chunk_roots:
		var chunk_id: String = String(chunk_id_variant)
		var entry: Dictionary = _chunk_roots[chunk_id]
		var instance: Node3D = entry.get("instance") as Node3D
		var generation: int = int(entry.get("generation", -1))
		if instance == null or not is_instance_valid(instance) or instance.is_queued_for_deletion() or not _is_current_chunk(chunk_id, generation):
			continue
		var regions: Array[NavigationRegion3D] = []
		for node: Node in instance.find_children("*", "NavigationRegion3D", true, false):
			if node is NavigationRegion3D:
				regions.append(node as NavigationRegion3D)
		regions.sort_custom(func(left: NavigationRegion3D, right: NavigationRegion3D) -> bool: return str(left.get_path()) < str(right.get_path()))
		entry["regions"] = regions
		_chunk_roots[chunk_id] = entry


func _publish_readiness_changes() -> void:
	for chunk_id: String in _manifest.get_chunk_ids():
		var entry: Dictionary = _chunk_roots.get(chunk_id, {})
		var generation: int = int(entry.get("generation", _manager.get_lifecycle_generation(chunk_id)))
		var ready: bool = _is_chunk_navigation_ready(chunk_id, generation) and _are_desired_navigation_maps_ready()
		var key: String = "%s:%d" % [chunk_id, generation]
		if bool(_published_readiness.get(key, false)) == ready and _published_readiness.has(key):
			continue
		_published_readiness[key] = ready
		navigation_readiness_changed.emit(chunk_id, generation, ready)


func _is_actor_navigation_ready(actor: Node) -> bool:
	if not _configured or actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	var uuid: String = ""
	for uuid_variant: Variant in _tracked_actors:
		if (_tracked_actors[uuid_variant] as Dictionary).get("actor") == actor:
			uuid = String(uuid_variant)
			break
	if uuid.is_empty():
		return false
	var entry: Dictionary = _tracked_actors[uuid]
	var chunk_id: String = String(entry.get("chunk_id", ""))
	var generation: int = int(entry.get("generation", -1))
	return _is_chunk_navigation_ready(chunk_id, generation) and _are_desired_navigation_maps_ready()


func _is_chunk_navigation_ready(chunk_id: String, generation: int) -> bool:
	if not _is_current_chunk(chunk_id, generation):
		return false
	var chunk: Dictionary = _chunk_roots.get(chunk_id, {})
	var instance: Node3D = chunk.get("instance") as Node3D
	if int(chunk.get("generation", -1)) != generation or instance == null or not is_instance_valid(instance) or not instance.is_inside_tree():
		return false
	var regions: Array = chunk.get("regions", [])
	if regions.is_empty():
		return false
	var world: World3D = instance.get_world_3d()
	if world == null:
		return false
	var map: RID = world.navigation_map
	if not map.is_valid() or not NavigationServer3D.map_is_active(map) or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return false
	for region_variant: Variant in regions:
		var region: NavigationRegion3D = region_variant as NavigationRegion3D
		if region == null or not is_instance_valid(region) or region.is_queued_for_deletion() or region.get_navigation_map() != map:
			return false
		if NavigationServer3D.region_get_iteration_id(region.get_rid()) <= 0:
			return false
	return true


func _are_desired_navigation_maps_ready() -> bool:
	var desired_ids: Array[String] = _manager.get_desired_chunk_ids()
	if desired_ids.is_empty():
		return false
	for chunk_id: String in desired_ids:
		var generation: int = _manager.get_lifecycle_generation(chunk_id)
		if not _is_chunk_navigation_ready(chunk_id, generation):
			return false
	return true


func _try_transfer_actor(uuid: String, entry: Dictionary, actor: TacticalAgent) -> void:
	var destination_id: String = _owner_at_position(actor.global_position)
	var source_id: String = String(entry.get("chunk_id", ""))
	if destination_id.is_empty() or destination_id == source_id:
		return
	var destination_generation: int = _manager.get_lifecycle_generation(destination_id)
	if not _is_chunk_navigation_ready(destination_id, destination_generation) or not _is_actor_navigation_ready(actor):
		return
	if not bool(_simulation.call("transfer_actor", uuid, source_id, int(entry["generation"]), destination_id, destination_generation, actor)):
		return
	var previous_parent: Node = actor.get_parent()
	if previous_parent != _persistent_actor_root:
		actor.reparent(_persistent_actor_root, true)
	entry["chunk_id"] = destination_id
	entry["generation"] = destination_generation
	_tracked_actors[uuid] = entry
	_transfer_counts[uuid] = int(_transfer_counts.get(uuid, 0)) + 1
	actor_transferred.emit(uuid, source_id, destination_id)


func _owner_at_position(world_position: Vector3) -> String:
	for chunk_id: String in _manifest.get_chunk_ids():
		var record: Dictionary = _manifest.get_chunk(chunk_id)
		var bounds: AABB = record["bounds"]
		if bounds.has_point(world_position):
			return chunk_id
	return ""


func _is_current_chunk(chunk_id: String, generation: int) -> bool:
	return _manager != null and _manifest.get_chunk_ids().has(chunk_id) \
		and _manager.get_desired_chunk_ids().has(chunk_id) \
		and _manager.get_load_state(chunk_id) == WorldManager.LoadState.ACTIVE \
		and _manager.get_lifecycle_generation(chunk_id) == generation


func _on_chunk_activated(payload: Dictionary, instance: Node3D) -> void:
	var chunk_id: String = String(payload.get("chunk_id", ""))
	var generation: int = int(payload.get("lifecycle_generation", -1))
	if not _configured or not _is_current_chunk(chunk_id, generation) or instance == null or not is_instance_valid(instance):
		return
	_chunk_roots[chunk_id] = {"generation": generation, "instance": instance, "regions": []}


func _on_chunk_unloaded(payload: Dictionary) -> void:
	if not _configured:
		return
	var chunk_id: String = String(payload.get("chunk_id", ""))
	var generation: int = int(payload.get("lifecycle_generation", -1))
	var loaded: Dictionary = _chunk_roots.get(chunk_id, {})
	if not loaded.is_empty() and int(loaded.get("generation", -1)) <= generation:
		_chunk_roots.erase(chunk_id)
		for readiness_key: String in _published_readiness:
			if readiness_key.begins_with(chunk_id + ":"):
				_published_readiness.erase(readiness_key)
	var retired_ids: Array[String] = []
	for uuid_variant: Variant in _tracked_actors:
		var uuid: String = String(uuid_variant)
		var entry: Dictionary = _tracked_actors[uuid]
		if entry.get("chunk_id") != chunk_id or int(entry.get("generation", -1)) > generation:
			continue
		var actor: TacticalAgent = entry.get("actor") as TacticalAgent
		if actor != null and is_instance_valid(actor) and actor.get_parent() == _persistent_actor_root and not actor.is_queued_for_deletion():
			actor.queue_free()
		retired_ids.append(uuid)
	for uuid: String in retired_ids:
		_tracked_actors.erase(uuid)
