extends SceneTree
## Dependency-free runner. Register focused suites here; intentional failure is opt-in.

var _cases: int = 0
var _failures: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--suite":
		printerr("Usage: -- --suite <sample|all|registry|save_store|world_manifest|health|migrations|chunk_loader|chunk_persistence|player_controller|hitscan|weapon_transactions|player_hud|inventory_items|inventory_grid|inventory_equipment|inventory_persistence|inventory_ui|hacking_energy|hacking_door|ai_perception|ai_states|ai_navigation|ai_unload|navigation_handoff|ai_encounter|interiors|deliberate_failure>")
		quit(2)
		return
	var suite: String = args[1]
	match suite:
		"sample", "all":
			_check(2 + 2 == 4, "sample arithmetic")
			var original: Dictionary = {"flags": {"open": false}}
			var copied: Dictionary = original.duplicate(true)
			copied["flags"]["open"] = true
			_check(not original["flags"]["open"], "sample nested copy isolation")
			if suite == "all":
				_run_isolated_navigation_suite()
				var registry_test: RefCounted = load("res://tests/persistence/test_registry.gd").new()
				registry_test.run(_check)
				var health_test: RefCounted = load("res://tests/player/test_health.gd").new()
				health_test.run(_check)
				var save_test: RefCounted = load("res://tests/persistence/test_save_store.gd").new()
				save_test.run(_check)
				var world_test: RefCounted = load("res://tests/world/test_manifest.gd").new()
				world_test.run(_check)
				var migration_test: RefCounted = load("res://tests/persistence/test_migrations.gd").new()
				migration_test.run(_check)
				var loader_test: RefCounted = load("res://tests/world/test_chunk_loader.gd").new()
				await loader_test.run(_check)
				var chunk_state_test: RefCounted = load("res://tests/world/test_chunk_persistence.gd").new()
				await chunk_state_test.run(_check)
				var interiors_test: RefCounted = load("res://tests/world/test_interiors.gd").new()
				await interiors_test.run(_check)
				var controller_test: RefCounted = load("res://tests/player/test_controller.gd").new()
				await controller_test.run(_check)
				var hitscan_test: RefCounted = load("res://tests/combat/test_hitscan.gd").new()
				await hitscan_test.run(_check)
				var weapon_transaction_test: RefCounted = load("res://tests/combat/test_weapon_transactions.gd").new()
				await weapon_transaction_test.run(_check)
				var player_hud_test: RefCounted = load("res://tests/player/test_hud.gd").new()
				await player_hud_test.run(_check)
				var item_test: RefCounted = load("res://tests/inventory/test_items.gd").new()
				item_test.run(_check)
				var grid_test: RefCounted = load("res://tests/inventory/test_grid.gd").new()
				await grid_test.run(_check)
				var equipment_test: RefCounted = load("res://tests/inventory/test_equipment.gd").new()
				equipment_test.run(_check)
				var persistence_test: RefCounted = load("res://tests/inventory/test_persistence.gd").new()
				await persistence_test.run(_check)
				var inventory_ui_test: RefCounted = load("res://tests/inventory/test_ui.gd").new()
				await inventory_ui_test.run(_check)
				var hacking_energy_test: RefCounted = load("res://tests/hacking/test_energy.gd").new()
				await hacking_energy_test.run(_check)
				var hacking_door_test: RefCounted = load("res://tests/hacking/test_door.gd").new()
				await hacking_door_test.run(_check)
				var ai_perception_test: RefCounted = load("res://tests/ai/test_perception.gd").new()
				await ai_perception_test.run(_check)
				var ai_states_test: RefCounted = load("res://tests/ai/test_states.gd").new()
				await ai_states_test.run(_check)
				var ai_unload_test: RefCounted = load("res://tests/ai/test_unload.gd").new()
				await ai_unload_test.run(_check)
				await process_frame
				var encounter_test: RefCounted = load("res://tests/ai/test_encounter.gd").new()
				await encounter_test.run(_check)
		"registry":
			var registry_test: RefCounted = load("res://tests/persistence/test_registry.gd").new()
			registry_test.run(_check)
		"save_store":
			var save_test: RefCounted = load("res://tests/persistence/test_save_store.gd").new()
			save_test.run(_check)
		"world_manifest":
			var world_test: RefCounted = load("res://tests/world/test_manifest.gd").new()
			world_test.run(_check)
		"health":
			var health_test: RefCounted = load("res://tests/player/test_health.gd").new()
			health_test.run(_check)
		"migrations":
			var migration_test: RefCounted = load("res://tests/persistence/test_migrations.gd").new()
			migration_test.run(_check)
		"chunk_loader":
			var loader_test: RefCounted = load("res://tests/world/test_chunk_loader.gd").new()
			await loader_test.run(_check)
		"chunk_persistence":
			var persistence_test: RefCounted = load("res://tests/world/test_chunk_persistence.gd").new()
			await persistence_test.run(_check)
		"interiors":
			var interiors_test: RefCounted = load("res://tests/world/test_interiors.gd").new()
			await interiors_test.run(_check)
		"player_controller":
			var controller_test: RefCounted = load("res://tests/player/test_controller.gd").new()
			await controller_test.run(_check)
		"hitscan":
			var hitscan_test: RefCounted = load("res://tests/combat/test_hitscan.gd").new()
			await hitscan_test.run(_check)
		"weapon_transactions":
			var weapon_transaction_test: RefCounted = load("res://tests/combat/test_weapon_transactions.gd").new()
			await weapon_transaction_test.run(_check)
		"player_hud":
			var player_hud_test: RefCounted = load("res://tests/player/test_hud.gd").new()
			await player_hud_test.run(_check)
		"inventory_items":
			var item_test: RefCounted = load("res://tests/inventory/test_items.gd").new()
			item_test.run(_check)
		"inventory_grid":
			var grid_test: RefCounted = load("res://tests/inventory/test_grid.gd").new()
			await grid_test.run(_check)
		"inventory_equipment":
			var equipment_test: RefCounted = load("res://tests/inventory/test_equipment.gd").new()
			equipment_test.run(_check)
		"inventory_persistence":
			var persistence_test: RefCounted = load("res://tests/inventory/test_persistence.gd").new()
			await persistence_test.run(_check)
		"inventory_ui":
			var inventory_ui_test: RefCounted = load("res://tests/inventory/test_ui.gd").new()
			await inventory_ui_test.run(_check)
		"hacking_energy":
			var hacking_energy_test: RefCounted = load("res://tests/hacking/test_energy.gd").new()
			await hacking_energy_test.run(_check)
		"hacking_door":
			var hacking_door_test: RefCounted = load("res://tests/hacking/test_door.gd").new()
			await hacking_door_test.run(_check)
		"ai_perception":
			var ai_perception_test: RefCounted = load("res://tests/ai/test_perception.gd").new()
			await ai_perception_test.run(_check)
		"ai_states":
			var ai_states_test: RefCounted = load("res://tests/ai/test_states.gd").new()
			await ai_states_test.run(_check)
		"ai_navigation":
			var ai_navigation_test: Node3D = (load("res://tests/scenes/ai_navigation.tscn") as PackedScene).instantiate() as Node3D
			ai_navigation_test.set("launch_demo", false)
			root.add_child(_create_isolated_navigation_viewport(ai_navigation_test))
			await ai_navigation_test.call("run", _check)
		"ai_unload":
			var ai_unload_test: RefCounted = load("res://tests/ai/test_unload.gd").new()
			await ai_unload_test.run(_check)
		"navigation_handoff":
			await process_frame
			var navigation_handoff_test: Node3D = (load("res://tests/scenes/navigation_boundary.tscn") as PackedScene).instantiate() as Node3D
			root.add_child(navigation_handoff_test)
			await process_frame
			await navigation_handoff_test.call("run", _check)
		"ai_encounter":
			var encounter_test: RefCounted = load("res://tests/ai/test_encounter.gd").new()
			await encounter_test.run(_check)
		"deliberate_failure":
			_check(false, "intentional failing fixture")
		_:
			printerr("Unknown suite: %s" % suite)
			quit(2)
			return
	print("Suite %s: %d cases, %d failures" % [suite, _cases, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	_cases += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		printerr("FAIL: %s" % description)


func _create_isolated_navigation_viewport(fixture: Node3D) -> SubViewport:
	var isolated_viewport: SubViewport = SubViewport.new()
	isolated_viewport.name = "AiNavigationTestViewport"
	isolated_viewport.size = Vector2i(128, 128)
	isolated_viewport.own_world_3d = true
	isolated_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	isolated_viewport.add_child(fixture)
	return isolated_viewport


func _run_isolated_navigation_suite() -> void:
	var project_path: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", project_path,
		"--script", "res://tests/run_tests.gd",
		"--", "--suite", "ai_navigation",
	], output, true)
	var passed_cases: int = 0
	var failed_cases: int = 0
	var combined_output: String = ""
	for item: Variant in output:
		combined_output += str(item) + "\n"
	for line: String in combined_output.split("\n"):
		if line.begins_with("PASS: "):
			passed_cases += 1
		elif line.begins_with("FAIL: "):
			failed_cases += 1
	_cases += passed_cases + failed_cases
	_failures += failed_cases
	if exit_code != 0 and failed_cases == 0:
		_failures += 1
	if not output.is_empty():
		print(combined_output)
	_check(exit_code == 0, "AI navigation isolated process exits successfully (%d)" % exit_code)
