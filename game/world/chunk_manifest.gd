extends RefCounted
class_name ChunkManifest

## Immutable after successful configuration: authored chunk identity and spatial metadata.

var _chunks: Dictionary = {}
var _configured: bool = false


func configure(records: Array) -> bool:
	if _configured:
		return false
	var candidate: Dictionary = {}
	var entity_ids: Dictionary = {}
	for raw_record: Variant in records:
		if not raw_record is Dictionary:
			return false
		var record: Dictionary = raw_record
		var chunk_id: Variant = record.get("id")
		var bounds: Variant = record.get("bounds")
		var scene_path: Variant = record.get("scene_path")
		var adjacent: Variant = record.get("adjacent")
		if not chunk_id is String or not _is_valid_id(chunk_id):
			return false
		if candidate.has(chunk_id) or not bounds is AABB or not _is_valid_bounds(bounds):
			return false
		if not scene_path is String or not ResourceLoader.exists(scene_path, "PackedScene"):
			return false
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		if packed_scene == null or not packed_scene.can_instantiate():
			return false
		if not ClassDB.is_parent_class(packed_scene.get_state().get_node_type(0), "Node3D"):
			return false
		if not adjacent is Array:
			return false
		var neighbors: Array[String] = []
		for neighbor: Variant in adjacent:
			if not neighbor is String or not _is_valid_id(neighbor) or neighbors.has(neighbor):
				return false
			neighbors.append(neighbor)
		var entity_result: Dictionary = _validated_entities(record.get("entities", []), entity_ids)
		if not entity_result["ok"]:
			return false
		candidate[chunk_id] = {
			"id": chunk_id,
			"bounds": bounds,
			"scene_path": scene_path,
			"adjacent": neighbors,
			"entities": entity_result["entities"]
		}
	if candidate.is_empty():
		return false
	for chunk_id: String in candidate:
		for neighbor_id: String in candidate[chunk_id]["adjacent"]:
			if not candidate.has(neighbor_id):
				return false
			if not candidate[neighbor_id]["adjacent"].has(chunk_id):
				return false
	_chunks = candidate
	_configured = true
	return true


func get_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id: String in _chunks:
		ids.append(chunk_id)
	ids.sort()
	return ids


func _validated_entities(raw_entities: Variant, entity_ids: Dictionary) -> Dictionary:
	if typeof(raw_entities) != TYPE_ARRAY or raw_entities.size() > EntityRegistry.MAX_CONTAINER_ENTRIES:
		return {"ok": false}
	var entities: Array[Dictionary] = []
	var paths: Dictionary = {}
	var validator: EntityRegistry = EntityRegistry.new()
	for raw: Variant in raw_entities:
		if typeof(raw) != TYPE_DICTIONARY or raw.size() != 3:
			return {"ok": false}
		var uuid: Variant = raw.get("uuid")
		var path: Variant = raw.get("node_path")
		var state: Variant = raw.get("initial_state")
		if typeof(uuid) != TYPE_STRING or typeof(path) != TYPE_STRING or typeof(state) != TYPE_DICTIONARY:
			return {"ok": false}
		if entity_ids.has(uuid) or paths.has(path) or path.is_empty() or path.contains(":"):
			return {"ok": false}
		for part: String in path.split("/", true):
			if part.is_empty() or part == "." or part == "..":
				return {"ok": false}
		if not validator.validate_snapshot_records([{"uuid": uuid, "state": state}]):
			return {"ok": false}
		entity_ids[uuid] = true
		paths[path] = true
		entities.append(raw.duplicate(true))
	return {"ok": true, "entities": entities}


func get_chunk(chunk_id: String) -> Dictionary:
	if not _chunks.has(chunk_id):
		return {}
	return _chunks[chunk_id].duplicate(true)


func _is_valid_id(chunk_id: String) -> bool:
	if chunk_id.is_empty() or not chunk_id[0].to_lower() in "abcdefghijklmnopqrstuvwxyz":
		return false
	for character: String in chunk_id:
		if not character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true


func _is_valid_bounds(bounds: AABB) -> bool:
	var position: Vector3 = bounds.position
	var size: Vector3 = bounds.size
	return size.x > 0.0 and size.y > 0.0 and size.z > 0.0 \
		and is_finite(position.x) and is_finite(position.y) and is_finite(position.z) \
		and is_finite(size.x) and is_finite(size.y) and is_finite(size.z)
