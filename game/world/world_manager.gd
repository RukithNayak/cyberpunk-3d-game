extends RefCounted
class_name WorldManager

## Desired lifecycle coordinator. It never loads or frees scene resources.

signal chunk_pre_unload(payload: Dictionary)
signal chunk_activated(payload: Dictionary)
signal chunk_deactivated(payload: Dictionary)

enum LoadState { UNLOADED, PRELOADING, ACTIVE }

var preload_margin: float = 12.0
var hysteresis_margin: float = 4.0
var _manifest: ChunkManifest
var _configured: bool = false
var _desired: Dictionary = {}
var _states: Dictionary = {}
var _generations: Dictionary = {}


func configure(manifest: ChunkManifest, configured_preload_margin: float = 12.0, configured_hysteresis_margin: float = 4.0) -> bool:
	if _configured:
		return false
	if manifest == null or manifest.get_chunk_ids().is_empty():
		return false
	if not is_finite(configured_preload_margin) or not is_finite(configured_hysteresis_margin):
		return false
	if configured_preload_margin < 0.0 or configured_hysteresis_margin < 0.0:
		return false
	_manifest = manifest
	preload_margin = configured_preload_margin
	hysteresis_margin = configured_hysteresis_margin
	_desired.clear()
	_states.clear()
	_generations.clear()
	for chunk_id: String in manifest.get_chunk_ids():
		_states[chunk_id] = LoadState.UNLOADED
		_generations[chunk_id] = 0
	_configured = true
	return true


func update_player_position(pos: Vector3) -> void:
	if _manifest == null or not _is_finite_vector(pos):
		return
	var next_desired: Dictionary = {}
	var entering_ids: Array[String] = []
	for chunk_id: String in _manifest.get_chunk_ids():
		var record: Dictionary = _manifest.get_chunk(chunk_id)
		var bounds: AABB = record["bounds"]
		var was_desired: bool = _desired.has(chunk_id)
		var margin: float = preload_margin + (hysteresis_margin if was_desired else 0.0)
		if bounds.grow(margin).has_point(pos):
			next_desired[chunk_id] = true
			if not was_desired:
				entering_ids.append(chunk_id)
	var removed_ids: Array[String] = []
	var unload_payloads: Array[Dictionary] = []
	for chunk_id: String in _desired:
		if next_desired.has(chunk_id):
			continue
		var generation: int = _generations[chunk_id] + 1
		removed_ids.append(chunk_id)
		_generations[chunk_id] = generation
		if _states[chunk_id] == LoadState.PRELOADING:
			_states[chunk_id] = LoadState.UNLOADED
		unload_payloads.append(_payload(chunk_id, generation))
	for chunk_id: String in removed_ids:
		_desired.erase(chunk_id)
	_desired = next_desired
	for chunk_id: String in entering_ids:
		_generations[chunk_id] += 1
		_states[chunk_id] = LoadState.PRELOADING
	for payload: Dictionary in unload_payloads:
		chunk_pre_unload.emit(payload)


func get_desired_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id: String in _desired:
		ids.append(chunk_id)
	ids.sort()
	return ids


func get_load_state(chunk_id: String) -> int:
	return int(_states.get(chunk_id, LoadState.UNLOADED))


func get_lifecycle_generation(chunk_id: String) -> int:
	return int(_generations.get(chunk_id, -1))


func acknowledge_activated(chunk_id: String, generation: int) -> bool:
	if not _desired.has(chunk_id) or not _states.has(chunk_id):
		return false
	if generation != _generations[chunk_id] or _states[chunk_id] != LoadState.PRELOADING:
		return false
	_states[chunk_id] = LoadState.ACTIVE
	chunk_activated.emit(_payload(chunk_id, generation))
	return true


func acknowledge_deactivated(chunk_id: String, generation: int) -> bool:
	if not _states.has(chunk_id) or _states[chunk_id] != LoadState.ACTIVE:
		return false
	if generation != _generations[chunk_id] or _desired.has(chunk_id):
		return false
	_states[chunk_id] = LoadState.UNLOADED
	chunk_deactivated.emit(_payload(chunk_id, generation))
	return true


func _payload(chunk_id: String, generation: int) -> Dictionary:
	return {"chunk_id": chunk_id, "lifecycle_generation": generation}


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
