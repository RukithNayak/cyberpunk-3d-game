extends RefCounted
class_name CombatFeedback
## Presentation event counts derived from authoritative combat/health signals.

signal feedback_event(kind: String)

var accepted_shot_count: int = 0
var hit_confirm_count: int = 0
var damage_event_count: int = 0
var death_event_count: int = 0


func register_shot(result: HitResult) -> void:
	if result == null or not result.fired:
		return
	accepted_shot_count += 1
	if result.target_node != null and result.damage_applied > 0:
		hit_confirm_count += 1
		feedback_event.emit("hit")
	else:
		feedback_event.emit("shot")


func register_health_change(previous_hp: int, current_hp: int) -> void:
	if current_hp < previous_hp:
		damage_event_count += 1
		feedback_event.emit("damage")


func register_death() -> void:
	death_event_count += 1
	feedback_event.emit("death")
