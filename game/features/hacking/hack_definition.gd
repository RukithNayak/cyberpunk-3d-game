extends Resource
class_name HackDefinition
## Data-only ability rules. Numeric defaults are tuning values, not approved balance.

enum Ability { DISABLE_CAMERA, UNLOCK_DOOR, TRIGGER_DISTRACTION, DISRUPT_IMPLANT, DISABLE_TURRET }

@export var ability_id: int = Ability.DISABLE_CAMERA
@export var display_name: String = "Disable Camera"
@export var required_target_group: StringName = &"hackable_camera"
@export_range(0.01, 100.0, 0.01) var energy_cost: float = 20.0
@export_range(0.0, 600.0, 0.1) var cooldown_seconds: float = 10.0
@export_range(0.0, 600.0, 0.1) var effect_duration_seconds: float = 8.0
@export_range(0.1, 1000.0, 0.1) var maximum_range: float = 18.0
@export_range(0.0, 10000.0, 0.1) var impact_damage: float = 0.0


func is_valid() -> bool:
	return ability_id >= Ability.DISABLE_CAMERA \
		and ability_id <= Ability.DISABLE_TURRET \
		and not display_name.strip_edges().is_empty() \
		and not required_target_group.is_empty() \
		and is_finite(energy_cost) and energy_cost > 0.0 \
		and is_finite(cooldown_seconds) and cooldown_seconds >= 0.0 \
		and is_finite(effect_duration_seconds) and effect_duration_seconds >= 0.0 \
		and is_finite(maximum_range) and maximum_range > 0.0 \
		and is_finite(impact_damage) and impact_damage >= 0.0
