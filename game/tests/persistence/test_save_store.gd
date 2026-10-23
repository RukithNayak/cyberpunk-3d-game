extends RefCounted

const SAVE_STORE_PATH: String = "res://persistence/save_store.gd"
const VALID_UUID: String = "123e4567-e89b-42d3-a456-426614174000"
const BIG_INT: int = 9007199254740993

var _live: Dictionary = {}
var _allow_candidate: bool = true


func run(check: Callable) -> void:
	var script: Script = load(SAVE_STORE_PATH) as Script
	check.call(script != null, "save store script is available")
	if script == null:
		return
	var io: TestFileOps = TestFileOps.new()
	var store: Object = script.new("user://core03_save_store_tests", Callable(self, "_capture"), Callable(self, "_validate"), Callable(self, "_apply"), io)
	check.call(store.has_method("save_to_disk") and store.has_method("load_from_disk"), "save and load entry points are available")
	if not store.has_method("save_to_disk") or not store.has_method("load_from_disk"):
		return
	var original: Dictionary = _fixture()
	_live = original.duplicate(true)
	check.call(store.call("save_to_disk", 1) == OK, "valid snapshot saves")
	_live = {"player": {"health": 1}, "entities": [], "factions": {}, "domains": {}}
	var load_result: Error = store.call("load_from_disk", 1)
	check.call(load_result == OK and _live == original, "round trip preserves nested, null, int64 and float types")
	check.call(typeof(_live.player.big) == TYPE_INT and _live.player.big == BIG_INT, "large integer retains integer type and precision")
	check.call(_live.player.int_max == 9223372036854775807 and _live.player.int_min == -9223372036854775807 - 1, "signed int64 boundaries round trip")
	check.call(typeof(_live.player.ratio) == TYPE_FLOAT and is_equal_approx(_live.player.ratio, 1.25), "float retains float type")
	check.call(_live.player.tiny == 1e-30 and _live.player.precision == 1.2345678901234567, "small and high-precision floats round trip")
	var deep_state: Dictionary = {"leaf": true}
	for depth: int in range(15):
		deep_state = {"nested": deep_state}
	_live = {"player": {}, "entities": [{"uuid": VALID_UUID, "state": deep_state}], "factions": {}, "domains": {}}
	check.call(store.call("save_to_disk", 2) == OK and store.call("load_from_disk", 2) == OK and _live.entities[0].state == deep_state, "maximum registry entity-state depth round trips")
	_live = original.duplicate(true)
	var save_path: String = "user://core03_save_store_tests/slot_01.save"
	var good_bytes: PackedByteArray = io.files[save_path]

	io.files.erase(save_path)
	check.call(store.call("load_from_disk", 1) != OK and _live == original, "missing save fails without live mutation")
	io.files[save_path] = "{truncated".to_utf8_buffer()
	check.call(store.call("load_from_disk", 1) != OK and _live == original, "truncated save fails without live mutation")
	io.files[save_path] = good_bytes
	check.call(store.call("load_from_disk", -1) != OK and store.call("save_to_disk", -1) != OK, "invalid slot is rejected")
	io.files[save_path] = _future_envelope()
	check.call(store.call("load_from_disk", 1) != OK and _live == original, "unsupported future version fails without live mutation")
	io.files[save_path] = _duplicate_uuid_envelope(store, original)
	check.call(store.call("load_from_disk", 1) != OK and _live == original, "duplicate entity UUID is rejected before live swap")
	io.files[save_path] = good_bytes
	check.call(store.call("load_from_disk", 1) == OK and _live == original, "valid candidate without duplicate UUID still loads")
	var bad_faction_bytes: PackedByteArray = ('{"format":"cyberpunk-save","version":"1","payload":{"t":"dict","v":[["player",{"t":"dict","v":[]}],["entities",{"t":"array","v":[]}],["factions",{"t":"dict","v":[["corpos",{"t":"int","v":"101"}]]}],["domains",{"t":"dict","v":[]}]]}}').to_utf8_buffer()
	io.files[save_path] = bad_faction_bytes
	check.call(store.call("load_from_disk", 1) != OK and _live == original, "out-of-range faction value is rejected before live swap")
	io.files[save_path] = good_bytes

	_live.player.health = 77
	io.fail_write = true
	check.call(store.call("save_to_disk", 1) != OK and io.files[save_path] == good_bytes, "failed write preserves prior valid disk save")
	io.fail_write = false
	io.fail_replace = true
	check.call(store.call("save_to_disk", 1) != OK and io.files[save_path] == good_bytes, "interrupted atomic replacement preserves prior valid disk save")
	io.fail_replace = false
	_live = {"preserved": true}
	check.call(store.call("load_from_disk", 1) == OK and _live == original and io.files[save_path] == good_bytes, "load after interrupted replacement preserves prior save")
	check.call(store.call("save_to_disk", 1) == OK, "subsequent replacement succeeds")
	var disk_after_save: PackedByteArray = io.files[save_path]
	_live = original.duplicate(true)
	_allow_candidate = false
	check.call(store.call("load_from_disk", 1) != OK and _live == original, "consumer rejection leaves live state unchanged")
	_allow_candidate = true
	check.call(io.files[save_path] == disk_after_save, "failed load leaves disk save unchanged")
	_test_native_round_trip(check)
	for path: Variant in io.files.keys():
		io.files.erase(path)


