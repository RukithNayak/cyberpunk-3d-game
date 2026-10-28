extends RefCounted
class_name FactionState
## Bounded faction standings. Thresholds are engineering defaults, not balance approval.

const MIN_STANDING: int = -100
const MAX_STANDING: int = 100
const DEFAULT_HOSTILE_THRESHOLD: int = -50
const DEFAULT_ALLIED_THRESHOLD: int = 50

var _standings: Dictionary = {}
var _hostile_threshold: int = DEFAULT_HOSTILE_THRESHOLD
var _allied_threshold: int = DEFAULT_ALLIED_THRESHOLD


func _init(faction_ids: Array[String] = []) -> void:
	for faction_id: String in faction_ids:
		if _is_valid_faction_id(faction_id):
			_standings[faction_id] = 0


func configure_thresholds(hostile_threshold: int, allied_threshold: int) -> bool:
	if hostile_threshold < MIN_STANDING or hostile_threshold > MAX_STANDING:
		return false
	if allied_threshold < MIN_STANDING or allied_threshold > MAX_STANDING:
		return false
	if hostile_threshold >= allied_threshold:
		return false
	_hostile_threshold = hostile_threshold
	_allied_threshold = allied_threshold
	return true


func get_faction_standing(faction_id: String) -> int:
	if not _standings.has(faction_id):
		return 0
	return _standings[faction_id]


func set_faction_standing(faction_id: String, standing: int) -> bool:
	if not _standings.has(faction_id):
		return false
	_standings[faction_id] = clampi(standing, MIN_STANDING, MAX_STANDING)
	return true


func adjust_faction_standing(faction_id: String, delta: int) -> bool:
	if not _standings.has(faction_id):
		return false
	# Once the magnitude exceeds the full standing range, more precision cannot affect the clamp.
	# Bounding first keeps addition within a tiny safe integer range even for int64 extremes.
	var bounded_delta: int = clampi(delta, MIN_STANDING * 2, MAX_STANDING * 2)
	_standings[faction_id] = clampi(_standings[faction_id] + bounded_delta, MIN_STANDING, MAX_STANDING)
	return true


func is_hostile(faction_id: String) -> bool:
	return _standings.has(faction_id) and _standings[faction_id] <= _hostile_threshold


func is_allied(faction_id: String) -> bool:
	return _standings.has(faction_id) and _standings[faction_id] >= _allied_threshold


func snapshot_standings() -> Dictionary:
	var result: Dictionary = {}
	var faction_ids: Array = _standings.keys()
	faction_ids.sort()
	for faction_id_variant: Variant in faction_ids:
		var faction_id: String = faction_id_variant
		result[faction_id] = _standings[faction_id]
	return result


func validate_snapshot_standings(candidate: Variant) -> bool:
	var prepared: Dictionary = prepare_snapshot_replacement(candidate)
	return prepared.get("ok", false)


func prepare_snapshot_replacement(candidate: Variant) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY or candidate.size() != _standings.size():
		return {"ok": false}
	var replacement: Dictionary = {}
	for faction_id: String in _standings:
		if not candidate.has(faction_id):
			return {"ok": false}
		var standing: Variant = candidate[faction_id]
		if typeof(standing) != TYPE_INT or standing < MIN_STANDING or standing > MAX_STANDING:
			return {"ok": false}
		replacement[faction_id] = standing
	return {"ok": true, "standings": replacement}


func commit_prepared_snapshot(prepared: Dictionary) -> void:
	# Threshold configuration belongs to this same authoritative object and is retained.
	_standings = prepared["standings"]


func _is_valid_faction_id(faction_id: String) -> bool:
	return not faction_id.is_empty() and faction_id == faction_id.strip_edges()
