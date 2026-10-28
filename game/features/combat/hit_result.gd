extends RefCounted
class_name HitResult

var fired: bool = false
var rejected_reason: String = ""
var hit_position: Vector3 = Vector3.ZERO
var surface_normal: Vector3 = Vector3.ZERO
var target_node: Node
var damage_applied: int = 0
var distance_m: float = 0.0


func to_data() -> Dictionary:
	return {
		"fired": fired,
		"rejected_reason": rejected_reason,
		"hit_position": hit_position,
		"surface_normal": surface_normal,
		"damage_applied": damage_applied,
		"distance_m": distance_m,
	}
