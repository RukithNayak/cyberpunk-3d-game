extends RefCounted
class_name SaveStore
## Versioned, data-only persistence with validation before one consumer-owned live commit.

const FORMAT_ID: String = "cyberpunk-save"
const CURRENT_VERSION: int = 1
const MIN_SLOT: int = 0
const MAX_SLOT: int = 99
const MAX_FILE_BYTES: int = 16777216
const MAX_DEPTH: int = 16
const MAX_CONTAINER_ENTRIES: int = 1024
const MAX_TOTAL_VALUES: int = 10000
const MAX_STRING_BYTES: int = 16384
const MAX_KEY_BYTES: int = 256
const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

var _directory: String
var _snapshot_provider: Callable
var _candidate_validator: Callable
var _atomic_apply: Callable
var _io: Object
var _migrations: Object
var _uuid_regex: RegEx = RegEx.new()


func _init(directory: String = "user://saves", snapshot_provider: Callable = Callable(), candidate_validator: Callable = Callable(), atomic_apply: Callable = Callable(), filesystem: Object = null, migrations: Object = null) -> void:
	_directory = directory.trim_suffix("/")
	_snapshot_provider = snapshot_provider
	_candidate_validator = candidate_validator
	_atomic_apply = atomic_apply
	_io = filesystem if filesystem != null else _NativeFileOps.new()
	_migrations = migrations
	_uuid_regex.compile(UUID_PATTERN)


func save_to_disk(slot: int) -> Error:
	if not _is_valid_slot(slot) or not _has_methods(["write", "replace", "remove"]):
		return ERR_INVALID_PARAMETER
	if not _snapshot_provider.is_valid():
		return ERR_UNCONFIGURED
	var snapshot_variant: Variant = _snapshot_provider.call()
	if typeof(snapshot_variant) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var snapshot: Dictionary = snapshot_variant
	if not _validate_snapshot(snapshot):
		return ERR_INVALID_DATA
	var envelope: Dictionary = {
		"format": FORMAT_ID,
		"version": str(CURRENT_VERSION),
		"payload": _encode_value(snapshot)
	}
	var bytes: PackedByteArray = JSON.stringify(envelope).to_utf8_buffer()
	if bytes.size() > MAX_FILE_BYTES:
		return ERR_INVALID_DATA
	var final_path: String = _slot_path(slot)
	var temp_path: String = final_path + ".tmp"
	var io_error: Error = _io.call("write", temp_path, bytes)
	if io_error != OK:
		return io_error
	io_error = _io.call("replace", temp_path, final_path)
	if io_error != OK:
		_io.call("remove", temp_path)
		return io_error
	return OK


func load_from_disk(slot: int) -> Error:
	if not _is_valid_slot(slot) or not _has_methods(["read"]):
		return ERR_INVALID_PARAMETER
	if not _candidate_validator.is_valid() or not _atomic_apply.is_valid():
		return ERR_UNCONFIGURED
	var final_path: String = _slot_path(slot)
	var read_result: Dictionary = _io.call("read", final_path)
	var read_error: Error = read_result.get("error", ERR_FILE_CANT_READ)
	if read_error != OK:
		return read_error
	var bytes: PackedByteArray = read_result.get("data", PackedByteArray())
	if bytes.is_empty() or bytes.size() > MAX_FILE_BYTES:
		return ERR_INVALID_DATA
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(bytes.get_string_from_utf8())
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var envelope: Dictionary = json.data
	if envelope.get("format") != FORMAT_ID:
		return ERR_INVALID_DATA
	var version: Variant = envelope.get("version")
	if typeof(version) != TYPE_STRING or not _is_integer_text(version):
		return ERR_INVALID_DATA
	var version_number: int = version.to_int()
	if version_number > CURRENT_VERSION:
		return ERR_UNAVAILABLE
	if not envelope.has("payload"):
		return ERR_INVALID_DATA
	var decoded: Dictionary = _decode_value(envelope["payload"], 0, [MAX_TOTAL_VALUES])
	if not decoded.get("ok", false) or typeof(decoded.get("value")) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var candidate: Dictionary = decoded["value"]
	if version_number < CURRENT_VERSION:
		if _migrations == null or not _migrations.has_method("migrate_snapshot"):
			return ERR_FILE_UNRECOGNIZED
		var migration_result: Variant = _migrations.call("migrate_snapshot", version_number, candidate.duplicate(true))
		if typeof(migration_result) != TYPE_DICTIONARY or not migration_result.get("ok", false):
			if typeof(migration_result) != TYPE_DICTIONARY or typeof(migration_result.get("error")) != TYPE_INT or migration_result["error"] == OK:
				return ERR_FILE_UNRECOGNIZED
			return migration_result["error"]
		if migration_result.get("version") != CURRENT_VERSION or typeof(migration_result.get("snapshot")) != TYPE_DICTIONARY:
			return ERR_FILE_UNRECOGNIZED
		candidate = migration_result["snapshot"].duplicate(true)
	if not _validate_snapshot(candidate):
		return ERR_INVALID_DATA
	var validation_result: Variant = _candidate_validator.call(candidate.duplicate(true))
	if typeof(validation_result) != TYPE_BOOL or not validation_result:
		return ERR_INVALID_DATA
	var apply_result: Variant = _atomic_apply.call(candidate.duplicate(true))
	if typeof(apply_result) == TYPE_BOOL and not apply_result:
		return ERR_INVALID_DATA
	return OK


