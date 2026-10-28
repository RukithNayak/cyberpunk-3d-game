extends RefCounted

const SAVE_STORE_PATH: String = "res://persistence/save_store.gd"
const MIGRATIONS_PATH: String = "res://persistence/save_migrations.gd"
const ADAPTERS_PATH: String = "res://persistence/snapshot_adapters.gd"
const REGISTRY_PATH: String = "res://persistence/entity_registry.gd"
const FACTION_PATH: String = "res://persistence/faction_state.gd"
const ENTITY_ID: String = "123e4567-e89b-42d3-a456-426614174000"

var _player: Dictionary = {"health": 100}
var _domains: Dictionary = {"inventory": {"slots": ["pistol"]}}
var _root_extensions: Dictionary = {"third_party_root_record": {"preserved": true}}
var _allow_prepare: bool = true


func run(check: Callable) -> void:
	var migrations_script: Script = load(MIGRATIONS_PATH) as Script
	check.call(migrations_script != null, "ordered save migration service is available")
	if migrations_script == null:
		return
	var migrations: Object = migrations_script.new()
	var old_snapshot: Dictionary = _v0_fixture()
	var first: Dictionary = migrations.call("migrate_snapshot", 0, old_snapshot)
	var repeated: Dictionary = migrations.call("migrate_snapshot", 0, old_snapshot)
	var second: Dictionary = migrations.call("migrate_snapshot", first.get("version", -1), first.get("snapshot", {}))
	check.call(first.get("ok", false) and repeated.get("ok", false) and second.get("ok", false) and first.get("version") == 1 and first.get("snapshot") == repeated.get("snapshot") and first.get("snapshot") == second.get("snapshot"), "previous schema migration is deterministic and idempotent at the current version")
	check.call(first.get("snapshot", {}).get("entities", [])[0].get("uuid") == ENTITY_ID and first.get("snapshot", {}).get("domains", {}).get("plugin_record") == {"opaque": [4, "kept"]}, "migration preserves stable IDs and unknown recoverable domain records")
	var missing_step: Object = MissingStepMigrations.new()
	check.call(not missing_step.call("migrate_snapshot", 0, old_snapshot).get("ok", false), "missing migration step is rejected")
	check.call(not migrations.call("migrate_snapshot", 2, {}).get("ok", false), "unsupported future save version is rejected")
	_test_unsafe_migration_preserves_bytes(check, migrations_script)
	_test_rejected_migration_cannot_report_success(check)
	_test_registry_and_faction_adapters(check)
	_test_store_migrates_before_atomic_apply(check, migrations)


func _test_unsafe_migration_preserves_bytes(check: Callable, migrations_script: Script) -> void:
	var io: TestFileOps = TestFileOps.new()
	var path: String = "user://core04_migration_tests/slot_00.save"
	var bytes: PackedByteArray = _encoded_envelope(0, _v0_fixture())
	io.files[path] = bytes.duplicate()
	var live: Dictionary = {"sentinel": true}
	var failing_migrations: FailingMigration = FailingMigration.new()
	var store: Object = _store(io, Callable(self, "_capture_live").bind(live), Callable(self, "_accept"), Callable(self, "_ignore_apply"), failing_migrations)
	var load_error: Error = store.call("load_from_disk", 0)
	check.call(load_error != OK and io.files[path] == bytes and live == {"sentinel": true}, "unsafe migration rejects without overwriting source bytes or live state")


func _test_rejected_migration_cannot_report_success(check: Callable) -> void:
	var io: TestFileOps = TestFileOps.new()
	var path: String = "user://core04_migration_tests/slot_00.save"
	var bytes: PackedByteArray = _encoded_envelope(0, _v0_fixture())
	io.files[path] = bytes.duplicate()
	var live: Dictionary = {"sentinel": true}
	var store: Object = _store(io, Callable(self, "_capture_live").bind(live), Callable(self, "_accept"), Callable(self, "_apply_to_live").bind(live), ContradictoryMigration.new())
	var load_error: Error = store.call("load_from_disk", 0)
	check.call(load_error != OK and live == {"sentinel": true} and io.files[path] == bytes, "rejected migration with an OK error returns failure without changing live state or source bytes")


