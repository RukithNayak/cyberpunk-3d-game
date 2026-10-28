extends RefCounted
class_name EntityHydrator
## Projects registry-owned entity records onto the currently loaded chunk scenes.

signal interactions_invalidated(payload: Dictionary)

var _registry: EntityRegistry
var _manifest: ChunkManifest
var _manager: WorldManager
var _configured: bool = false
var _bindings: Dictionary = {}
var _chunks: Dictionary = {}
var _prepared: Dictionary = {}

func configure(registry: EntityRegistry, manifest: ChunkManifest, manager: WorldManager) -> bool:
	if _configured or registry == null or manifest == null or manager == null or manifest.get_chunk_ids().is_empty():
		return false
	_registry = registry
	_manifest = manifest
	_manager = manager
	_manager.chunk_pre_unload.connect(_on_chunk_pre_unload)
	_configured = true
	return true


func prepare_chunk(chunk_id: String, generation: int, instance: Node3D) -> bool:
	if not _is_current(chunk_id, generation) or not is_instance_valid(instance) or instance.is_queued_for_deletion():
		return false
	if _chunks.has(chunk_id) and int(_chunks[chunk_id]["generation"]) == generation:
		return false
	if _prepared.has(chunk_id) and int(_prepared[chunk_id]["generation"]) == generation:
		return false
	var chunk: Dictionary = _manifest.get_chunk(chunk_id)
	var descriptors: Variant = chunk.get("entities", [])
	if typeof(descriptors) != TYPE_ARRAY:
		return false
	var staged: Array[Dictionary] = []
	var pending_defaults: Dictionary = {}
	for raw_descriptor: Variant in descriptors:
		if typeof(raw_descriptor) != TYPE_DICTIONARY:
			return false
		var descriptor: Dictionary = raw_descriptor
		var uuid: Variant = descriptor.get("uuid")
		var node_path: Variant = descriptor.get("node_path")
		var initial_state: Variant = descriptor.get("initial_state")
		if typeof(uuid) != TYPE_STRING or typeof(node_path) != TYPE_STRING or typeof(initial_state) != TYPE_DICTIONARY:
			return false
		if _has_other_owner(uuid, chunk_id) or _prepared_has_other_owner(uuid, chunk_id):
			return false
		var state: Dictionary = _registry.get_entity_state(uuid)
		if not _registry.has_entity(uuid):
			state = initial_state.duplicate(true)
			pending_defaults[uuid] = state
		var tombstoned: bool = bool(state.get("collected", false)) or bool(state.get("destroyed", false))
		var target: Node3D = _resolve_target(instance, node_path) if not tombstoned else null
		if not tombstoned and target == null:
			return false
		if not tombstoned and (not target.has_method("apply_persistent_state") or not target.has_method("set_interaction_enabled")):
			return false
		staged.append({"uuid": uuid, "node_path": node_path, "state": state, "node": target, "tombstoned": tombstoned})
	if not _is_current(chunk_id, generation) or not is_instance_valid(instance):
		return false
	if not pending_defaults.is_empty() and not _commit_missing_defaults(pending_defaults):
		return false
	# Set all interactions off before any user projection callback can observe the scene.
	for binding: Dictionary in staged:
		if bool(binding["tombstoned"]):
			continue
		var node: Node3D = binding["node"]
		if not _is_current(chunk_id, generation) or not is_instance_valid(node):
			_revoke_staged(chunk_id, generation, staged)
			return false
		node.call("set_interaction_enabled", false)
		if not _is_current(chunk_id, generation) or not is_instance_valid(node) or instance.is_queued_for_deletion():
			_revoke_staged(chunk_id, generation, staged)
			return false
		node.call("apply_persistent_state", (binding["state"] as Dictionary).duplicate(true))
		if not _is_current(chunk_id, generation) or not is_instance_valid(node) or instance.is_queued_for_deletion():
			_revoke_staged(chunk_id, generation, staged)
			return false
	for binding: Dictionary in staged:
		if bool(binding["tombstoned"]):
			var tombstone_target: Node3D = _resolve_target(instance, binding["node_path"])
			if tombstone_target != null and tombstone_target.get_parent() != null:
				tombstone_target.get_parent().remove_child(tombstone_target)
				tombstone_target.queue_free()
	_chunks[chunk_id] = {"generation": generation, "instance": instance, "bindings": staged, "active": false}
	_prepared[chunk_id] = {"generation": generation, "instance": instance}
	return _is_current(chunk_id, generation) and is_instance_valid(instance) and not instance.is_queued_for_deletion()