func _test_native_round_trip(check: Callable) -> void:
	var directory: String = "user://core03_save_store_native_%d" % OS.get_process_id()
	var native_store_script: Script = load(SAVE_STORE_PATH) as Script
	var native_store: Object = native_store_script.new(directory, Callable(self, "_capture"), Callable(self, "_validate"), Callable(self, "_apply"))
	var save_path: String = "%s/slot_02.save" % directory
	_live = _fixture()
	var save_error: Error = native_store.call("save_to_disk", 2)
	_live = {"changed": true}
	var load_error: Error = native_store.call("load_from_disk", 2)
	var replacement_snapshot: Dictionary = _fixture()
	replacement_snapshot["player"]["health"] = 51
	_live = replacement_snapshot.duplicate(true)
	var replacement_error: Error = native_store.call("save_to_disk", 2)
	_live = {"changed": true}
	var replacement_load_error: Error = native_store.call("load_from_disk", 2)
	check.call(save_error == OK and load_error == OK and replacement_error == OK and replacement_load_error == OK and _live == replacement_snapshot, "native filesystem save, replacement and load round trip succeeds")
	for path: String in [save_path, save_path + ".tmp"]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _fixture() -> Dictionary:
	return {
		"player": {"health": 89, "big": BIG_INT, "int_max": 9223372036854775807, "int_min": -9223372036854775807 - 1, "ratio": 1.25, "tiny": 1e-30, "precision": 1.2345678901234567, "nullable": null, "nested": [true, {"text": "cyberpunk"}]},
		"entities": [{"uuid": VALID_UUID, "state": {"alive": true, "count": BIG_INT}}],
		"factions": {"corpos": -17},
		"domains": {"inventory": {"slots": [null, 4.5, "item"]}}
	}


func _capture() -> Dictionary:
	return _live.duplicate(true)


func _validate(candidate: Dictionary) -> bool:
	return _allow_candidate and candidate.has("player")


func _apply(candidate: Dictionary) -> void:
	_live = candidate.duplicate(true)


func _future_envelope() -> PackedByteArray:
	return '{"format":"cyberpunk-save","version":"999","payload":{}}'.to_utf8_buffer()


func _duplicate_uuid_envelope(store: Object, source: Dictionary) -> PackedByteArray:
	var duplicate_candidate: Dictionary = source.duplicate(true)
	duplicate_candidate["entities"].append({"uuid": VALID_UUID, "state": {"another": true}})
	var payload: Dictionary = store.call("_encode_value", duplicate_candidate)
	return JSON.stringify({"format": "cyberpunk-save", "version": "1", "payload": payload}).to_utf8_buffer()


class TestFileOps extends RefCounted:
	var files: Dictionary = {}
	var fail_write: bool = false
	var fail_replace: bool = false

	func read(path: String) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND}
		return {"error": OK, "data": files[path]}

	func write(path: String, data: PackedByteArray) -> Error:
		if fail_write:
			return ERR_CANT_CREATE
		files[path] = data.duplicate()
		return OK

	func replace(from_path: String, to_path: String) -> Error:
		if fail_replace:
			return ERR_CANT_CREATE
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = files[from_path]
		files.erase(from_path)
		return OK

	func remove(path: String) -> Error:
		files.erase(path)
		return OK
