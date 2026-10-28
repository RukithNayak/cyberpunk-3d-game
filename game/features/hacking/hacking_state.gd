extends RefCounted
class_name HackingState
## Data-only energy and cooldown values. It never retains gameplay Nodes.

signal energy_changed(current: float, maximum: float)

var current_energy: float = 100.0
var max_energy: float = 100.0
var regen_rate_per_sec: float = 8.0
var _cooldowns: Dictionary = {}


func configure(maximum: float, regeneration_rate: float, starting_energy: float = -1.0) -> bool:
	if not is_finite(maximum) or maximum <= 0.0:
		return false
	if not is_finite(regeneration_rate) or regeneration_rate < 0.0:
		return false
	var initial: float = maximum if starting_energy == -1.0 else starting_energy
	if not is_finite(initial) or initial < 0.0 or initial > maximum:
		return false
	max_energy = maximum
	regen_rate_per_sec = regeneration_rate
	current_energy = initial
	_cooldowns.clear()
	energy_changed.emit(current_energy, max_energy)
	return true


func try_spend(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0 or amount > current_energy:
		return false
	current_energy -= amount
	energy_changed.emit(current_energy, max_energy)
	return true


func refund(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0:
		return false
	current_energy = minf(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)
	return true


func tick(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0:
		return false
	if delta == 0.0:
		return true
	var old_energy: float = current_energy
	current_energy = minf(max_energy, current_energy + regen_rate_per_sec * delta)
	if not is_equal_approx(old_energy, current_energy):
		energy_changed.emit(current_energy, max_energy)
	for key_variant: Variant in _cooldowns.keys():
		var remaining: float = maxf(0.0, float(_cooldowns[key_variant]) - delta)
		if remaining <= 0.0:
			_cooldowns.erase(key_variant)
		else:
			_cooldowns[key_variant] = remaining
	return true


func get_cooldown_remaining(target_uuid: String, ability_id: int) -> float:
	return float(_cooldowns.get(_cooldown_key(target_uuid, ability_id), 0.0))


func start_cooldown(target_uuid: String, ability_id: int, duration_seconds: float) -> bool:
	if target_uuid.is_empty() or ability_id < 0 or not is_finite(duration_seconds) or duration_seconds < 0.0:
		return false
	if duration_seconds == 0.0:
		return true
	var key: String = _cooldown_key(target_uuid, ability_id)
	if _cooldowns.has(key):
		return false
	_cooldowns[key] = duration_seconds
	return true


func clear_cooldown(target_uuid: String, ability_id: int) -> void:
	_cooldowns.erase(_cooldown_key(target_uuid, ability_id))


func _cooldown_key(target_uuid: String, ability_id: int) -> String:
	return "%s::%d" % [target_uuid, ability_id]
