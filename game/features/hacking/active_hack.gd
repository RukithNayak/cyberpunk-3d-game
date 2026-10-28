extends RefCounted
class_name ActiveHack
## Runtime effect data. Deliberately contains no Node references.

var target_uuid: String = ""
var hack_type: int = -1
var remaining_duration: float = 0.0


func configure(stable_target_uuid: String, ability_id: int, duration_seconds: float) -> bool:
	if stable_target_uuid.is_empty() or ability_id < HackDefinition.Ability.DISABLE_CAMERA or ability_id > HackDefinition.Ability.DISABLE_TURRET:
		return false
	if not is_finite(duration_seconds) or duration_seconds < 0.0:
		return false
	target_uuid = stable_target_uuid
	hack_type = ability_id
	remaining_duration = duration_seconds
	return true


func to_data() -> Dictionary:
	return {
		"target_uuid": target_uuid,
		"hack_type": hack_type,
		"remaining_duration": remaining_duration,
	}
