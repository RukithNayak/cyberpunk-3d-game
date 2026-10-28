extends RefCounted
class_name NpcSimulationRecord
## Unload coordinator. Registry data is durable; actor references here are transient.

signal unload_capture_committed(chunk_id: String, lifecycle_generation: int, actor_count: int)
signal unload_capture_rejected(chunk_id: String, lifecycle_generation: int)

const RECORD_SCHEMA: int = 1
const RECORD_KEY: String = "npc_simulation"

var _registry: EntityRegistry
var _manager: WorldManager
var _factions: FactionState
var _navigation_ready_provider: Callable
var _configured: bool = false
var _active_actors: Dictionary = {}


func configure(registry: EntityRegistry, manager: WorldManager, factions: FactionState, navigation_ready_provider: Callable = Callable()) -> bool:
	if _configured or registry == null or manager == null or factions == null:
		return false
	if navigation_ready_provider.is_valid() and navigation_ready_provider.get_argument_count() != 1:
		return false
	_registry = registry
	_manager = manager
	_factions = factions
	_navigation_ready_provider = navigation_ready_provider
	if not _manager.chunk_pre_unload.is_connected(_on_chunk_pre_unload):
		_manager.chunk_pre_unload.connect(_on_chunk_pre_unload)
	_configured = true
	return true


func register_actor(uuid: String, chunk_id: String, generation: int, actor: TacticalAgent) -> bool:
	if not _configured or not _registry.has_entity(uuid) or not _is_current_chunk(chunk_id, generation):
		return false
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return false
	if _active_actors.has(uuid):
		var current: Dictionary = _active_actors[uuid]
		return current.get("actor") == actor and current.get("chunk_id") == chunk_id and int(current.get("generation", -1)) == generation
	if not _is_navigation_ready(actor):
		actor.process_ai = false
		return false
	var state: Dictionary = _registry.get_entity_state(uuid)
	var saved_variant: Variant = state.get(RECORD_KEY)
	if saved_variant != null:
		actor.process_ai = false
		if not _validate_record(saved_variant, chunk_id):
			return false
		if not _restore_actor(actor, saved_variant as Dictionary):
			return false
	elif not actor.is_configured():
		return false
	else:
		actor.process_ai = true
	_active_actors[uuid] = {"chunk_id": chunk_id, "generation": generation, "actor": actor}
	return true


func get_active_actor(uuid: String) -> TacticalAgent:
	var entry: Dictionary = _active_actors.get(uuid, {})
	var actor: TacticalAgent = entry.get("actor") as TacticalAgent
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return null
	return actor


func get_active_actor_count() -> int:
	return _active_actors.size()


func get_actor_chunk_id(uuid: String) -> String:
	var entry: Dictionary = _active_actors.get(uuid, {})
	return String(entry.get("chunk_id", ""))


func transfer_actor(uuid: String, source_chunk_id: String, source_generation: int, destination_chunk_id: String, destination_generation: int, actor: TacticalAgent) -> bool:
	if not _configured or uuid.is_empty() or source_chunk_id == destination_chunk_id:
		return false
	if not _active_actors.has(uuid) or not _is_current_chunk(source_chunk_id, source_generation) or not _is_current_chunk(destination_chunk_id, destination_generation):
		return false
	var entry: Dictionary = _active_actors[uuid]
	if entry.get("chunk_id") != source_chunk_id or int(entry.get("generation", -1)) != source_generation or entry.get("actor") != actor:
		return false
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree() or not _is_navigation_ready(actor):
		return false
	_active_actors[uuid] = {"chunk_id": destination_chunk_id, "generation": destination_generation, "actor": actor}
	return true


func get_record(uuid: String) -> Dictionary:
	if not _configured or not _registry.has_entity(uuid):
		return {}
	var state: Dictionary = _registry.get_entity_state(uuid)
	var record: Variant = state.get(RECORD_KEY)
	return record.duplicate(true) if typeof(record) == TYPE_DICTIONARY else {}


func _on_chunk_pre_unload(payload: Dictionary) -> void:
	if not _configured or typeof(payload.get("chunk_id")) != TYPE_STRING or typeof(payload.get("lifecycle_generation")) != TYPE_INT:
		return
	var chunk_id: String = payload["chunk_id"]
	var generation: int = payload["lifecycle_generation"]
	if _manager.get_lifecycle_generation(chunk_id) != generation or _manager.get_desired_chunk_ids().has(chunk_id):
		return
	var owners: Array[Dictionary] = []
	for uuid: String in _active_actors:
		var entry: Dictionary = _active_actors[uuid]
		if entry.get("chunk_id") != chunk_id:
			continue
		var actor: TacticalAgent = entry.get("actor") as TacticalAgent
		if int(entry.get("generation", -1)) >= generation or actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
			unload_capture_rejected.emit(chunk_id, generation)
			return
		var actor_data: Dictionary = actor.capture_simulation_data()
		var record: Dictionary = _make_record(chunk_id, actor_data)
		if not _validate_record(record, chunk_id):
			unload_capture_rejected.emit(chunk_id, generation)
			return
		owners.append({"uuid": uuid, "actor": actor, "record": record})
	if owners.is_empty():
		return
	var rows: Array[Dictionary] = _registry.snapshot_records()
	var row_index: Dictionary = {}
	for index: int in range(rows.size()):
		row_index[rows[index]["uuid"]] = index
	for owner: Dictionary in owners:
		var uuid: String = owner["uuid"]
		if not row_index.has(uuid):
			unload_capture_rejected.emit(chunk_id, generation)
			return
		var row: Dictionary = rows[int(row_index[uuid])]
		var state: Dictionary = (row["state"] as Dictionary).duplicate(true)
		state[RECORD_KEY] = (owner["record"] as Dictionary).duplicate(true)
		row["state"] = state
		rows[int(row_index[uuid])] = row
	var prepared: Dictionary = _registry.prepare_snapshot_replacement(rows)
	if not prepared.get("ok", false):
		unload_capture_rejected.emit(chunk_id, generation)
		return
	_registry.commit_prepared_snapshot(prepared)
	# Relinquish active UUID ownership before actor callbacks can re-enter this service.
	for owner: Dictionary in owners:
		_active_actors.erase(owner["uuid"])
	for owner: Dictionary in owners:
		var actor: TacticalAgent = owner["actor"]
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			actor.prepare_for_unload()
	unload_capture_committed.emit(chunk_id, generation, owners.size())


