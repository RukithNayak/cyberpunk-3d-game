extends RefCounted

const SNAPSHOT_PATH: String = "res://features/hacking/hack_snapshot.gd"
const HUD_PATH: String = "res://ui/hacking_hud.gd"
const CAMERA_PATH: String = "res://features/hacking/targets/hackable_camera.gd"
const TARGET_UUID: String = "123e4567-e89b-42d3-a456-426614174030"
const CHUNK_ID: String = "hack_room"
const SAVE_DIRECTORY: String = "user://hacking_effect_tests"


func run(check: Callable) -> void:
	var snapshot_script: Script = load(SNAPSHOT_PATH) as Script
	var hud_script: Script = load(HUD_PATH) as Script
	var camera_script: Script = load(CAMERA_PATH) as Script
	check.call(snapshot_script != null, "HACK-05 data-only timed effect snapshot is available")
	check.call(hud_script != null, "HACK-05 hacking HUD is available")
	check.call(camera_script != null, "HACK-05 camera target can restore an active effect")
	if snapshot_script != null and camera_script != null:
		await _test_effect_roundtrip_and_lifecycle(check, snapshot_script, camera_script)
	if hud_script != null:
		await _test_hud_feedback(check, hud_script)


func _test_effect_roundtrip_and_lifecycle(check: Callable, snapshot_script: Script, camera_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var manifest: ChunkManifest = ChunkManifest.new()
	check.call(manifest.configure([{
		"id": CHUNK_ID,
		"bounds": AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 4.0, 8.0)),
		"scene_path": "res://world/fixtures/chunk_a.tscn",
		"adjacent": [],
		"entities": [],
	}]), "timed hack fixture has a valid streamed chunk")
	var manager: WorldManager = WorldManager.new()
	check.call(manager.configure(manifest, 0.0, 0.0), "timed hack fixture configures WORLD-01 lifecycle authority")
	var snapshot: RefCounted = snapshot_script.new() as RefCounted
	check.call(bool(snapshot.call("configure", manager)), "hack snapshot binds lifecycle activation and unload events")
	manager.update_player_position(Vector3.ZERO)
	check.call(manager.acknowledge_activated(CHUNK_ID, manager.get_lifecycle_generation(CHUNK_ID)), "hack room becomes active")
	var camera: StaticBody3D = camera_script.new() as StaticBody3D
	camera.set("persistent_uuid", TARGET_UUID)
	camera.set("chunk_id", CHUNK_ID)
	camera.position = Vector3(0.0, 1.0, -4.0)
	tree.root.add_child(camera)
	await tree.physics_frame
	check.call(bool(snapshot.call("register_target", camera, CHUNK_ID)), "hydrated camera registers by stable ID and owning chunk")
	var operator: Node3D = Node3D.new()
	tree.root.add_child(operator)
	var state: HackingState = HackingState.new()
	state.configure(100.0, 0.0, 100.0)
	var service: HackingService = HackingService.new()
	check.call(bool(service.call("configure", operator, state, service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true, snapshot)), "hacking service accepts the optional persistent effect owner")
	var status: Dictionary = service.call("get_target_status", camera, HackDefinition.Ability.DISABLE_CAMERA)
	check.call(status.get("valid", false) and is_equal_approx(float(status.get("cost", -1.0)), 20.0) and is_equal_approx(float(status.get("duration", -1.0)), 8.0), "HUD status query exposes eligible target cost and duration without mutation")
	var hud_scene: PackedScene = load("res://ui/hacking_hud.tscn") as PackedScene
	var hud: Control = hud_scene.instantiate() as Control if hud_scene != null else null
	check.call(hud != null, "hacking HUD has an instantiable reusable scene")
	if hud != null:
		tree.root.add_child(hud)
		await tree.process_frame
		hud.call("configure", service)
		hud.call("present_target", camera, HackDefinition.Ability.DISABLE_CAMERA)
		check.call(String(hud.call("get_status_text")).contains("READY") and String(hud.call("get_detail_text")).contains("COST 20") and String(hud.call("get_detail_text")).contains("DUR 08.0"), "HUD shows target readiness, cost, cooldown, and duration")
	check.call(service.request_hack(camera, HackDefinition.Ability.DISABLE_CAMERA), "camera hack commits through the snapshot owner")
	if hud != null:
		check.call(String(hud.call("get_status_text")).contains("LINK ESTABLISHED"), "HUD presents committed hack feedback")
	check.call(not service.request_hack(camera, HackDefinition.Ability.DISABLE_CAMERA), "active camera effect rejects a repeated hack")
	if hud != null:
		check.call(String(hud.call("get_status_text")).contains("ACCESS DENIED"), "HUD presents authoritative rejection feedback")
	service.tick_energy_regen(2.0)
	var saved: Dictionary = snapshot.call("capture_domain")
	check.call(saved.get("active_hacks", []).size() == 1 and is_equal_approx(float(saved.active_hacks[0].get("remaining_seconds", 0.0)), 6.0), "save captures the remaining active simulation duration as data")
	check.call(not _contains_object(saved), "persisted hack domain contains no Nodes or engine Objects")
	var save_store: SaveStore = _create_save_store(snapshot, true)
	check.call(save_store.save_to_disk(3) == OK, "active hack remainder saves through CORE-04 SaveStore")
	var misrouted_snapshot: RefCounted = snapshot_script.new() as RefCounted
	misrouted_snapshot.call("configure", manager)
	var misrouted_data: Dictionary = saved.duplicate(true)
	misrouted_data.active_hacks[0].chunk_id = "other_room"
	var misrouted_prepared: Dictionary = misrouted_snapshot.call("prepare_domain", misrouted_data)
	misrouted_snapshot.call("commit_domain", misrouted_prepared)
	var wrong_projection: StaticBody3D = camera_script.new() as StaticBody3D
	wrong_projection.set("persistent_uuid", TARGET_UUID)
	wrong_projection.set("chunk_id", "different_room")
	tree.root.add_child(wrong_projection)
	await tree.physics_frame
	check.call(not bool(misrouted_snapshot.call("register_target", wrong_projection, "different_room")) and is_zero_approx(float(misrouted_snapshot.call("get_remaining_seconds", TARGET_UUID, HackDefinition.Ability.DISABLE_CAMERA))) and bool(wrong_projection.get("detection_enabled")), "mismatched chunk projection drops the delayed effect without applying it")
	tree.root.remove_child(wrong_projection)
	wrong_projection.free()
	var empty_prepared: Dictionary = snapshot.call("prepare_domain", {"active_hacks": []})
	snapshot.call("commit_domain", empty_prepared)
	service.tick_energy_regen(0.0)
	check.call(bool(camera.get("detection_enabled")), "loaded snapshot removal clears the matching live effect on the next simulation tick")
	check.call(save_store.load_from_disk(3) == OK, "saved effect reloads into the same active snapshot owner")
	service.tick_energy_regen(0.0)
	check.call(not bool(camera.get("detection_enabled")) and is_equal_approx(float(snapshot.call("get_remaining_seconds", TARGET_UUID, HackDefinition.Ability.DISABLE_CAMERA)), 6.0), "same-chunk load reapplies the effect without retaining stale save-time truth")
	manager.update_player_position(Vector3(30.0, 0.0, 0.0))
	manager.acknowledge_deactivated(CHUNK_ID, manager.get_lifecycle_generation(CHUNK_ID))
	service.tick_energy_regen(5.0)
	check.call(manager.get_load_state(CHUNK_ID) == WorldManager.LoadState.UNLOADED and is_equal_approx(float(snapshot.call("get_remaining_seconds", TARGET_UUID, HackDefinition.Ability.DISABLE_CAMERA)), 6.0), "effect time pauses as soon as WORLD-01 announces chunk unload")
	tree.root.remove_child(camera)
	camera.free()
	var restored: RefCounted = snapshot_script.new() as RefCounted
	check.call(bool(restored.call("configure", manager)), "fresh snapshot owner binds to WORLD-01 lifecycle events")
	var load_store: SaveStore = _create_save_store(restored, false)
	check.call(load_store.load_from_disk(3) == OK and is_equal_approx(float(restored.call("get_remaining_seconds", TARGET_UUID, HackDefinition.Ability.DISABLE_CAMERA)), 6.0), "fresh snapshot owner loads the effect remainder through CORE-04 SaveStore")
	manager.update_player_position(Vector3.ZERO)
	manager.acknowledge_activated(CHUNK_ID, manager.get_lifecycle_generation(CHUNK_ID))
	var rehydrated: StaticBody3D = camera_script.new() as StaticBody3D
	rehydrated.set("persistent_uuid", TARGET_UUID)
	rehydrated.set("chunk_id", CHUNK_ID)
	rehydrated.position = Vector3(0.0, 1.0, -4.0)
	tree.root.add_child(rehydrated)
	await tree.physics_frame
	check.call(bool(restored.call("register_target", rehydrated, CHUNK_ID)) and not bool(rehydrated.get("detection_enabled")), "fresh projection resumes the saved camera effect without stale target references")
	restored.call("advance_active_time", 6.0)
	check.call(is_equal_approx(float(restored.call("get_remaining_seconds", TARGET_UUID, HackDefinition.Ability.DISABLE_CAMERA)), 0.0) and bool(rehydrated.get("detection_enabled")), "restored effect expires after its remaining active time")
	tree.root.remove_child(rehydrated)
	tree.root.remove_child(operator)
	if hud != null:
		tree.root.remove_child(hud)
		hud.free()
	rehydrated.free()
	operator.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY.path_join("slot_03.save")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	await tree.process_frame


