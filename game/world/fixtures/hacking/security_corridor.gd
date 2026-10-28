extends HackingEncounterBase

func _init() -> void:
	encounter_id = "corporate_transit_spine"
	palette_primary = Color("ffb12b")
	palette_secondary = Color("ff3156")
	security_ability = HackDefinition.Ability.DISABLE_TURRET
	include_turret = true
	include_guard = true


func _build_encounter() -> void:
	# Central firing lane is exposed; waist-high transit barriers and a side
	# maintenance aisle offer cover and a flank route around the turret.
	_add_box("TransitCoverA", Vector3(-3.2, 0.7, 1.0), Vector3(3.2, 1.4, 1.0), Color("58616c"), true)
	_add_box("TransitCoverB", Vector3(-4.2, 0.7, -5.8), Vector3(3.0, 1.4, 1.0), Color("434c59"), true)
	_add_box("FlankShield", Vector3(8.4, 1.2, -4.0), Vector3(1.0, 2.4, 9.0), Color("343e4a"), true)
	_add_box("TransitCeilingBeam", Vector3(0.0, 7.4, -8.0), Vector3(19.0, 0.22, 0.45), palette_primary, false)
	_add_box("WarningStrip", Vector3(-11.9, 2.8, -4.0), Vector3(0.12, 3.0, 12.0), palette_secondary, false)
