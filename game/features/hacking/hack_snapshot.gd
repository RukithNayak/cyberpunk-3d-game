extends RefCounted
class_name HackSnapshot
## Data-only active hack records with a runtime-only weak projection cache.

const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
const MAX_ACTIVE_EFFECTS: int = 1024
const TIMED_ABILITIES: Array[int] = [
	HackDefinition.Ability.DISABLE_CAMERA,
	HackDefinition.Ability.DISRUPT_IMPLANT,
	HackDefinition.Ability.DISABLE_TURRET,
]

var _effects: Array[Dictionary] = []
var _target_refs: Dictionary = {}
var _target_chunks: Dictionary = {}
var _active_chunks: Dictionary = {}
var _manager: WorldManager
var _uuid_regex: RegEx = RegEx.new()
var _configured: bool = false
var _pending_reconcile: Dictionary = {}


func _init() -> void:
	_uuid_regex.compile(UUID_PATTERN)


func configure(world_manager: WorldManager) -> bool:
	if _configured or world_manager == null:
		return false
	_manager = world_manager
	_manager.chunk_pre_unload.connect(_on_chunk_pre_unload)
	_manager.chunk_activated.connect(_on_chunk_activated)
	for chunk_id: String in _manager.get_desired_chunk_ids():
		if _manager.get_load_state(chunk_id) == WorldManager.LoadState.ACTIVE:
			_active_chunks[chunk_id] = true
	_configured = true
	return true


func register_target(target: Node3D, chunk_id: String) -> bool:
	if not _configured or not _is_live_node(target) or chunk_id.is_empty() or chunk_id != chunk_id.strip_edges():
		return false
	if not target.has_method("get_persistent_uuid"):
		return false
	if not target.has_method("restore_hack_effect") or not target.has_method("set_hack_remaining") \
		or not target.has_method("clear_hack_effect") or not target.has_method("set_external_hack_clock"):
		return false
	var target_uuid: String = String(target.call("get_persistent_uuid"))
	if _uuid_regex.search(target_uuid) == null:
		return false
	var active_effect: Dictionary = _find_effect(target_uuid, -1)
	if not active_effect.is_empty() and String(active_effect["chunk_id"]) != chunk_id:
		_remove_effect(target_uuid, int(active_effect["ability_id"]))
		return false
	_target_refs[target_uuid] = weakref(target)
	_target_chunks[target_uuid] = chunk_id
	target.call("set_external_hack_clock", true)
	if not _active_chunks.has(chunk_id):
		return true
	var record: Dictionary = _find_effect(target_uuid, -1)
	if not record.is_empty():
		var restored: bool = _restore_target_effect(target, record)
		_pending_reconcile.erase(target_uuid)
		return restored
	_pending_reconcile.erase(target_uuid)
	return true


func unregister_target(target_uuid: String) -> void:
	var target: Node3D = _resolve_target(target_uuid)
	if target != null and target.has_method("set_external_hack_clock"):
		target.call("set_external_hack_clock", false)
	_target_refs.erase(target_uuid)
	_target_chunks.erase(target_uuid)
	_pending_reconcile.erase(target_uuid)


func can_record_effect(target_uuid: String, ability_id: int, remaining_seconds: float, chunk_id: String) -> bool:
	if not _configured or _uuid_regex.search(target_uuid) == null or not TIMED_ABILITIES.has(ability_id):
		return false
	if not is_finite(remaining_seconds) or remaining_seconds <= 0.0 or chunk_id.is_empty() or chunk_id != chunk_id.strip_edges():
		return false
	return _find_effect(target_uuid, ability_id).is_empty() and _effects.size() < MAX_ACTIVE_EFFECTS


func record_effect(target_uuid: String, ability_id: int, remaining_seconds: float, chunk_id: String) -> bool:
	if not can_record_effect(target_uuid, ability_id, remaining_seconds, chunk_id):
		return false
	_effects.append({
		"target_uuid": target_uuid,
		"ability_id": ability_id,
		"remaining_seconds": remaining_seconds,
		"chunk_id": chunk_id,
	})
	var target: Node3D = _resolve_target(target_uuid)
	if target != null and target.has_method("set_hack_remaining"):
		target.call("set_hack_remaining", ability_id, remaining_seconds)
	return true


