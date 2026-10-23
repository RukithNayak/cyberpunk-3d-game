extends RefCounted
## AI-05 ambient behavior plus WORLD-05 seam encounter integration.

const FIXTURE_PATH: String = "res://tests/scenes/encounter_fixture.tscn"
const AMBIENT_SCRIPT_PATH: String = "res://features/npcs/ambient_agent.gd"


func run(check: Callable) -> void:
	var ambient_script: Script = load(AMBIENT_SCRIPT_PATH) as Script
	check.call(ambient_script != null, "AI-05 lightweight ambient agent script is available")
	if ambient_script == null:
		return
	await _test_ambient_update_and_faction_response(check, ambient_script)
	await _test_seam_encounter_and_crowd_unload(check)


func _test_ambient_update_and_faction_response(check: Callable, ambient_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node3D = Node3D.new()
	var ambient: AmbientAgent = ambient_script.new() as AmbientAgent
	var factions: FactionState = FactionState.new(["civilian", "gang_a", "player"])
	factions.set_faction_standing("gang_a", -50)
	check.call(ambient.configure(factions, "civilian", "district_a", 0.5), "ambient pedestrian configures faction, area and reduced tick interval")
	check.call(not ambient.has_method("submit_dialogue_request"), "ambient pedestrian has no inference request interface")
	for _step: int in range(180):
		ambient.tick(1.0 / 60.0)
	check.call(ambient.get_update_count() >= 5 and ambient.get_update_count() <= 7, "active ambient updates stay on the configured low-frequency clock (%d updates / 3s expected near 6)" % ambient.get_update_count())
	var updates_before_pause: int = ambient.get_update_count()
	ambient.set_simulation_active(false)
	for _step: int in range(600):
		ambient.tick(1.0 / 60.0)
	check.call(ambient.get_update_count() == updates_before_pause, "inactive ambient actor performs zero simulation updates")
	ambient.set_simulation_active(true)
	tree.root.add_child(root)
	root.add_child(ambient)
	await tree.process_frame
	var timer: Timer = ambient.get_node("AmbientUpdateTimer") as Timer
	check.call(timer != null and is_equal_approx(timer.wait_time, 0.5) and not timer.is_stopped(), "runtime ambient update timer starts at its configured interval")
	ambient.set_simulation_active(false)
	check.call(timer.is_stopped(), "inactive ambient actor stops its runtime timer")
	ambient.set_simulation_active(true)
	var runtime_updates_before: int = ambient.get_update_count()
	await timer.timeout
	check.call(ambient.get_update_count() == runtime_updates_before + 1, "runtime timer advances exactly one ambient update per timeout")
	ambient.notify_sound_event(Vector3(1.0, 0.0, 0.0), 4.0, "gang_a")
	check.call(ambient.status == AmbientAgent.AmbientStatus.ALERT and ambient.has_sound_position, "hostile sound raises a readable alert and stores only the heard position")
	var status_label: Label3D = ambient.get_node("AmbientStatus") as Label3D
	check.call(status_label != null and status_label.text.contains("ALERT"), "ambient actor displays its alert state in-world")
	ambient.debug_enabled = true
	ambient.tick(0.5)
	check.call(status_label.text.contains("UPDATES"), "ambient debug switch exposes the bounded update counter")
	factions.set_faction_standing("gang_a", 50)
	ambient.notify_sound_event(Vector3(2.0, 0.0, 0.0), 4.0, "gang_a")
	check.call(ambient.status == AmbientAgent.AmbientStatus.DISTRACTED, "live faction change turns the same sound source into a distraction")
	ambient.notify_sound_event(Vector3(20.0, 0.0, 0.0), 1.0, "gang_a")
	check.call(ambient.status == AmbientAgent.AmbientStatus.DISTRACTED, "out-of-range sound does not replace a current ambient alert state")
	root.queue_free()
	await tree.process_frame


func _test_seam_encounter_and_crowd_unload(check: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var fixture: Node3D = (load(FIXTURE_PATH) as PackedScene).instantiate() as Node3D
	fixture.set("auto_run", false)
	fixture.set("cleanup_after_run", true)
	tree.root.add_child(fixture)
	await tree.process_frame
	await fixture.call("run", check)
	check.call(fixture.call("get_active_ambient_count") == 0, "encounter fixture leaves no ambient actors after streamed-area teardown")
	check.call(fixture.call("get_populated_area_ids") == ["district_a", "district_b"], "fixture records configured faction populations on each side of the seam")
	var debug_key: InputEventKey = InputEventKey.new()
	debug_key.pressed = true
	debug_key.keycode = KEY_F3
	fixture.call("_unhandled_key_input", debug_key)
	var readout: Label = fixture.get_node("EncounterHUD/EncounterReadout") as Label
	check.call(readout.text.contains("DEBUG ON"), "F3 debug switch shows active and peak ambient counts")
	fixture.queue_free()
	await tree.process_frame
