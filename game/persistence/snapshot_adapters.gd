extends RefCounted
class_name SnapshotAdapters
## Data-only bridge between existing owners and SaveStore callbacks.

const MAX_DEPTH: int = 16
const MAX_CONTAINER_ENTRIES: int = 1024
const MAX_TOTAL_VALUES: int = 10000
const MAX_STRING_BYTES: int = 16384
const MAX_KEY_BYTES: int = 256
const OWNED_ROOT_KEYS: Array[String] = ["player", "entities", "factions", "domains"]

var _registry: Object
var _factions: Object
var _capture_player: Callable
var _prepare_player: Callable
var _commit_player: Callable
var _capture_domains: Callable
var _prepare_domains: Callable
var _commit_domains: Callable
var _capture_extensions: Callable
var _prepare_extensions: Callable
var _commit_extensions: Callable


func _init(registry: Object, factions: Object, capture_player: Callable, prepare_player: Callable, commit_player: Callable, capture_domains: Callable, prepare_domains: Callable, commit_domains: Callable, capture_extensions: Callable = Callable(), prepare_extensions: Callable = Callable(), commit_extensions: Callable = Callable()) -> void:
	_registry = registry
	_factions = factions
	_capture_player = capture_player
	_prepare_player = prepare_player
	_commit_player = commit_player
	_capture_domains = capture_domains
	_prepare_domains = prepare_domains
	_commit_domains = commit_domains
	_capture_extensions = capture_extensions
	_prepare_extensions = prepare_extensions
	_commit_extensions = commit_extensions


func capture_snapshot() -> Dictionary:
	if not _has_contract_methods() or not _capture_callbacks_valid() or not _extension_callbacks_valid():
		return {}
	var player_variant: Variant = _capture_player.call()
	var domains_variant: Variant = _capture_domains.call()
	if typeof(player_variant) != TYPE_DICTIONARY or typeof(domains_variant) != TYPE_DICTIONARY:
		return {}
	var result: Dictionary = {
		"player": (player_variant as Dictionary).duplicate(true),
		"entities": _registry.call("snapshot_records"),
		"factions": _factions.call("snapshot_standings"),
		"domains": (domains_variant as Dictionary).duplicate(true)
	}
	if _extension_callbacks_configured():
		var extensions_variant: Variant = _capture_extensions.call()
		if typeof(extensions_variant) != TYPE_DICTIONARY or _has_owned_root_key(extensions_variant):
			return {}
		for key: Variant in extensions_variant:
			result[key] = extensions_variant[key].duplicate(true) if typeof(extensions_variant[key]) == TYPE_DICTIONARY or typeof(extensions_variant[key]) == TYPE_ARRAY else extensions_variant[key]
	if not _validate_value(result, 0, [MAX_TOTAL_VALUES], MAX_DEPTH + 3):
		return {}
	return result


func validate_snapshot(candidate: Dictionary) -> bool:
	if not _has_contract_methods() or not _capture_callbacks_valid() or not _extension_callbacks_valid():
		return false
	if not _validate_value(candidate, 0, [MAX_TOTAL_VALUES], MAX_DEPTH + 3):
		return false
	if not candidate.has("player") or typeof(candidate["player"]) != TYPE_DICTIONARY:
		return false
	if not candidate.has("entities") or typeof(candidate["entities"]) != TYPE_ARRAY:
		return false
	if not candidate.has("factions") or typeof(candidate["factions"]) != TYPE_DICTIONARY:
		return false
	if not candidate.has("domains") or typeof(candidate["domains"]) != TYPE_DICTIONARY:
		return false
	if not _extension_callbacks_configured() and _has_extension_records(candidate):
		return false
	return _registry.call("validate_snapshot_records", candidate["entities"]) and _factions.call("validate_snapshot_standings", candidate["factions"])


func apply_snapshot(candidate: Dictionary) -> bool:
	if not validate_snapshot(candidate):
		return false
	var registry_prepared: Dictionary = _registry.call("prepare_snapshot_replacement", candidate["entities"])
	var factions_prepared: Dictionary = _factions.call("prepare_snapshot_replacement", candidate["factions"])
	var player_result: Variant = _prepare_player.call(candidate["player"].duplicate(true))
	var domains_result: Variant = _prepare_domains.call(candidate["domains"].duplicate(true))
	var extensions_result: Variant = {"ok": true, "prepared": {}}
	if _extension_callbacks_configured():
		extensions_result = _prepare_extensions.call(_extension_records(candidate).duplicate(true))
	if not registry_prepared.get("ok", false) or not factions_prepared.get("ok", false):
		return false
	if not _valid_preparation(player_result) or not _valid_preparation(domains_result) or not _valid_preparation(extensions_result):
		return false
	# All participants have prepared copies. Commit methods are deliberately void and must not signal or fail.
	_registry.call("commit_prepared_snapshot", registry_prepared)
	_factions.call("commit_prepared_snapshot", factions_prepared)
	_commit_player.call(player_result["prepared"])
	_commit_domains.call(domains_result["prepared"])
	if _extension_callbacks_configured():
		_commit_extensions.call(extensions_result["prepared"])
	return true


func _has_contract_methods() -> bool:
	return _registry != null and _registry.has_method("snapshot_records") and _registry.has_method("validate_snapshot_records") and _registry.has_method("prepare_snapshot_replacement") and _registry.has_method("commit_prepared_snapshot") and _factions != null and _factions.has_method("snapshot_standings") and _factions.has_method("validate_snapshot_standings") and _factions.has_method("prepare_snapshot_replacement") and _factions.has_method("commit_prepared_snapshot")


func _capture_callbacks_valid() -> bool:
	return _capture_player.is_valid() and _prepare_player.is_valid() and _commit_player.is_valid() and _capture_domains.is_valid() and _prepare_domains.is_valid() and _commit_domains.is_valid()


func _extension_callbacks_configured() -> bool:
	return _capture_extensions.is_valid() or _prepare_extensions.is_valid() or _commit_extensions.is_valid()


func _extension_callbacks_valid() -> bool:
	return not _extension_callbacks_configured() or (_capture_extensions.is_valid() and _prepare_extensions.is_valid() and _commit_extensions.is_valid())


func _has_extension_records(candidate: Dictionary) -> bool:
	for key: Variant in candidate:
		if not OWNED_ROOT_KEYS.has(key):
			return true
	return false


func _extension_records(candidate: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in candidate:
		if not OWNED_ROOT_KEYS.has(key):
			result[key] = candidate[key].duplicate(true) if typeof(candidate[key]) == TYPE_DICTIONARY or typeof(candidate[key]) == TYPE_ARRAY else candidate[key]
	return result


func _has_owned_root_key(candidate: Dictionary) -> bool:
	for key: Variant in OWNED_ROOT_KEYS:
		if candidate.has(key):
			return true
	return false


func _valid_preparation(result: Variant) -> bool:
	if typeof(result) != TYPE_DICTIONARY or not result.get("ok", false) or not result.has("prepared") or typeof(result["prepared"]) != TYPE_DICTIONARY:
		return false
	return _validate_value(result["prepared"], 0, [MAX_TOTAL_VALUES], MAX_DEPTH + 3)


func _validate_value(value: Variant, depth: int, budget: Array, max_depth: int) -> bool:
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
			for child: Variant in value:
				if not _validate_value(child, depth + 1, budget, max_depth):
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