func _make_record(chunk_id: String, actor_data: Dictionary) -> Dictionary:
	var position: Variant = actor_data.get("position")
	var rotation: Variant = actor_data.get("rotation")
	if not position is Vector3 or not rotation is Quaternion:
		return {}
	var world_position: Vector3 = position
	var world_rotation: Quaternion = rotation.normalized()
	return {
		"schema": RECORD_SCHEMA,
		"chunk_id": chunk_id,
		"faction_id": actor_data.get("faction_id", ""),
		"health": {
			"current": actor_data.get("current_health", -1),
			"maximum": actor_data.get("maximum_health", -1),
		},
		"pose": {
			"position": [world_position.x, world_position.y, world_position.z],
			"rotation": [world_rotation.x, world_rotation.y, world_rotation.z, world_rotation.w],
		},
		"flags": {"dead": actor_data.get("dead", false)},
	}


func _restore_actor(actor: TacticalAgent, record: Dictionary) -> bool:
	var health: Dictionary = record["health"]
	var pose: Dictionary = record["pose"]
	var position_values: Array = pose["position"]
	var rotation_values: Array = pose["rotation"]
	var position: Vector3 = Vector3(float(position_values[0]), float(position_values[1]), float(position_values[2]))
	var rotation: Quaternion = Quaternion(float(rotation_values[0]), float(rotation_values[1]), float(rotation_values[2]), float(rotation_values[3])).normalized()
	var flags: Dictionary = record["flags"]
	return actor.restore_simulation_state(_factions, record["faction_id"], int(health["current"]), int(health["maximum"]), position, rotation, bool(flags["dead"]))


func _validate_record(value: Variant, expected_chunk_id: String) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var record: Dictionary = value
	if record.size() != 6 or typeof(record.get("schema")) != TYPE_INT or int(record["schema"]) != RECORD_SCHEMA or record.get("chunk_id") != expected_chunk_id:
		return false
	var faction: Variant = record.get("faction_id")
	if typeof(faction) != TYPE_STRING or (faction as String).is_empty() or (faction as String) != (faction as String).strip_edges():
		return false
	var health: Variant = record.get("health")
	var pose: Variant = record.get("pose")
	var flags: Variant = record.get("flags")
	if typeof(health) != TYPE_DICTIONARY or typeof(pose) != TYPE_DICTIONARY or typeof(flags) != TYPE_DICTIONARY:
		return false
	if (health as Dictionary).size() != 2 or not health.has("current") or not health.has("maximum") \
		or typeof(health["current"]) != TYPE_INT or typeof(health["maximum"]) != TYPE_INT:
		return false
	var current_health: int = health["current"]
	var maximum_health: int = health["maximum"]
	if maximum_health <= 0 or maximum_health > 10000 or current_health < 0 or current_health > maximum_health:
		return false
	if (flags as Dictionary).size() != 1 or not flags.has("dead") or typeof(flags["dead"]) != TYPE_BOOL:
		return false
	if bool(flags["dead"]) != (current_health == 0):
		return false
	if (pose as Dictionary).size() != 2 or typeof(pose.get("position")) != TYPE_ARRAY or typeof(pose.get("rotation")) != TYPE_ARRAY:
		return false
	var position: Array = pose["position"]
	var rotation: Array = pose["rotation"]
	if position.size() != 3 or rotation.size() != 4:
		return false
	var rotation_length_squared: float = 0.0
	for component: Variant in position:
		if not _is_finite_number(component):
			return false
	for component: Variant in rotation:
		if not _is_finite_number(component):
			return false
		rotation_length_squared += float(component) * float(component)
	return is_finite(rotation_length_squared) and absf(rotation_length_squared - 1.0) <= 0.01


func _is_navigation_ready(actor: TacticalAgent) -> bool:
	if _navigation_ready_provider.is_valid():
		var supplied: Variant = _navigation_ready_provider.call(actor)
		return typeof(supplied) == TYPE_BOOL and supplied
	var driver: Node = actor.get_node_or_null("NavigationDriver")
	return driver != null and bool(driver.get("navigation_ready"))


func _is_current_chunk(chunk_id: String, generation: int) -> bool:
	return _manager.get_desired_chunk_ids().has(chunk_id) \
		and _manager.get_load_state(chunk_id) == WorldManager.LoadState.ACTIVE \
		and _manager.get_lifecycle_generation(chunk_id) == generation


func _is_finite_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value))