func advance_active_time(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0:
		return false
	if not _pending_reconcile.is_empty():
		_reconcile_targets()
		_pending_reconcile.clear()
	if delta == 0.0:
		return true
	for index: int in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[index]
		var chunk_id: String = String(effect["chunk_id"])
		if not _active_chunks.has(chunk_id):
			continue
		var target_uuid: String = String(effect["target_uuid"])
		var target: Node3D = _resolve_target(target_uuid)
		if _target_refs.has(target_uuid) and target == null:
			_effects.remove_at(index)
			_target_refs.erase(target_uuid)
			_target_chunks.erase(target_uuid)
			continue
		var remaining: float = maxf(0.0, float(effect["remaining_seconds"]) - delta)
		if remaining <= 0.0:
			_effects.remove_at(index)
			if target != null and target.has_method("clear_hack_effect"):
				target.call("clear_hack_effect", int(effect["ability_id"]))
		else:
			effect["remaining_seconds"] = remaining
			_effects[index] = effect
			if target != null and target.has_method("set_hack_remaining"):
				target.call("set_hack_remaining", int(effect["ability_id"]), remaining)
	return true


func get_remaining_seconds(target_uuid: String, ability_id: int) -> float:
	var effect: Dictionary = _find_effect(target_uuid, ability_id)
	return float(effect.get("remaining_seconds", 0.0))


func capture_domain() -> Dictionary:
	return {"active_hacks": _effects.duplicate(true)}


func prepare_domain(candidate: Dictionary) -> Dictionary:
	if candidate.size() != 1 or typeof(candidate.get("active_hacks")) != TYPE_ARRAY:
		return {"ok": false}
	var raw_effects: Array = candidate["active_hacks"]
	if raw_effects.size() > MAX_ACTIVE_EFFECTS:
		return {"ok": false}
	var prepared_effects: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in raw_effects:
		if typeof(raw) != TYPE_DICTIONARY or raw.size() != 4:
			return {"ok": false}
		var effect: Dictionary = raw
		var target_uuid: Variant = effect.get("target_uuid")
		var ability_id: Variant = effect.get("ability_id")
		var remaining: Variant = effect.get("remaining_seconds")
		var chunk_id: Variant = effect.get("chunk_id")
		if typeof(target_uuid) != TYPE_STRING or _uuid_regex.search(target_uuid) == null:
			return {"ok": false}
		if typeof(ability_id) != TYPE_INT or not TIMED_ABILITIES.has(ability_id):
			return {"ok": false}
		if typeof(remaining) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(remaining)) or float(remaining) <= 0.0:
			return {"ok": false}
		if typeof(chunk_id) != TYPE_STRING or chunk_id.is_empty() or chunk_id != chunk_id.strip_edges():
			return {"ok": false}
		var key: String = "%s::%d" % [target_uuid, ability_id]
		if seen.has(key):
			return {"ok": false}
		seen[key] = true
		prepared_effects.append({
			"target_uuid": target_uuid,
			"ability_id": ability_id,
			"remaining_seconds": float(remaining),
			"chunk_id": chunk_id,
		})
	return {"ok": true, "prepared": {"active_hacks": prepared_effects}}


func commit_domain(prepared: Dictionary) -> bool:
	if prepared.get("ok") != true or typeof(prepared.get("prepared")) != TYPE_DICTIONARY:
		return false
	var candidate: Dictionary = prepared["prepared"]
	if candidate.size() != 1 or typeof(candidate.get("active_hacks")) != TYPE_ARRAY:
		return false
	_effects.clear()
	for effect: Dictionary in candidate["active_hacks"]:
		_effects.append(effect.duplicate(true))
	_pending_reconcile.clear()
	for target_uuid: Variant in _target_refs:
		_pending_reconcile[target_uuid] = true
	return true


func _on_chunk_pre_unload(payload: Dictionary) -> void:
	var chunk_id: String = String(payload.get("chunk_id", ""))
	_active_chunks.erase(chunk_id)
	for target_uuid: Variant in _target_chunks.keys():
		if _target_chunks[target_uuid] != chunk_id:
			continue
		_target_refs.erase(target_uuid)
		_target_chunks.erase(target_uuid)


func _on_chunk_activated(payload: Dictionary) -> void:
	var chunk_id: String = String(payload.get("chunk_id", ""))
	_active_chunks[chunk_id] = true
	for target_uuid: Variant in _target_chunks:
		if _target_chunks[target_uuid] != chunk_id:
			continue
		var target: Node3D = _resolve_target(target_uuid)
		var effect: Dictionary = _find_effect(target_uuid, -1)
		if target != null and not effect.is_empty():
			_restore_target_effect(target, effect)
		_pending_reconcile.erase(target_uuid)


func _restore_target_effect(target: Node3D, effect: Dictionary) -> bool:
	if not target.has_method("restore_hack_effect"):
		return false
	return bool(target.call("restore_hack_effect", int(effect["ability_id"]), float(effect["remaining_seconds"])))


func _find_effect(target_uuid: String, ability_id: int) -> Dictionary:
	for effect: Dictionary in _effects:
		if effect["target_uuid"] == target_uuid and (ability_id < 0 or int(effect["ability_id"]) == ability_id):
			return effect
	return {}


func _remove_effect(target_uuid: String, ability_id: int) -> void:
	for index: int in range(_effects.size() - 1, -1, -1):
		if _effects[index]["target_uuid"] == target_uuid and int(_effects[index]["ability_id"]) == ability_id:
			_effects.remove_at(index)


func _resolve_target(target_uuid: String) -> Node3D:
	var weak_target: WeakRef = _target_refs.get(target_uuid) as WeakRef
	if weak_target == null:
		return null
	var target: Node3D = weak_target.get_ref() as Node3D
	return target if _is_live_node(target) else null


func _reconcile_targets() -> void:
	for target_uuid: Variant in _pending_reconcile.keys():
		var target: Node3D = _resolve_target(target_uuid)
		if target == null:
			continue
		var next_effect: Dictionary = _find_effect(target_uuid, -1)
		if next_effect.is_empty():
			for ability_id: int in TIMED_ABILITIES:
				if target.has_method("clear_hack_effect"):
					target.call("clear_hack_effect", ability_id)
		elif not _restore_target_effect(target, next_effect):
			for index: int in range(_effects.size() - 1, -1, -1):
				if _effects[index]["target_uuid"] == target_uuid:
					_effects.remove_at(index)


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
