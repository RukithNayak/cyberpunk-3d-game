extends RefCounted

const MANIFEST_PATH: String = "res://world/chunk_manifest.gd"
const MANAGER_PATH: String = "res://world/world_manager.gd"


func run(check: Callable) -> void:
	var manifest_script: Script = load(MANIFEST_PATH) as Script
	check.call(manifest_script != null, "chunk manifest script is available")
	if manifest_script == null:
		return
	var manager_script: Script = load(MANAGER_PATH) as Script
	check.call(manager_script != null, "world manager script is available")
	if manager_script == null:
		return
	var manifest: Object = manifest_script.new()
	check.call(manifest.has_method("configure") and manifest.has_method("get_chunk_ids"), "manifest exposes validated setup and IDs")
	if not manifest.has_method("configure") or not manifest.has_method("get_chunk_ids"):
		return
	var entries: Array[Dictionary] = [
		{"id": "chunk_a", "bounds": AABB(Vector3(-10.0, -2.0, -10.0), Vector3(10.0, 8.0, 20.0)), "scene_path": "res://world/fixtures/chunk_a.tscn", "adjacent": ["chunk_b"]},
		{"id": "chunk_b", "bounds": AABB(Vector3(0.0, -2.0, -10.0), Vector3(10.0, 8.0, 20.0)), "scene_path": "res://world/fixtures/chunk_b.tscn", "adjacent": ["chunk_a"]}
	]
	check.call(not manifest.call("configure", [{"id": "../bad", "bounds": AABB(), "scene_path": "res://world/fixtures/chunk_a.tscn", "adjacent": []}]), "malformed chunk IDs are rejected")
	check.call(not manifest.call("configure", [entries[0], entries[0].duplicate(true)]), "duplicate chunk IDs are rejected")
	check.call(not manifest.call("configure", [{"id": "missing_neighbor", "bounds": AABB(Vector3.ZERO, Vector3.ONE), "scene_path": "res://world/fixtures/chunk_a.tscn", "adjacent": ["unknown"]}]), "unknown adjacent chunk IDs are rejected")
	var asymmetric: Array[Dictionary] = [entries[0].duplicate(true), entries[1].duplicate(true)]
	asymmetric[1]["adjacent"] = []
	check.call(not manifest.call("configure", asymmetric), "asymmetric adjacency is rejected")
	var bad_resource: Array[Dictionary] = [entries[0].duplicate(true), entries[1].duplicate(true)]
	bad_resource[1]["scene_path"] = "res://world/fixtures/not_a_chunk.tscn"
	check.call(not manifest.call("configure", bad_resource), "missing chunk scenes are rejected")
	var wrong_root: Array[Dictionary] = [entries[0].duplicate(true), entries[1].duplicate(true)]
	wrong_root[1]["scene_path"] = "res://tests/scenes/startup.tscn"
	check.call(not manifest.call("configure", wrong_root), "non-3D chunk scenes are rejected")
	var derived_root: CharacterBody3D = CharacterBody3D.new()
	var derived_scene: PackedScene = PackedScene.new()
	derived_scene.pack(derived_root)
	derived_root.free()
	var derived_path: String = "user://world_manifest_character_body_test.tscn"
	ResourceSaver.save(derived_scene, derived_path)
	var derived_record: Array[Dictionary] = [entries[0].duplicate(true), entries[1].duplicate(true)]
	derived_record[1]["scene_path"] = derived_path
	var derived_manifest: Object = manifest_script.new()
	check.call(derived_manifest.call("configure", derived_record), "Node3D-derived chunk root types are accepted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(derived_path))
	var invalid_bounds: Array[Dictionary] = [entries[0].duplicate(true), entries[1].duplicate(true)]
	invalid_bounds[1]["bounds"] = AABB(Vector3.ZERO, Vector3(-1.0, 2.0, 2.0))
	check.call(not manifest.call("configure", invalid_bounds), "non-positive chunk bounds are rejected")
	check.call(manifest.call("configure", entries), "valid symmetric manifest is accepted")
	check.call(not manifest.call("configure", entries), "configured manifest rejects later replacement")
	check.call(manifest.call("get_chunk_ids") == ["chunk_a", "chunk_b"], "manifest preserves configured chunk IDs")
	var chunk_a_scene: PackedScene = load("res://world/fixtures/chunk_a.tscn") as PackedScene
	var chunk_b_scene: PackedScene = load("res://world/fixtures/chunk_b.tscn") as PackedScene
	check.call(chunk_a_scene != null and chunk_b_scene != null, "both greybox chunk fixtures load as scenes")
	if chunk_a_scene != null and chunk_b_scene != null:
		var chunk_a: Node3D = chunk_a_scene.instantiate() as Node3D
		var chunk_b: Node3D = chunk_b_scene.instantiate() as Node3D
		var a_ground: StaticBody3D = chunk_a.get_node("Ground") as StaticBody3D
		var b_ground: StaticBody3D = chunk_b.get_node("Ground") as StaticBody3D
		check.call(a_ground.position.x + 5.0 == b_ground.position.x - 5.0, "walkable floor collision bounds meet at the seam")
		check.call(is_equal_approx(chunk_a.get_node("FirstPersonSeamView").position.y, 1.7) and is_equal_approx(chunk_b.get_node("FirstPersonSeamView").position.y, 1.7), "fixtures define first-person-height seam viewpoints")
		chunk_a.free()
		chunk_b.free()

	var manager: Object = manager_script.new()
	check.call(manager.has_method("configure") and manager.has_method("update_player_position") and manager.has_method("get_desired_chunk_ids"), "manager exposes desired lifecycle updates")
	if not manager.has_method("configure") or not manager.has_method("update_player_position") or not manager.has_method("get_desired_chunk_ids"):
		return
	manager.call("configure", manifest, 2.0, 1.0)
	var manager_generation_before_reconfigure: int = manager.call("get_lifecycle_generation", "chunk_a")
	check.call(not manager.call("configure", manifest, 2.0, 1.0), "configured manager rejects replacement")
	check.call(manager.call("get_lifecycle_generation", "chunk_a") == manager_generation_before_reconfigure, "rejected manager replacement preserves generations")
	manager.call("update_player_position", Vector3(-1.0, 0.0, 0.0))
	check.call(manager.call("get_desired_chunk_ids") == ["chunk_a", "chunk_b"], "preload margin selects both chunks near seam")
	var activation_payloads: Array[Dictionary] = []
	var pre_unload_payloads: Array[Dictionary] = []
	var deactivation_payloads: Array[Dictionary] = []
	var pre_unload_observations: Array[Dictionary] = []
	manager.connect("chunk_activated", func(payload: Dictionary) -> void: activation_payloads.append(payload))
	manager.connect("chunk_pre_unload", func(payload: Dictionary) -> void: pre_unload_payloads.append(payload))
	manager.connect("chunk_deactivated", func(payload: Dictionary) -> void: deactivation_payloads.append(payload))
	var observation_callback: Callable = func(payload: Dictionary) -> void:
		pre_unload_observations.append({
			"payload": payload.duplicate(true),
			"desired": manager.call("get_desired_chunk_ids"),
			"generation": manager.call("get_lifecycle_generation", payload["chunk_id"])
		})
	manager.connect("chunk_pre_unload", observation_callback)
	var chunk_a_generation: int = manager.call("get_lifecycle_generation", "chunk_a")
	check.call(manager.call("acknowledge_activated", "chunk_a", chunk_a_generation), "current preload generation can be acknowledged as active")
	check.call(activation_payloads.size() == 1 and activation_payloads[0] == {"chunk_id": "chunk_a", "lifecycle_generation": chunk_a_generation}, "activation event publishes chunk ID and generation")
	manager.call("update_player_position", Vector3(-0.25, 0.0, 0.0))
	check.call(manager.call("get_desired_chunk_ids") == ["chunk_a", "chunk_b"], "rapid seam recrossing does not flicker desired chunks")
	manager.call("update_player_position", Vector3(12.5, 0.0, 0.0))
	check.call(manager.call("get_desired_chunk_ids") == ["chunk_b"], "departed chunk exits preload range while neighbor stays desired")
	check.call(pre_unload_observations.size() == 1 and pre_unload_observations[0]["generation"] == pre_unload_observations[0]["payload"]["lifecycle_generation"] and not pre_unload_observations[0]["desired"].has("chunk_a"), "pre-unload listeners observe committed generation and desired set")
	var first_retired_generation: int = manager.call("get_lifecycle_generation", "chunk_a")
	manager.call("update_player_position", Vector3(12.2, 0.0, 0.0))
	check.call(manager.call("get_desired_chunk_ids") == ["chunk_b"], "hysteresis keeps chunk desired on boundary recrossing")
	manager.call("update_player_position", Vector3(1.0, 0.0, 0.0))
	var reentered_generation: int = manager.call("get_lifecycle_generation", "chunk_a")
	check.call(reentered_generation > first_retired_generation and manager.call("get_load_state", "chunk_a") == 1, "re-entering during pending teardown starts a new preload generation")
	check.call(not manager.call("acknowledge_deactivated", "chunk_a", first_retired_generation), "prior teardown acknowledgement is stale after re-entry")
	check.call(manager.call("acknowledge_activated", "chunk_a", reentered_generation), "new re-entry generation can be acknowledged as active")
	manager.call("update_player_position", Vector3(13.1, 0.0, 0.0))
	manager.call("update_player_position", Vector3(30.0, 0.0, 0.0))
	check.call(manager.call("get_desired_chunk_ids").is_empty(), "chunks leave desired set beyond preload and hysteresis margins")
	check.call(manager.has_method("acknowledge_activated") and manager.has_method("acknowledge_deactivated"), "manager exposes generation-tagged lifecycle acknowledgements")
	check.call(pre_unload_payloads.size() >= 3 and pre_unload_payloads[0].has("chunk_id") and pre_unload_payloads[0].has("lifecycle_generation"), "pre-unload event publishes IDs and lifecycle generations")
	var retired_generation: int = manager.call("get_lifecycle_generation", "chunk_a")
	check.call(not manager.call("acknowledge_deactivated", "chunk_a", reentered_generation), "stale lifecycle generation cannot acknowledge deactivation")
	check.call(manager.call("acknowledge_deactivated", "chunk_a", retired_generation), "current retired generation can acknowledge deactivation")
	check.call(manager.call("get_load_state", "chunk_a") == 0, "deactivation returns lifecycle state to unloaded")
	check.call(deactivation_payloads.size() == 1 and deactivation_payloads[0] == {"chunk_id": "chunk_a", "lifecycle_generation": retired_generation}, "deactivation event publishes chunk ID and generation")
	manager.disconnect("chunk_pre_unload", observation_callback)