func _test_registry_and_faction_adapters(check: Callable) -> void:
	var adapters_script: Script = load(ADAPTERS_PATH) as Script
	var registry_script: Script = load(REGISTRY_PATH) as Script
	var faction_script: Script = load(FACTION_PATH) as Script
	check.call(adapters_script != null and registry_script != null and faction_script != null, "snapshot adapter and authoritative owners are available without scenes")
	if adapters_script == null or registry_script == null or faction_script == null:
		return
	var registry: Object = registry_script.new()
	registry.call("register_entity", ENTITY_ID, {"alive": true, "count": 9007199254740993, "position": {"x": 4.5}})
	var faction_ids: Array[String] = ["corpos"]
	var factions: Object = faction_script.new(faction_ids)
	factions.call("set_faction_standing", "corpos", 37)
	var adapters: Object = adapters_script.new(registry, factions, Callable(self, "_capture_player"), Callable(self, "_prepare_player"), Callable(self, "_commit_player"), Callable(self, "_capture_domains"), Callable(self, "_prepare_domains"), Callable(self, "_commit_domains"), Callable(self, "_capture_extensions"), Callable(self, "_prepare_extensions"), Callable(self, "_commit_extensions"))
	var snapshot: Dictionary = adapters.call("capture_snapshot")
	check.call(snapshot.get("player") == _player and snapshot.get("entities", []).size() == 1 and snapshot.entities[0].state.count == 9007199254740993 and typeof(snapshot.entities[0].state.position.x) == TYPE_FLOAT and snapshot.get("factions", {}).get("corpos") == 37 and snapshot.get("domains", {}).get("inventory") == _domains.inventory and snapshot.get("third_party_root_record") == _root_extensions.third_party_root_record, "snapshot adapters preserve owned and extension data with numeric types and no runtime scenes")
	snapshot.entities[0].state.alive = false
	snapshot.factions.corpos = -99
	check.call(registry.call("get_entity_state", ENTITY_ID).alive and factions.call("get_faction_standing", "corpos") == 37 and _domains.inventory.slots == ["pistol"], "mutating captured snapshot copies cannot mutate live owners")
	snapshot.entities[0].state.alive = true
	snapshot.factions.corpos = 37
	var extensions_before_collision: Dictionary = _root_extensions.duplicate(true)
	_root_extensions = {"player": {"collision": true}}
	check.call(adapters.call("capture_snapshot").is_empty(), "extension capture rejects collisions with adapter-owned root keys")
	_root_extensions = extensions_before_collision
	var unconfigured_adapter: Object = adapters_script.new(registry, factions, Callable(self, "_capture_player"), Callable(self, "_prepare_player"), Callable(self, "_commit_player"), Callable(self, "_capture_domains"), Callable(self, "_prepare_domains"), Callable(self, "_commit_domains"))
	check.call(not unconfigured_adapter.call("validate_snapshot", snapshot) and not unconfigured_adapter.call("apply_snapshot", snapshot), "unknown root records reject before mutation when no extension owner is configured")
	var candidate: Dictionary = snapshot.duplicate(true)
	candidate["player"]["health"] = 12
	candidate["entities"][0]["state"]["alive"] = false
	candidate["factions"]["corpos"] = -20
	candidate["domains"]["inventory"]["slots"] = []
	check.call(adapters.call("validate_snapshot", candidate), "adapter validates all candidate owners before replacement")
	var invalid_candidate: Dictionary = candidate.duplicate(true)
	var unexpected_node: Node = Node.new()
	invalid_candidate["player"]["unexpected_node"] = unexpected_node
	check.call(not adapters.call("validate_snapshot", invalid_candidate), "adapter rejects engine Objects from player and domain state")
	unexpected_node.free()
	invalid_candidate = candidate.duplicate(true)
	invalid_candidate["entities"].append(invalid_candidate["entities"][0].duplicate(true))
	check.call(not adapters.call("validate_snapshot", invalid_candidate), "adapter rejects duplicate stable entity IDs")
	check.call(adapters.call("apply_snapshot", candidate) and _player == candidate.player and registry.call("get_entity_state", ENTITY_ID) == candidate.entities[0].state and factions.call("get_faction_standing", "corpos") == -20 and _domains == candidate.domains, "prepared adapter replacement commits all owners through their existing instances")
	_allow_prepare = false
	var rejected: bool = adapters.call("apply_snapshot", snapshot)
	check.call(not rejected and _player == candidate.player and registry.call("get_entity_state", ENTITY_ID) == candidate.entities[0].state and factions.call("get_faction_standing", "corpos") == -20 and _domains == candidate.domains, "participant prepare failure leaves every live owner unchanged")
	_allow_prepare = true


