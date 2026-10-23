extends HackingEncounterBase

func _init() -> void:
	encounter_id = "neon_market_alley"
	palette_primary = Color("00f5ff")
	palette_secondary = Color("ff2d9b")
	security_ability = HackDefinition.Ability.DISABLE_CAMERA
	include_door = true


func _build_encounter() -> void:
	# The red service gate divides the short main lane. A continuous right-hand
	# maintenance walk stays open and rejoins beyond it.
	_add_box("MarketStallLeft", Vector3(-8.0, 0.9, -2.5), Vector3(3.0, 1.8, 2.5), Color("4b354c"), true)
	_add_box("MaintenanceBypassWall", Vector3(-2.6, 1.2, -6.0), Vector3(2.4, 2.4, 0.4), Color("303948"), true)
	_add_box("NeonOverhang", Vector3(4.8, 5.2, -3.0), Vector3(2.2, 0.12, 2.6), palette_primary, false)
	_add_box("CableBridge", Vector3(-3.0, 7.3, -9.0), Vector3(12.0, 0.3, 0.7), Color("424857"), false)