func activate_chunk(chunk_id: String, generation: int, instance: Node3D) -> bool:
	if not _is_current(chunk_id, generation) or not is_instance_valid(instance) or instance.is_queued_for_deletion():
		return false
	if not _prepared.has(chunk_id):
		return false
	var prepared: Dictionary = _prepared[chunk_id]
	if int(prepared["generation"]) != generation or prepared["instance"] != instance:
		return false
	var chunk: Dictionary = _chunks.get(chunk_id, {})
	var staged: Array = chunk.get("bindings", [])
	for binding_variant: Variant in staged:
		var binding: Dictionary = binding_variant
		if bool(binding["tombstoned"]):
			continue
		var node: Node3D = binding["node"]
		if not _is_current(chunk_id, generation) or not is_instance_valid(node) or not is_instance_valid(instance):
			_retire_internal(chunk_id, generation, instance)
			return false
		# Publish this exact generation's ownership before the callback. If enabling
		# synchronously invalidates the chunk, retirement can now disable this node.
		_bindings[binding["uuid"]] = {"node": node, "chunk_id": chunk_id, "generation": generation}
		node.call("set_interaction_enabled", true)
		if not _is_current(chunk_id, generation) or not is_instance_valid(node) or instance.is_queued_for_deletion():
			_retire_internal(chunk_id, generation, instance)
			return false
	chunk["active"] = true
	_chunks[chunk_id] = chunk
	_prepared.erase(chunk_id)
	return true


func retire_chunk(chunk_id: String, generation: int, instance: Node3D) -> void:
	_retire_internal(chunk_id, generation, instance)


func commit_entity_delta(uuid: String, delta: Dictionary, generation: int) -> bool:
	if not _configured or not _bindings.has(uuid):
		return false
	var binding: Dictionary = _bindings[uuid]
	var chunk_id: String = binding["chunk_id"]
	if generation != int(binding["generation"]) or not _is_current(chunk_id, generation):
		return false
	var node: Node3D = binding["node"]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if not _registry.try_commit_state_delta(uuid, delta):
		return false
	var state: Dictionary = _registry.get_entity_state(uuid)
	if bool(state.get("collected", false)) or bool(state.get("destroyed", false)):
		var chunk: Dictionary = _chunks.get(chunk_id, {})
		# Revoke only the exact old binding before invoking user code. A callback may
		# synchronously re-enter this chunk and install a newer instance/generation.
		if _bindings.has(uuid) and _binding_matches(_bindings[uuid], chunk_id, generation, node):
			_bindings.erase(uuid)
		if _chunk_matches(chunk, generation, binding.get("instance", chunk.get("instance")) as Node3D):
			var remaining: Array = []
			for raw_binding: Variant in chunk.get("bindings", []):
				if raw_binding["uuid"] != uuid:
					remaining.append(raw_binding)
			chunk["bindings"] = remaining
			_chunks[chunk_id] = chunk
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.call("set_interaction_enabled", false)
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				if node.get_parent() != null:
					node.get_parent().remove_child(node)
				node.queue_free()
		return true
	node.call("apply_persistent_state", state.duplicate(true))
	return true


func get_runtime_entity(_uuid: String) -> Node3D:
	if not _bindings.has(_uuid):
		return null
	var binding: Dictionary = _bindings[_uuid]
	var node: Node3D = binding["node"]
	if not _is_current(binding["chunk_id"], int(binding["generation"])) or not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node


func get_bound_entity_count() -> int:
	return _bindings.size()


func _commit_missing_defaults(missing: Dictionary) -> bool:
	var records: Array[Dictionary] = _registry.snapshot_records()
	var present: Dictionary = {}
	for record: Dictionary in records:
		present[record["uuid"]] = true
	for uuid: String in missing:
		if not present.has(uuid):
			records.append({"uuid": uuid, "state": (missing[uuid] as Dictionary).duplicate(true)})
	var plan: Dictionary = _registry.prepare_snapshot_replacement(records)
	if not plan.get("ok", false):
		return false
	_registry.commit_prepared_snapshot(plan)
	return true


func _resolve_target(instance: Node3D, path: String) -> Node3D:
	if path.is_empty() or path.begins_with("/"):
		return null
	var node: Node = instance.get_node_or_null(NodePath(path))
	if node == null or not node is Node3D:
		return null
	return node as Node3D


func _has_other_owner(uuid: String, chunk_id: String) -> bool:
	if _bindings.has(uuid) and _bindings[uuid]["chunk_id"] != chunk_id:
		return true
	return false