func _test_store_migrates_before_atomic_apply(check: Callable, migrations: Object) -> void:
	var io: TestFileOps = TestFileOps.new()
	var source: Dictionary = _v0_fixture()
	var path: String = "user://core04_migration_tests/slot_01.save"
	var original_bytes: PackedByteArray = _encoded_envelope(0, source)
	io.files[path] = original_bytes.duplicate()
	_player = {"health": 1}
	_domains = {"inventory": {"slots": []}}
	var registry_script: Script = load(REGISTRY_PATH) as Script
	var faction_script: Script = load(FACTION_PATH) as Script
	var registry: Object = registry_script.new()
	registry.call("register_entity", ENTITY_ID, {"alive": false})
	var faction_ids: Array[String] = ["corpos"]
	var factions: Object = faction_script.new(faction_ids)
	_root_extensions = {"third_party_root_record": {"live": "before"}}
	var adapters: Object = (load(ADAPTERS_PATH) as Script).new(registry, factions, Callable(self, "_capture_player"), Callable(self, "_prepare_player"), Callable(self, "_commit_player"), Callable(self, "_capture_domains"), Callable(self, "_prepare_domains"), Callable(self, "_commit_domains"), Callable(self, "_capture_extensions"), Callable(self, "_prepare_extensions"), Callable(self, "_commit_extensions"))
	var store: Object = _store(io, Callable(adapters, "capture_snapshot"), Callable(adapters, "validate_snapshot"), Callable(adapters, "apply_snapshot"), migrations)
	_allow_prepare = false
	var rejected_error: Error = store.call("load_from_disk", 1)
	check.call(rejected_error != OK and _player == {"health": 1} and registry.call("get_entity_state", ENTITY_ID) == {"alive": false} and factions.call("get_faction_standing", "corpos") == 0 and _domains == {"inventory": {"slots": []}} and io.files[path] == original_bytes, "failed participant preparation rejects migrated load before any owner commit")
	_allow_prepare = true
	var load_error: Error = store.call("load_from_disk", 1)
	check.call(load_error == OK and _player == source.player and registry.call("get_entity_state", ENTITY_ID) == source.entities[0].state and factions.call("get_faction_standing", "corpos") == 7 and _domains == source.domain_records, "SaveStore migrates an older file before validated owner preparation and atomic apply")
	var recaptured: Dictionary = adapters.call("capture_snapshot")
	check.call(recaptured.get("third_party_root_record") == source.third_party_root_record and recaptured.get("domains", {}).get("plugin_record") == source.domain_records.plugin_record, "successful migrated load retains unknown root and domain records on recapture")
	check.call(io.files[path] == original_bytes, "successful old-save load leaves original source bytes intact")
	var save_error: Error = store.call("save_to_disk", 1)
	var saved_snapshot: Dictionary = _decode_saved_snapshot(io.files[path])
	check.call(save_error == OK and saved_snapshot.get("third_party_root_record") == source.third_party_root_record and saved_snapshot.get("domains", {}).get("plugin_record") == source.domain_records.plugin_record, "explicit save after migration retains unknown root and domain records")