func _test_hud_feedback(check: Callable, hud_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var hud: Control = hud_script.new() as Control
	tree.root.add_child(hud)
	await tree.process_frame
	hud.call("configure", null)
	check.call(String(hud.call("get_status_text")).contains("OFFLINE"), "HUD visibly reports an unavailable hacking provider")
	tree.root.remove_child(hud)
	hud.free()
	await tree.process_frame


func _create_save_store(snapshot: RefCounted, with_provider: bool) -> SaveStore:
	var provider: Callable = func() -> Dictionary:
		return {"player": {}, "entities": [], "factions": {}, "domains": {"active_hacks": snapshot.call("capture_domain")}}
	var validator: Callable = func(candidate: Dictionary) -> bool:
		if typeof(candidate.get("domains")) != TYPE_DICTIONARY:
			return false
		return bool(snapshot.call("prepare_domain", candidate["domains"].get("active_hacks", {})).get("ok", false))
	var apply: Callable = func(candidate: Dictionary) -> bool:
		var prepared: Dictionary = snapshot.call("prepare_domain", candidate["domains"].get("active_hacks", {}))
		return bool(snapshot.call("commit_domain", prepared))
	return SaveStore.new(SAVE_DIRECTORY, provider if with_provider else Callable(), validator, apply)


func _contains_object(value: Variant) -> bool:
	if value is Node or value is Object and not value is Resource:
		return true
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value:
			if _contains_object(key) or _contains_object(value[key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			if _contains_object(item):
				return true
	return false