func _prepared_has_other_owner(uuid: String, chunk_id: String) -> bool:
	for other_chunk: String in _chunks:
		if other_chunk == chunk_id:
			continue
		for binding: Dictionary in _chunks[other_chunk].get("bindings", []):
			if binding["uuid"] == uuid:
				return true
	return false


func _revoke_staged(chunk_id: String, generation: int, staged: Array[Dictionary]) -> void:
	var chunk: Dictionary = _chunks.get(chunk_id, {})
	var instance: Node3D = chunk.get("instance") as Node3D
	if _chunk_matches(chunk, generation, instance):
		_chunks.erase(chunk_id)
	var prepared: Dictionary = _prepared.get(chunk_id, {})
	if int(prepared.get("generation", -1)) == generation and prepared.get("instance") == instance:
		_prepared.erase(chunk_id)
	var to_disable: Array[Dictionary] = []
	for binding: Dictionary in staged:
		if bool(binding["tombstoned"]):
			continue
		var node: Node3D = binding["node"]
		if _bindings.has(binding["uuid"]) and _binding_matches(_bindings[binding["uuid"]], chunk_id, generation, node):
			_bindings.erase(binding["uuid"])
		if is_instance_valid(node):
			to_disable.append({"uuid": binding["uuid"], "node": node})
	for owner: Dictionary in to_disable:
		var node: Node3D = owner["node"]
		if _has_same_node_binding(owner["uuid"], node):
			continue
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.call("set_interaction_enabled", false)


func _on_chunk_pre_unload(payload: Dictionary) -> void:
	var chunk_id: String = String(payload.get("chunk_id", ""))
	var generation: int = int(payload.get("lifecycle_generation", -1))
	var chunk: Dictionary = _chunks.get(chunk_id, {})
	_retire_internal(chunk_id, generation, chunk.get("instance") as Node3D)


func _retire_internal(chunk_id: String, generation: int, instance: Node3D) -> void:
	if not _chunks.has(chunk_id):
		_prepared.erase(chunk_id)
		return
	var chunk: Dictionary = _chunks[chunk_id]
	var bound_generation: int = int(chunk["generation"])
	if generation < bound_generation:
		return
	if instance != null and is_instance_valid(instance) and chunk["instance"] != instance:
		return
	var uuids: Array[String] = []
	var to_disable: Array[Dictionary] = []
	for binding_variant: Variant in chunk.get("bindings", []):
		var binding: Dictionary = binding_variant
		var uuid: String = binding["uuid"]
		if _bindings.has(uuid) and _binding_matches(_bindings[uuid], chunk_id, bound_generation, binding.get("node") as Node3D):
			var node: Node3D = _bindings[uuid]["node"]
			_bindings.erase(uuid)
			uuids.append(uuid)
			if is_instance_valid(node):
				to_disable.append({"uuid": uuid, "node": node})
	# Revoke ownership before any projection callback can re-enter and bind a new
	# chunk instance. All cleanup below is local to the captured old instance.
	if _chunk_matches(_chunks.get(chunk_id, {}), bound_generation, chunk["instance"] as Node3D):
		_chunks.erase(chunk_id)
	var prepared: Dictionary = _prepared.get(chunk_id, {})
	if int(prepared.get("generation", -1)) == bound_generation and prepared.get("instance") == chunk["instance"]:
		_prepared.erase(chunk_id)
	for owner: Dictionary in to_disable:
		var node: Node3D = owner["node"]
		if _has_same_node_binding(owner["uuid"], node):
			continue
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.call("set_interaction_enabled", false)
	if not uuids.is_empty():
		interactions_invalidated.emit({"chunk_id": chunk_id, "lifecycle_generation": generation, "entity_uuids": uuids})


func _binding_matches(binding: Dictionary, chunk_id: String, generation: int, node: Node3D) -> bool:
	return binding.get("chunk_id") == chunk_id and int(binding.get("generation", -1)) == generation \
		and binding.get("node") == node


func _chunk_matches(chunk: Dictionary, generation: int, instance: Node3D) -> bool:
	return not chunk.is_empty() and int(chunk.get("generation", -1)) == generation \
		and chunk.get("instance") == instance


func _has_same_node_binding(uuid: String, node: Node3D) -> bool:
	return _bindings.has(uuid) and _bindings[uuid].get("node") == node


func _is_current(chunk_id: String, generation: int) -> bool:
	return _configured and _manager.get_desired_chunk_ids().has(chunk_id) \
		and _manager.get_lifecycle_generation(chunk_id) == generation