func _slot_path(slot: int) -> String:
	return "%s/slot_%02d.save" % [_directory, slot]


func _is_valid_slot(slot: int) -> bool:
	return slot >= MIN_SLOT and slot <= MAX_SLOT


func _has_methods(methods: Array[String]) -> bool:
	if _io == null:
		return false
	for method_name: String in methods:
		if not _io.has_method(method_name):
			return false
	return true


func _validate_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot.has("player") or typeof(snapshot["player"]) != TYPE_DICTIONARY:
		return false
	if not snapshot.has("entities") or typeof(snapshot["entities"]) != TYPE_ARRAY:
		return false
	if not snapshot.has("factions") or typeof(snapshot["factions"]) != TYPE_DICTIONARY:
		return false
	if not snapshot.has("domains") or typeof(snapshot["domains"]) != TYPE_DICTIONARY:
		return false
	var budget: Array = [MAX_TOTAL_VALUES]
	if not _validate_value(snapshot, 0, budget, MAX_DEPTH + 3):
		return false
	var seen: Dictionary = {}
	for entity_variant: Variant in snapshot["entities"]:
		if typeof(entity_variant) != TYPE_DICTIONARY:
			return false
		var entity: Dictionary = entity_variant
		if entity.size() != 2 or typeof(entity.get("uuid")) != TYPE_STRING or typeof(entity.get("state")) != TYPE_DICTIONARY:
			return false
		var uuid: String = entity["uuid"]
		if _uuid_regex.search(uuid) == null or seen.has(uuid):
			return false
		if not _validate_value(entity["state"], 0, [MAX_TOTAL_VALUES]):
			return false
		seen[uuid] = true
	for faction_variant: Variant in snapshot["factions"]:
		if typeof(faction_variant) != TYPE_STRING:
			return false
		var faction_id: String = faction_variant
		var standing: Variant = snapshot["factions"][faction_id]
		if faction_id.is_empty() or faction_id != faction_id.strip_edges() or typeof(standing) != TYPE_INT or standing < -100 or standing > 100:
			return false
	return true


func _validate_value(value: Variant, depth: int, budget: Array, max_depth: int = MAX_DEPTH) -> bool:
	if depth > max_depth or budget[0] <= 0:
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
			for item: Variant in value:
				if not _validate_value(item, depth + 1, budget, max_depth):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return false
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or (key as String).to_utf8_buffer().size() > MAX_KEY_BYTES:
					return false
				if not _validate_value(value[key], depth + 1, budget, max_depth):
					return false
			return true
		_:
			return false


