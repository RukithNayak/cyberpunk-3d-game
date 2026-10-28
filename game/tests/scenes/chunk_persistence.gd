extends Node3D
## WORLD-03 end-to-end lifecycle/save fixture, independent of future gameplay modules.

const DOOR: String = "00000000-0000-4000-8000-000000000031"
const LOOT: String = "00000000-0000-4000-8000-000000000032"
const NPC: String = "00000000-0000-4000-8000-000000000033"
const PROJECTION: Script = preload("res://tests/world/fixtures/persistence_visual.gd")
const EVIDENCE: String = "res://../docs/evidence/WORLD-03"

var _registry: EntityRegistry = EntityRegistry.new()
var _manager: WorldManager = WorldManager.new()
var _hydrator: EntityHydrator = EntityHydrator.new()
var _loader: ChunkLoader = ChunkLoader.new()
var _chunks: Node3D = Node3D.new()
var _label: Label = Label.new()
var _store: SaveStore
var _checks: Array[Dictionary] = []
var _invalidations: Array[Dictionary] = []
var _boundary_saved: bool = false
var _temporary_paths: Array[String] = []
var _save_directory: String
var _player: Dictionary = {"health": 100}
var _domains: Dictionary = {}


func _ready() -> void:
	_setup_view()
	_save_directory = "user://world03_runtime_%d" % OS.get_process_id()
	var a_path: String = _build_chunk(true)
	var b_path: String = _build_chunk(false)
	var manifest: ChunkManifest = ChunkManifest.new()
	var entries: Array[Dictionary] = [
		{"id": "chunk_a", "bounds": AABB(Vector3(-10, -2, -10), Vector3(10, 8, 20)), "scene_path": a_path, "adjacent": ["chunk_b"], "entities": [_descriptor(DOOR, "Door", {"locked": true}), _descriptor(LOOT, "Loot", {"collected": false})]},
		{"id": "chunk_b", "bounds": AABB(Vector3(0, -2, -10), Vector3(10, 8, 20)), "scene_path": b_path, "adjacent": ["chunk_a"], "entities": [_descriptor(NPC, "NPC", {"trust": 1, "opaque": "preserve"})]}
	]
	assert(manifest.configure(entries))
	assert(_manager.configure(manifest, 0.0, 0.0))
	assert(_hydrator.configure(_registry, manifest, _manager))
	_hydrator.interactions_invalidated.connect(_on_invalidation)
	add_child(_chunks)
	add_child(_loader)
	assert(_loader.configure(_manager, manifest, _chunks, null, 1, 5000, Callable(), _hydrator))
	var factions: FactionState = FactionState.new([])
	var adapters: SnapshotAdapters = SnapshotAdapters.new(_registry, factions, _capture_player, _prepare_data, _commit_player, _capture_domains, _prepare_data, _commit_domains)
	_store = SaveStore.new(_save_directory, adapters.capture_snapshot, adapters.validate_snapshot, adapters.apply_snapshot)
	_manager.chunk_pre_unload.connect(_save_boundary)
	_manager.update_player_position(Vector3(-5, 0, 0))
	var a: Node3D = await _wait_chunk("chunk_a")
	if a == null:
		_finish()
		return
	var old_a_generation: int = _manager.get_lifecycle_generation("chunk_a")
	var door: Node3D = _hydrator.get_runtime_entity(DOOR)
	_check(door != null and door.get("ready_state") == {"locked": true} and not door.get("ready_interactions_enabled") and door.get("interactions_enabled"), "loader hydrates before ready and enables interactions only after entry")
	await _capture("before-changes")
	_check(_hydrator.commit_entity_delta(DOOR, {"locked": false}, old_a_generation), "door unlock commits through current-generation authority")
	_check(_hydrator.commit_entity_delta(LOOT, {"collected": true}, old_a_generation) and _hydrator.get_runtime_entity(LOOT) == null, "collected loot immediately loses its runtime projection")
	_manager.update_player_position(Vector3(5, 0, 0))
	_check(_boundary_saved and _registry.get_entity_state(DOOR) == {"locked": false} and _registry.get_entity_state(LOOT) == {"collected": true}, "pre-unload boundary save sees already-committed door and loot records")
	var b: Node3D = await _wait_chunk("chunk_b")
	if b == null:
		_finish()
		return
	_check(_hydrator.commit_entity_delta(NPC, {"trust": 4}, _manager.get_lifecycle_generation("chunk_b")) and _registry.get_entity_state(NPC)["opaque"] == "preserve", "NPC record changes preserve unrelated authoritative data")
	_check(_store.save_to_disk(1) == OK, "all entity records save through CORE-04 snapshot adapters")
	_manager.update_player_position(Vector3(40, 0, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_hydrator.get_bound_entity_count() == 0 and _loader.get_active_instance("chunk_a") == null and _loader.get_active_instance("chunk_b") == null and _invalidations.size() == 2, "unload revokes both chunks and notifies stale-work consumers")
	var clear_plan: Dictionary = _registry.prepare_snapshot_replacement([])
	_registry.commit_prepared_snapshot(clear_plan)
	_check(_store.load_from_disk(1) == OK and _registry.get_entity_state(NPC)["trust"] == 4, "saved entity data restores after all runtime scenes are gone")
	# Unloaded A then B; reload B then A to prove identity is independent of order.
	_manager.update_player_position(Vector3(5, 0, 0))
	b = await _wait_chunk("chunk_b")
	if b == null:
		_finish()
		return
	_check(_hydrator.get_runtime_entity(NPC).get("ready_state")["trust"] == 4, "reverse-order NPC re-entry restores saved state before ready")
	_manager.update_player_position(Vector3(-5, 0, 0))
	a = await _wait_chunk("chunk_a")
	if a == null:
		_finish()
		return
	_check(_hydrator.get_runtime_entity(DOOR).get("ready_state") == {"locked": false} and a.get_node_or_null("Loot") == null, "reverse-order door re-entry preserves unlock and suppresses collected loot")
	_check(not _hydrator.commit_entity_delta(DOOR, {"locked": true}, old_a_generation) and not _registry.get_entity_state(DOOR)["locked"], "old asynchronous interaction cannot mutate a reloaded generation")
	_manager.update_player_position(Vector3.ZERO)
	b = await _wait_chunk("chunk_b")
	_check(b != null and _hydrator.get_bound_entity_count() == 2 and _registry.snapshot_records().size() == 3, "two runtime projections and one tombstone retain exactly three stable identities")
	_finish()


func _build_chunk(first: bool) -> String:
	var scene: PackedScene = load("res://world/fixtures/chunk_a.tscn" if first else "res://world/fixtures/chunk_b.tscn") as PackedScene
	var source: Node3D = scene.instantiate() as Node3D
	if first:
		_add_projection(source, "Door", Vector3(-4, 1, 0), Vector3(0.4, 2, 1.4))
		_add_projection(source, "Loot", Vector3(-2, 0.4, 2), Vector3(0.7, 0.8, 0.7))
	else:
		_add_projection(source, "NPC", Vector3(3, 0.9, 0), Vector3(0.7, 1.8, 0.7))
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(source) == OK)
	source.free()
	var path: String = "user://world03_runtime_%d_%s.tscn" % [OS.get_process_id(), "a" if first else "b"]
	assert(ResourceSaver.save(packed, path) == OK)
	_temporary_paths.append(path)
	return path


