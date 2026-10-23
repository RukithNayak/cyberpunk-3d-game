extends RefCounted
class_name EntityRegistry
## Persistent entity data keyed by canonical UUIDs, independent of scene Nodes.

const MAX_DEPTH: int = 16
const MAX_CONTAINER_ENTRIES: int = 1024
const MAX_TOTAL_VALUES: int = 10000
const MAX_STRING_BYTES: int = 16384
const MAX_KEY_BYTES: int = 256
const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

var _entities: Dictionary = {}
var _uuid_regex: RegEx = RegEx.new()


func _init() -> void:
	_uuid_regex.compile(UUID_PATTERN)


func register_entity(uuid: String, initial_state: Dictionary) -> void:
	if not _is_valid_uuid(uuid):
		push_warning("EntityRegistry rejected non-canonical UUID: %s" % uuid)
		return
	if _entities.has(uuid):
		push_warning("EntityRegistry ignored duplicate entity UUID: %s" % uuid)
		return
	if not _is_valid_data(initial_state):
		push_warning("EntityRegistry rejected non-serializable or oversized state for UUID: %s" % uuid)
		return
	_entities[uuid] = initial_state.duplicate(true)


func commit_state_delta(uuid: String, delta: Dictionary) -> void:
	try_commit_state_delta(uuid, delta)


func try_commit_state_delta(uuid: String, delta: Dictionary) -> bool:
	if not _is_valid_uuid(uuid):
		push_warning("EntityRegistry rejected delta for non-canonical UUID: %s" % uuid)
		return false
	if not _entities.has(uuid):
		push_warning("EntityRegistry ignored delta for unknown UUID: %s" % uuid)
		return false
	if not _is_valid_data(delta):
		push_warning("EntityRegistry rejected non-serializable or oversized delta for UUID: %s" % uuid)
		return false
	var merged: Dictionary = _deep_merge(_entities[uuid], delta)
	if not _is_valid_data(merged):
		push_warning("EntityRegistry rejected delta whose merged state exceeds limits for UUID: %s" % uuid)
		return false
	_entities[uuid] = merged
	return true


func get_entity_state(uuid: String) -> Dictionary:
	if not _is_valid_uuid(uuid) or not _entities.has(uuid):
		return {}
	return (_entities[uuid] as Dictionary).duplicate(true)


func has_entity(uuid: String) -> bool:
	return _is_valid_uuid(uuid) and _entities.has(uuid)


func snapshot_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var uuids: Array = _entities.keys()
	uuids.sort()
	for uuid_variant: Variant in uuids:
		var uuid: String = uuid_variant
		result.append({"uuid": uuid, "state": (_entities[uuid] as Dictionary).duplicate(true)})
	return result


func validate_snapshot_records(records: Variant) -> bool:
	return _records_to_dictionary(records).get("ok", false)


func prepare_snapshot_replacement(records: Variant) -> Dictionary:
	var result: Dictionary = _records_to_dictionary(records)
	if not result.get("ok", false):
		return {"ok": false}
	return {"ok": true, "records": result["records"]}


func commit_prepared_snapshot(prepared: Dictionary) -> void:
	# This method only accepts plans produced by prepare_snapshot_replacement.
	# Its caller prepares every owner first and invokes this infallible commit phase.
	_entities = prepared["records"]


func _records_to_dictionary(records: Variant) -> Dictionary:
	if typeof(records) != TYPE_ARRAY or records.size() > MAX_CONTAINER_ENTRIES:
		return {"ok": false}
	var replacement: Dictionary = {}
	for record_variant: Variant in records:
		if typeof(record_variant) != TYPE_DICTIONARY:
			return {"ok": false}
		var record: Dictionary = record_variant
		if record.size() != 2 or typeof(record.get("uuid")) != TYPE_STRING or typeof(record.get("state")) != TYPE_DICTIONARY:
			return {"ok": false}
		var uuid: String = record["uuid"]
		var state: Dictionary = record["state"]
		if not _is_valid_uuid(uuid) or replacement.has(uuid) or not _is_valid_data(state):
			return {"ok": false}
		replacement[uuid] = state.duplicate(true)
	return {"ok": true, "records": replacement}


func _is_valid_uuid(uuid: String) -> bool:
	return _uuid_regex.search(uuid) != null


func _is_valid_data(value: Variant) -> bool:
	var budget: Array = [MAX_TOTAL_VALUES]
	return _validate_value(value, 0, budget)


func _validate_value(value: Variant, depth: int, budget: Array) -> bool:
	if depth > MAX_DEPTH or budget[0] <= 0:
		return false
	budget[0] -= 1
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING:
			return value.to_utf8_buffer().size() <= MAX_STRING_BYTES
		TYPE_ARRAY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return false
			for child: Variant in value:
				if not _validate_value(child, depth + 1, budget):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return false
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or (key as String).to_utf8_buffer().size() > MAX_KEY_BYTES:
					return false
				if not _validate_value(value[key], depth + 1, budget):
					return false
			return true
		_:
			# Objects (including Nodes), packed arrays and other engine values are not JSON-like data.
			return false


func _deep_merge(current: Dictionary, delta: Dictionary) -> Dictionary:
	var result: Dictionary = current.duplicate(true)
	for key: Variant in delta:
		var new_value: Variant = delta[key]
		if typeof(new_value) == TYPE_DICTIONARY and typeof(result.get(key)) == TYPE_DICTIONARY:
			result[key] = _deep_merge(result[key], new_value)
		else:
			result[key] = _deep_copy(new_value)
	return result


func _deep_copy(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value
