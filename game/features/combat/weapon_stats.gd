extends Resource
class_name WeaponStats

@export_range(1, 200, 1) var damage: int = 24
@export_range(0.1, 30.0, 0.1) var fire_rate_per_second: float = 5.0
@export_range(1.0, 200.0, 1.0) var range_m: float = 40.0
@export_range(0.0, 10.0, 0.05) var spread_degrees: float = 0.65
@export_range(0.0, 10.0, 0.05) var recoil_degrees: float = 0.7
@export_range(0.0, 200.0, 1.0) var falloff_start_m: float = 20.0
@export_range(0.0, 200.0, 1.0) var minimum_damage: float = 12.0
@export var source_faction: StringName = &"player"


func damage_at_distance(distance_m: float) -> int:
	if distance_m <= falloff_start_m:
		return damage
	if distance_m >= range_m:
		return roundi(minf(float(damage), minimum_damage))
	var amount: float = inverse_lerp(range_m, falloff_start_m, distance_m)
	return roundi(lerpf(minimum_damage, float(damage), amount))