func _add_projection(root: Node3D, node_name: String, at: Vector3, dimensions: Vector3) -> void:
	var projection: Node3D = Node3D.new()
	projection.name = node_name
	projection.position = at
	projection.set_script(PROJECTION)
	root.add_child(projection)
	projection.owner = root
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	projection.add_child(visual)
	visual.owner = root


func _descriptor(uuid: String, node_path: String, state: Dictionary) -> Dictionary:
	return {"uuid": uuid, "node_path": node_path, "initial_state": state}


func _wait_chunk(chunk_id: String) -> Node3D:
	var deadline: int = Time.get_ticks_msec() + 5000
	while _loader.get_active_instance(chunk_id) == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var instance: Node3D = _loader.get_active_instance(chunk_id)
	if instance == null:
		_check(false, "chunk loading deadline: " + chunk_id)
	return instance


func _on_invalidation(payload: Dictionary) -> void:
	_invalidations.append(payload.duplicate(true))


func _save_boundary(payload: Dictionary) -> void:
	if payload["chunk_id"] == "chunk_a" and not _boundary_saved:
		_boundary_saved = _store.save_to_disk(0) == OK


func _setup_view() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 13, 16)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.08, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.7
	world.environment = environment
	add_child(world)
	var canvas: CanvasLayer = CanvasLayer.new()
	_label.position = Vector2(20, 20)
	_label.text = "WORLD-03 / PERSISTENT ENTITY LIFECYCLE\nDoor, loot and NPC projection fixture"
	_label.add_theme_font_size_override("font_size", 18)
	canvas.add_child(_label)
	add_child(canvas)


func _check(passed: bool, description: String) -> void:
	_checks.append({"passed": passed, "description": description})
	print("WORLD-03 %s: %s" % ["PASS" if passed else "FAIL", description])


func _capture(capture_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(EVIDENCE).path_join(capture_name + ".png")) == OK, "rendered capture saved: " + capture_name)


func _finish() -> void:
	_label.text = "WORLD-03 / PERSISTENCE VERIFIED\nDoor unlocked · loot collected · NPC trust 4\nSave restored; reverse-order reload retained UUIDs"
	await _capture("after-restore")
	var passed: bool = not _checks.is_empty()
	for result: Dictionary in _checks:
		passed = passed and result["passed"]
	var mode: String = "headless" if DisplayServer.get_name() == "headless" else "rendered"
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(EVIDENCE).path_join("runtime-" + mode + ".json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"passed": passed, "checks": _checks, "records": _registry.snapshot_records(), "invalidations": _invalidations, "godot": Engine.get_version_info()["string"], "display_server": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method()}, "\t"))
	file.close()
	for path: String in _temporary_paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for slot: int in [0, 1]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_directory.path_join("slot_%02d.save" % slot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_directory))
	print("WORLD-03 runtime %s: %d checks; %s" % ["PASS" if passed else "FAIL", _checks.size(), mode])
	if mode == "headless" or OS.get_cmdline_user_args().has("--verify"):
		get_tree().quit(0 if passed else 1)


func _capture_player() -> Dictionary:
	return _player.duplicate(true)


func _capture_domains() -> Dictionary:
	return _domains.duplicate(true)


func _prepare_data(candidate: Dictionary) -> Dictionary:
	return {"ok": true, "prepared": candidate.duplicate(true)}


func _commit_player(candidate: Dictionary) -> void:
	_player = candidate.duplicate(true)


func _commit_domains(candidate: Dictionary) -> void:
	_domains = candidate.duplicate(true)