func _store(io: TestFileOps, capture: Callable, validate: Callable, apply: Callable, migrations: Object) -> Object:
	var store_script: Script = load(SAVE_STORE_PATH) as Script
	return store_script.new("user://core04_migration_tests", capture, validate, apply, io, migrations)


func _encoded_envelope(version: int, snapshot: Dictionary) -> PackedByteArray:
	var store_script: Script = load(SAVE_STORE_PATH) as Script
	var codec: Object = store_script.new()
	var encoded: Dictionary = codec.call("_encode_value", snapshot)
	return JSON.stringify({"format": "cyberpunk-save", "version": str(version), "payload": encoded}).to_utf8_buffer()


func _decode_saved_snapshot(bytes: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var codec: Object = (load(SAVE_STORE_PATH) as Script).new()
	var decoded: Dictionary = codec.call("_decode_value", parsed.get("payload"), 0, [10000])
	return decoded.get("value", {}) if decoded.get("ok", false) and typeof(decoded.get("value")) == TYPE_DICTIONARY else {}


func _v0_fixture() -> Dictionary:
	return {
		"player": {"health": 88},
		"entities": [{"uuid": ENTITY_ID, "state": {"alive": true, "unknown_flag": "retain"}}],
		"factions": {"corpos": 7},
		"domain_records": {"inventory": {"slots": ["smg"]}, "plugin_record": {"opaque": [4, "kept"]}},
		"third_party_root_record": {"retain": true}
	}


func _capture_player() -> Dictionary:
	return _player.duplicate(true)


func _prepare_player(candidate: Dictionary) -> Dictionary:
	return {"ok": _allow_prepare and candidate.has("health"), "prepared": candidate.duplicate(true)}


func _commit_player(prepared: Dictionary) -> void:
	_player = prepared.duplicate(true)


func _capture_domains() -> Dictionary:
	return _domains.duplicate(true)


func _prepare_domains(candidate: Dictionary) -> Dictionary:
	return {"ok": _allow_prepare and candidate.has("inventory"), "prepared": candidate.duplicate(true)}


func _commit_domains(prepared: Dictionary) -> void:
	_domains = prepared.duplicate(true)


func _capture_extensions() -> Dictionary:
	return _root_extensions.duplicate(true)


func _prepare_extensions(candidate: Dictionary) -> Dictionary:
	return {"ok": _allow_prepare, "prepared": candidate.duplicate(true)}


func _commit_extensions(prepared: Dictionary) -> void:
	_root_extensions = prepared.duplicate(true)


func _capture_live(live: Dictionary) -> Dictionary:
	return live.duplicate(true)


func _accept(_candidate: Dictionary) -> bool:
	return true


func _ignore_apply(_candidate: Dictionary) -> void:
	pass


func _apply_to_live(candidate: Dictionary, live: Dictionary) -> void:
	live.clear()
	for key: Variant in candidate:
		live[key] = candidate[key].duplicate(true) if typeof(candidate[key]) == TYPE_DICTIONARY else candidate[key]


class FailingMigration extends RefCounted:
	func migrate_snapshot(_version: int, _snapshot: Dictionary) -> Dictionary:
		return {"ok": false}


class ContradictoryMigration extends RefCounted:
	func migrate_snapshot(_version: int, _snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "error": OK}


class MissingStepMigrations extends "res://persistence/save_migrations.gd":
	func _migration_for(_source_version: int) -> Callable:
		return Callable()


class TestFileOps extends RefCounted:
	var files: Dictionary = {}

	func read(path: String) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND}
		return {"error": OK, "data": files[path]}

	func write(path: String, data: PackedByteArray) -> Error:
		files[path] = data.duplicate()
		return OK

	func replace(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = files[from_path]
		files.erase(from_path)
		return OK

	func remove(path: String) -> Error:
		files.erase(path)
		return OK
