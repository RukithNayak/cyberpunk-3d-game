extends RefCounted
class_name HealthState
## Data-only health. Damage alone emits on_death; hydration never replays death.
## Invalid constructor maxima use DEFAULT_MAX_HP; restore rejects invalid candidates.

signal on_death
signal health_changed(current: int, maximum: int)

const DEFAULT_MAX_HP: int = 100 # Engineering default, not balance approval.

var _current_hp: int = DEFAULT_MAX_HP
var _max_hp: int = DEFAULT_MAX_HP
var current_hp: int:
	get:
		return _current_hp
var max_hp: int:
	get:
		return _max_hp


func _init(maximum: int = DEFAULT_MAX_HP) -> void:
	_max_hp = maximum if maximum > 0 else DEFAULT_MAX_HP
	_current_hp = _max_hp


func apply_damage(amount: int, _source_faction: String) -> void:
	if amount <= 0 or is_dead():
		return
	_current_hp -= mini(amount, _current_hp)
	var became_dead: bool = is_dead()
	health_changed.emit(_current_hp, _max_hp)
	if became_dead:
		on_death.emit()


func heal(amount: int) -> void:
	if amount <= 0 or is_dead() or _current_hp == _max_hp:
		return
	_current_hp += mini(amount, _max_hp - _current_hp)
	health_changed.emit(_current_hp, _max_hp)


func is_dead() -> bool:
	return _current_hp == 0


func restore(current: int, maximum: int) -> bool:
	if maximum <= 0 or current < 0 or current > maximum:
		return false
	var changed: bool = current != _current_hp or maximum != _max_hp
	_current_hp = current
	_max_hp = maximum
	if changed:
		health_changed.emit(_current_hp, _max_hp)
	return true