func _encode_value(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_NIL:
			return {"t": "nil"}
		TYPE_BOOL:
			return {"t": "bool", "v": value}
		TYPE_INT:
			return {"t": "int", "v": str(value)}
		TYPE_FLOAT:
			var float_stream: StreamPeerBuffer = StreamPeerBuffer.new()
			float_stream.big_endian = false
			float_stream.put_double(value)
			return {"t": "float64le", "v": float_stream.data_array.hex_encode()}
		TYPE_STRING:
			return {"t": "string", "v": value}
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(_encode_value(item))
			return {"t": "array", "v": items}
		TYPE_DICTIONARY:
			var entries: Array = []
			for key: Variant in value:
				entries.append([key, _encode_value(value[key])])
			return {"t": "dict", "v": entries}
	return {"t": "invalid"}


func _decode_value(node: Variant, depth: int, budget: Array) -> Dictionary:
	if depth > MAX_DEPTH + 3 or budget[0] <= 0 or typeof(node) != TYPE_DICTIONARY or not node.has("t"):
		return {"ok": false}
	budget[0] -= 1
	var tag: Variant = node["t"]
	var value: Variant = node.get("v")
	match tag:
		"nil":
			return {"ok": node.size() == 1, "value": null}
		"bool":
			return {"ok": node.size() == 2 and typeof(value) == TYPE_BOOL, "value": value}
		"int":
			if node.size() != 2 or typeof(value) != TYPE_STRING or not _is_integer_text(value):
				return {"ok": false}
			return {"ok": true, "value": value.to_int()}
		"float64le":
			if node.size() != 2 or typeof(value) != TYPE_STRING or value.length() != 16:
				return {"ok": false}
			var float_bytes: PackedByteArray = value.hex_decode()
			if float_bytes.size() != 8:
				return {"ok": false}
			var float_stream: StreamPeerBuffer = StreamPeerBuffer.new()
			float_stream.big_endian = false
			float_stream.data_array = float_bytes
			var float_value: float = float_stream.get_double()
			if not is_finite(float_value):
				return {"ok": false}
			return {"ok": true, "value": float_value}
		"string":
			return {"ok": node.size() == 2 and typeof(value) == TYPE_STRING, "value": value}
		"array":
			if node.size() != 2 or typeof(value) != TYPE_ARRAY or value.size() > MAX_CONTAINER_ENTRIES:
				return {"ok": false}
			var decoded_array: Array = []
			for child: Variant in value:
				var child_result: Dictionary = _decode_value(child, depth + 1, budget)
				if not child_result.get("ok", false):
					return {"ok": false}
				decoded_array.append(child_result["value"])
			return {"ok": true, "value": decoded_array}
		"dict":
			if node.size() != 2 or typeof(value) != TYPE_ARRAY or value.size() > MAX_CONTAINER_ENTRIES:
				return {"ok": false}
			var decoded_dict: Dictionary = {}
			for entry_variant: Variant in value:
				if typeof(entry_variant) != TYPE_ARRAY or entry_variant.size() != 2 or typeof(entry_variant[0]) != TYPE_STRING or decoded_dict.has(entry_variant[0]):
					return {"ok": false}
				var entry_result: Dictionary = _decode_value(entry_variant[1], depth + 1, budget)
				if not entry_result.get("ok", false):
					return {"ok": false}
				decoded_dict[entry_variant[0]] = entry_result["value"]
			return {"ok": true, "value": decoded_dict}
	return {"ok": false}


func _is_integer_text(value: String) -> bool:
	if value.is_empty() or value == "-0":
		return false
	var start: int = 1 if value.begins_with("-") else 0
	if start == value.length():
		return false
	for index: int in range(start, value.length()):
		var code: int = value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	var parsed: int = value.to_int()
	return str(parsed) == value


class _NativeFileOps extends RefCounted:
	func read(path: String) -> Dictionary:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(absolute_path):
			return {"error": ERR_FILE_NOT_FOUND}
		var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
		if file == null:
			return {"error": FileAccess.get_open_error()}
		var data: PackedByteArray = file.get_buffer(MAX_FILE_BYTES + 1)
		file.close()
		return {"error": OK, "data": data}

	func write(path: String, data: PackedByteArray) -> Error:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var directory: String = absolute_path.get_base_dir()
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
			return directory_error
		var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_buffer(data)
		file.flush()
		var write_error: Error = file.get_error()
		file.close()
		return write_error

	func replace(from_path: String, to_path: String) -> Error:
		var from_absolute: String = ProjectSettings.globalize_path(from_path)
		var to_absolute: String = ProjectSettings.globalize_path(to_path)
		return DirAccess.rename_absolute(from_absolute, to_absolute)

	func remove(path: String) -> Error:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(absolute_path):
			return OK
		return DirAccess.remove_absolute(absolute_path)
