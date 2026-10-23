extends Node3D
## WORLD-06 integration fixture. Composes accepted module services without transferring ownership.

const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const CHUNK_A: String = "res://world/fixtures/chunk_a.tscn"
const CHUNK_B: String = "res://world/fixtures/chunk_b.tscn"
const UI_DIALOGUE_SCENE: PackedScene = preload("res://ui/dialogue_ui.tscn")
const CACHE_UUID: String = "00000000-0000-4000-8000-000000000032"
const PLAYER_UUID: String = "00000000-0000-4000-8000-000000000001"
const DOOR_UUID: String = "81000000-0000-4000-8000-000000000002"
const NPC_ID: String = "mara_vega"
const CONVERSATION_ID: String = "world06_mara_session"
const MODEL_NAME: String = "llama3:willowbrook"
const MODEL_ENDPOINT: String = "http://127.0.0.1:11434"
const BENCHMARK_DIR: String = "res://../benchmarks/feasibility"
const SAVE_DIRECTORY: String = "user://world06_feasibility"
const SAMPLE_INTERVAL_SECONDS: float = 0.5
const MAX_WAIT_SECONDS: float = 12.0
const BENCHMARK_BASELINE_SECONDS: float = 30.0
const BENCHMARK_CONCURRENT_SECONDS: float = 60.0
const BENCHMARK_REQUEST_PAUSE_SECONDS: float = 0.6
const BENCHMARK_CROSS_EVERY_REQUESTS: int = 4

var player: PlayerController
var health: HealthState
var weapon: WeaponController
var actions: WeaponStateMachine
var inventory: GridInventory
var ammo: AmmoPouch
var grants: ItemGrants
var equipment: EquipmentService
var definitions: Dictionary = {}
var inventory_snapshot: InventorySnapshot
var player_snapshot: PlayerSnapshot
var dialogue_snapshot: DialogueSnapshot
var checkpoint: Node
var save_store: SaveStore
var registry: EntityRegistry
var factions: FactionState
var missions: MissionDirector
var npc_memory: NpcMemory
var mara_actor: Node3D
var dialogue_ui: DialogueUI
var dialogue_orchestrator: DialogueOrchestrator
var cancellation_orchestrator: DialogueOrchestrator
var cancellation_provider: MockDialogueProvider
var ollama_provider: OllamaProvider
var hacking_service: HackingService
var hacking_state: HackingState
var entity_hydrator: EntityHydrator
var door_manager: WorldManager
var door_manifest: ChunkManifest
var door_projection_root: Node3D
var service_door: HackableDoor
var door_generation: int = -1
var cache_drop: Node3D
var cache_item: ItemInstance
var loot_item: ItemInstance
var mission_id: String = ""
var goon: TacticalAgent
var _city_manager: WorldManager
var _city_loader: ChunkLoader
var _active_chunks: Node3D
var _checks: Array[Dictionary] = []
var _frame_intervals_ms: Array[float] = []
var _process_times_ms: Array[float] = []
var _physics_times_ms: Array[float] = []
var _draw_calls: Array[float] = []
var _static_memory_bytes: Array[float] = []
var _last_sample_usec: int = 0
var _started_usec: int = 0
var _last_model_request_usec: int = 0
var _model_request_ms: float = -1.0
var _model_used_fallback: bool = false
var _model_response_received: bool = false
var _model_dialogue_count: int = 0
var _model_fallback_count: int = 0
var _model_latency_samples_ms: Array[float] = []
var _last_model_fallback: bool = false
var _cancel_probe_response_count: int = 0
var _offline_fallback_received: bool = false
var _offline_used_fallback: bool = false
var _dialogue_cancel_distance: float = 6.5
var _benchmark_mode: bool = false
var _headless_smoke: bool = false
var _relaunch_check: bool = false
var _setup_error: String = ""


func _ready() -> void:
	_headless_smoke = DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().has("--smoke")
	_relaunch_check = OS.get_cmdline_user_args().has("--relaunch-check")
	_benchmark_mode = OS.get_cmdline_user_args().has("--benchmark")
	if _headless_smoke:
		_reset_headless_fixture_save()
	_started_usec = Time.get_ticks_usec()
	_last_sample_usec = _started_usec
	_build_presentation()
	_build_city_streaming()
	_build_player_and_combat()
	_build_world_records()
	_build_loot()
	_build_enemy()
	_build_hacking()
	_build_checkpoint()
	_build_dialogue()
	_finish_services()
	set_process(true)
	set_physics_process(true)
	call_deferred("_finish_setup")


func _process(delta: float) -> void:
	if player != null and _city_manager != null:
		_city_manager.update_player_position(player.global_position)
	_sync_mara_actor()
	_cancel_invalid_dialogue()
	var frame_ms: float = delta * 1000.0
	_frame_intervals_ms.append(frame_ms)
	var process_seconds: float = Performance.get_monitor(Performance.TIME_PROCESS)
	var physics_seconds: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_process_times_ms.append(process_seconds * 1000.0)
	_physics_times_ms.append(physics_seconds * 1000.0)
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_static_memory_bytes.append(Performance.get_monitor(Performance.MEMORY_STATIC))
	var now_usec: int = Time.get_ticks_usec()
	if now_usec - _last_sample_usec >= int(SAMPLE_INTERVAL_SECONDS * 1000000.0):
		_last_sample_usec = now_usec
		if _frame_intervals_ms.size() > 50000:
			_trim_samples()


func _physics_process(delta: float) -> void:
	if _city_loader != null:
		_city_loader.pump_frame()
	if hacking_service != null:
		hacking_service.tick_energy_regen(delta)
	if goon != null and goon.is_configured() and not _headless_smoke:
		goon.tick(minf(delta, TacticalAgent.MAX_TICK_SECONDS))


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_E:
			_open_dialogue()
		KEY_F:
			_pick_up_loot()
		KEY_H:
			_use_medkit()
		KEY_G:
			_unlock_service_door()
		KEY_F5:
			_save_checkpoint()
		KEY_F9:
			_restore_checkpoint()
		KEY_TAB:
			if inventory_ui != null:
				inventory_ui.toggle_inventory()
	get_viewport().set_input_as_handled()


var inventory_ui: InventoryUI
var _status_label: Label
var _fps_label: Label


func _finish_setup() -> void:
	await get_tree().process_frame
	if not _setup_error.is_empty():
		push_error("WORLD-06 setup failed: " + _setup_error)
		if _headless_smoke or _relaunch_check:
			get_tree().quit(1)
		return
	if _relaunch_check:
		_run_fresh_process_check()
		return
	if _headless_smoke:
		await _run_headless_smoke()
		return
	if _benchmark_mode:
		await _capture_startup()
		await _run_sustained_benchmark()
		return
	if DisplayServer.get_name() != "headless":
		await _capture_startup()
	print("WORLD-06 feasibility ready: walk with WASD, aim/fire with mouse/Enter, E contact, F loot, H heal, G hack, Tab inventory, F5 save, F9 load, Esc pause.")


func _build_presentation() -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111b27")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9bbc9")
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	add_child(environment_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -26.0, 0.0)
	sun.light_energy = 0.75
	add_child(sun)
	var cyan_sign: MeshInstance3D = _build_sign(Vector3(5.5, 3.0, -4.0), Color("00e5ff"), Vector3(3.5, 1.0, 0.18))
	add_child(cyan_sign)
	var amber_sign: MeshInstance3D = _build_sign(Vector3(-7.0, 3.6, 4.5), Color("ffb52e"), Vector3(2.4, 0.8, 0.18))
	add_child(amber_sign)
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 1
	hud_layer.name = "HudLayer"
	add_child(hud_layer)
	var instructions: Label = Label.new()
	instructions.text = "DISTRICT // NIGHT MARKET\nE  CONTACT     F  LOOT     H  HEAL     G  HACK\nTAB  INVENTORY     F5  SAVE     F9  RESTORE     ESC  PAUSE"
	instructions.theme_type_variation = &"CyberpunkAccent"
	instructions.position = Vector2(24.0, 132.0)
	hud_layer.add_child(instructions)
	_status_label = Label.new()
	_status_label.theme_type_variation = &"CyberpunkStatus"
	_status_label.position = Vector2(24.0, 210.0)
	hud_layer.add_child(_status_label)
	_fps_label = Label.new()
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.anchor_left = 0.72
	_fps_label.anchor_right = 0.98
	_fps_label.anchor_top = 0.92
	_fps_label.anchor_bottom = 0.99
	_fps_label.theme_type_variation = &"CyberpunkMuted"
	hud_layer.add_child(_fps_label)


func _build_city_streaming() -> void:
	var manifest: ChunkManifest = ChunkManifest.new()
	var records: Array[Dictionary] = [
		{"id": "district_a", "bounds": AABB(Vector3(-10.0, -2.0, -10.0), Vector3(10.0, 10.0, 20.0)), "scene_path": CHUNK_A, "adjacent": ["district_b"]},
		{"id": "district_b", "bounds": AABB(Vector3(0.0, -2.0, -10.0), Vector3(10.0, 10.0, 20.0)), "scene_path": CHUNK_B, "adjacent": ["district_a"]},
	]
	if not manifest.configure(records):
		_setup_error = "two-district chunk manifest was rejected"
		return
	_city_manager = WorldManager.new()
	if not _city_manager.configure(manifest, 1.0, 2.0):
		_setup_error = "city WorldManager failed configuration"
		return
	_active_chunks = Node3D.new()
	_active_chunks.name = "StreamedCityChunks"
	add_child(_active_chunks)
	_city_loader = ChunkLoader.new()
	_city_loader.name = "CityChunkLoader"
	add_child(_city_loader)
	if not _city_loader.configure(_city_manager, manifest, _active_chunks, null, 1, 15000):
		_setup_error = "threaded city ChunkLoader failed configuration"


func _build_player_and_combat() -> void:
	player = PLAYER_SCENE.instantiate() as PlayerController
	if player == null:
		_setup_error = "player scene could not be instantiated"
		return
	player.name = "FeasibilityPlayer"
	player.position = Vector3(-4.0, 0.0, 0.0)
	player.rotation.y = -PI * 0.5
	player.capture_mouse_on_start = DisplayServer.get_name() != "headless"
	add_child(player)
	weapon = player.get_node("WeaponController") as WeaponController
	actions = player.get_node("WeaponStateMachine") as WeaponStateMachine
	health = HealthState.new(100)
	health.on_death.connect(_cancel_dialogue_on_player_death)
	health.apply_damage(30, "feasibility_setup")
	_create_definitions_and_inventory()
	var consumables: ConsumableService = ConsumableService.new(inventory, definitions, health)
	actions.configure(player, weapon, equipment, consumables, health)
	var hud: PlayerHUD = (load("res://ui/player_hud.tscn") as PackedScene).instantiate() as PlayerHUD
	var hud_layer: CanvasLayer = get_node("HudLayer") as CanvasLayer
	hud_layer.add_child(hud)
	hud.configure(health, actions, equipment, player)
	var inventory_layer: CanvasLayer = CanvasLayer.new()
	inventory_layer.layer = 3
	inventory_layer.name = "InventoryLayer"
	add_child(inventory_layer)
	inventory_ui = (load("res://ui/inventory_ui.tscn") as PackedScene).instantiate() as InventoryUI
	inventory_layer.add_child(inventory_ui)
	inventory_ui.configure(inventory, equipment, consumables, health, player, save_store)
	inventory_ui.close_inventory()


func _create_definitions_and_inventory() -> void:
	var pistol: ItemDefinition = ItemDefinition.new()
	pistol.item_id = &"street_pistol"
	pistol.display_name = "Street Pistol"
	pistol.weapon_family = &"pistol"
	pistol.magazine_capacity = 12
	pistol.base_stats = {"damage": 24.0, "fire_rate_per_second": 5.0, "range_m": 40.0, "spread_degrees": 0.0, "recoil_degrees": 0.25}
	var medkit: ItemDefinition = ItemDefinition.new()
	medkit.item_id = &"street_medkit"
	medkit.display_name = "Street Medkit"
	medkit.consumable_heal_amount = 25
	var scrap: ItemDefinition = ItemDefinition.new()
	scrap.item_id = &"signal_scrap"
	scrap.display_name = "Signal Scrap"
	definitions = {"street_pistol": pistol, "street_medkit": medkit, "signal_scrap": scrap}
	inventory = GridInventory.new(Vector2i(6, 4))
	ammo = AmmoPouch.new(100)
	grants = ItemGrants.new(inventory, definitions)
	cache_item = _make_item("00000000-0000-4000-8000-000000000001", pistol, Vector2i.ZERO, 10)
	var med_item: ItemInstance = _make_item("00000000-0000-4000-8000-000000000002", medkit, Vector2i(0, 1))
	if not inventory.try_add_item(cache_item) or not inventory.try_add_item(med_item):
		_setup_error = "starting weapon/medkit do not fit the test inventory"
		return
	ammo.add_ammo("pistol", 24)
	equipment = EquipmentService.new(inventory, definitions, ammo)
	if not equipment.equip_item(cache_item.uuid):
		_setup_error = "starter pistol could not be equipped"
		return
	inventory_snapshot = InventorySnapshot.new(inventory, ammo, definitions, grants)
	var loot_definition: ItemDefinition = definitions["signal_scrap"] as ItemDefinition
	loot_item = _make_item("00000000-0000-4000-8000-000000000003", loot_definition, Vector2i(2, 0))


func _build_world_records() -> void:
	registry = EntityRegistry.new()
	registry.register_entity(PLAYER_UUID, {"checkpoint": "night_market"})
	registry.register_entity(CACHE_UUID, {"collected": false})
	factions = FactionState.new(["player", "security", "night_market"])
	factions.set_faction_standing("security", -100)
	factions.set_faction_standing("night_market", 0)
	var mission_template: MissionTemplate = load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate
	missions = MissionDirector.new()
	if not missions.configure([mission_template], registry, factions, func(_target_uuid: String) -> bool: return true):
		_setup_error = "MissionDirector failed configuration"
		return
	npc_memory = NpcMemory.new()
	if not npc_memory.configure({"underpass_signal_cache": "A signal cache was stashed beneath the transit underpass."}, func(_npc_id: String, _fact_id: String, _source: String, _evidence: String) -> bool: return true):
		_setup_error = "NPC memory failed configuration"
		return
	dialogue_snapshot = DialogueSnapshot.new()
	if not dialogue_snapshot.configure(npc_memory, missions, factions):
		_setup_error = "NPC/mission snapshot adapter failed configuration"


func _build_loot() -> void:
	cache_drop = _make_loot_drop(loot_item)
	cache_drop.name = "SignalScrapDrop"
	cache_drop.position = Vector3(-3.0, 0.35, -0.8)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.42, 0.42, 0.42)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("ffb52e")
	material.emission_enabled = true
	material.emission = Color("7b3d08")
	mesh.material = material
	mesh_instance.mesh = mesh
	cache_drop.add_child(mesh_instance)
	add_child(cache_drop)


func _build_enemy() -> void:
	goon = (load("res://features/npcs/goon.tscn") as PackedScene).instantiate() as TacticalAgent
	if goon == null:
		_setup_error = "goon scene could not be instantiated"
		return
	goon.name = "SecurityGoon"
	goon.position = Vector3(-1.8, 0.0, 0.0)
	add_child(goon)
	if not goon.configure(factions, "security", []):
		_setup_error = "security goon failed configuration"
		return
	goon.set_candidate_target(player, "player")
	goon.attack_delivered.connect(_on_enemy_attack)
	goon.agent_died.connect(_on_enemy_death)
	var driver: Node = goon.get_node_or_null("NavigationDriver")
	if driver != null:
		driver.set("process_navigation", false)


func _build_hacking() -> void:
	var manifest: ChunkManifest = ChunkManifest.new()
	var records: Array[Dictionary] = [{
		"id": "night_market_service_lane",
		"bounds": AABB(Vector3(-20.0, -4.0, -20.0), Vector3(40.0, 20.0, 40.0)),
		"scene_path": CHUNK_A,
		"adjacent": [],
		"entities": [{"uuid": DOOR_UUID, "node_path": "ServiceDoor", "initial_state": {"locked": true, "open": false}}]
	}]
	if not manifest.configure(records):
		_setup_error = "hack target manifest was rejected"
		return
	door_manifest = manifest
	door_manager = WorldManager.new()
	if not door_manager.configure(door_manifest, 0.0, 0.0):
		_setup_error = "hack door WorldManager failed configuration"
		return
	door_manager.update_player_position(player.global_position)
	entity_hydrator = EntityHydrator.new()
	if not entity_hydrator.configure(registry, door_manifest, door_manager):
		_setup_error = "Hack entity hydrator failed configuration"
		return
	if not _create_door_projection():
		_setup_error = "persistent hack door projection failed activation"
		return
	hacking_state = HackingState.new()
	if not hacking_state.configure(100.0, 8.0, 100.0):
		_setup_error = "HackingState failed configuration"
		return
	hacking_service = HackingService.new()
	if not hacking_service.configure(player, hacking_state, hacking_service.get_default_definitions()):
		_setup_error = "HackingService failed configuration"


func _create_door_projection() -> bool:
	var generation: int = door_manager.get_lifecycle_generation("night_market_service_lane")
	door_projection_root = Node3D.new()
	door_projection_root.name = "NightMarketServiceLane"
	var door: HackableDoor = HackableDoor.new()
	door.name = "ServiceDoor"
	door.persistent_uuid = DOOR_UUID
	door.position = Vector3(-4.0, 1.1, -5.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.2, 2.2, 0.2)
	collision.shape = shape
	door.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var door_mesh: BoxMesh = BoxMesh.new()
	door_mesh.size = shape.size
	var door_material: StandardMaterial3D = StandardMaterial3D.new()
	door_material.albedo_color = Color("b6355a")
	door_material.metallic = 0.5
	door_material.roughness = 0.28
	door_mesh.material = door_material
	visual.mesh = door_mesh
	door.add_child(visual)
	door_projection_root.add_child(door)
	add_child(door_projection_root)
	if not door.configure_lifecycle(entity_hydrator, generation):
		return false
	if not entity_hydrator.prepare_chunk("night_market_service_lane", generation, door_projection_root):
		return false
	if not door_manager.acknowledge_activated("night_market_service_lane", generation):
		return false
	if not entity_hydrator.activate_chunk("night_market_service_lane", generation, door_projection_root):
		return false
	door_generation = generation
	service_door = door
	return true


func _build_checkpoint() -> void:
	player_snapshot = PlayerSnapshot.new(player, health, actions)
	var adapters: SnapshotAdapters = SnapshotAdapters.new(
		registry, factions,
		Callable(player_snapshot, "capture"), Callable(player_snapshot, "prepare"), Callable(player_snapshot, "commit_prepared"),
		Callable(self, "_capture_domains"), Callable(self, "_prepare_domains"), Callable(self, "_commit_domains")
	)
	save_store = SaveStore.new(SAVE_DIRECTORY, Callable(adapters, "capture_snapshot"), Callable(adapters, "validate_snapshot"), Callable(adapters, "apply_snapshot"))
	checkpoint = (load("res://persistence/checkpoint_controller.gd") as Script).new()
	checkpoint.name = "CheckpointController"
	add_child(checkpoint)
	if not checkpoint.configure(save_store, adapters, health, 0):
		_setup_error = "CheckpointController failed configuration"


func _build_dialogue() -> void:
	ollama_provider = OllamaProvider.new()
	ollama_provider.name = "LocalOllamaProvider"
	add_child(ollama_provider)
	dialogue_orchestrator = DialogueOrchestrator.new()
	dialogue_orchestrator.name = "DialogueOrchestrator"
	add_child(dialogue_orchestrator)
	dialogue_orchestrator.dialogue_ready.connect(_on_model_dialogue_ready)
	var dispatcher: ActionDispatcher = ActionDispatcher.new()
	var policy: Dictionary = {
		"resolve_actor": Callable(self, "_resolve_dialogue_actor"),
		"mission_director": missions,
		"mission_permissions": {NPC_ID: ["retrieve_signal_cache"]},
	}
	if not dispatcher.configure(policy):
		_setup_error = "ActionDispatcher failed configuration"
		return
	var context: ContextSnapshot = dialogue_snapshot.build_context(NPC_ID, "Mara Vega", "night_market", ["retrieve_signal_cache"])
	if context == null:
		_setup_error = "dialogue context could not be built"
		return
	var dialogue_layer: CanvasLayer = CanvasLayer.new()
	dialogue_layer.layer = 2
	dialogue_layer.name = "DialogueLayer"
	add_child(dialogue_layer)
	dialogue_ui = UI_DIALOGUE_SCENE.instantiate() as DialogueUI
	dialogue_ui.name = "DialogueUI"
	dialogue_layer.add_child(dialogue_ui)
	dialogue_ui.set_recovery_action(Callable(self, "_collect_signal_cache"))
	if not dialogue_ui.configure(dialogue_orchestrator, dispatcher, missions, context):
		_setup_error = "DialogueUI failed service configuration"
	dialogue_ui.visible = false


func _finish_services() -> void:
	if not ollama_provider.configure(MODEL_ENDPOINT, MODEL_NAME, 30.0):
		_setup_error = "Ollama provider failed configuration"
		return
	if not dialogue_orchestrator.configure(ollama_provider, null, 30.0, 2):
		_setup_error = "DialogueOrchestrator failed configuration"


func _reset_headless_fixture_save() -> void:
	var save_path: String = ProjectSettings.globalize_path(SAVE_DIRECTORY + "/slot_00.save")
	var temporary_path: String = save_path + ".tmp"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)


func _open_dialogue() -> void:
	if dialogue_ui == null or not _is_mara_live():
		if _status_label != null:
			_status_label.text = "CONTACT OFFLINE // CHUNK UNAVAILABLE"
		return
	if dialogue_ui.begin_conversation(CONVERSATION_ID):
		dialogue_ui.set_return_focus(inventory_ui)
		_status_label.text = "CONTACT // MARA VEGA"


func _resolve_dialogue_actor(npc_id: String) -> Node:
	return mara_actor if npc_id == NPC_ID and _is_mara_live() else null


func _sync_mara_actor() -> void:
	if _is_mara_live() or _city_loader == null:
		return
	var chunk: Node3D = _city_loader.get_active_instance("district_a")
	if chunk == null:
		return
	mara_actor = Node3D.new()
	mara_actor.name = "MaraVega"
	mara_actor.position = Vector3(-4.0, 0.0, -2.0)
	chunk.add_child(mara_actor)


func _is_mara_live() -> bool:
	return mara_actor != null and is_instance_valid(mara_actor) and not mara_actor.is_queued_for_deletion() and mara_actor.is_inside_tree()


func _cancel_invalid_dialogue() -> void:
	if dialogue_ui == null or not dialogue_ui.visible:
		return
	if health != null and health.is_dead():
		dialogue_ui.close_dialogue()
		return
	if not _is_mara_live() or (player != null and player.global_position.distance_to(mara_actor.global_position) > _dialogue_cancel_distance):
		dialogue_ui.close_dialogue()
		if _status_label != null:
			_status_label.text = "CONTACT CLOSED // LINK LOST"


func _cancel_dialogue_on_player_death() -> void:
	if dialogue_ui != null and dialogue_ui.visible:
		dialogue_ui.close_dialogue()


func _configure_cancellation_probe() -> bool:
	cancellation_provider = MockDialogueProvider.new()
	cancellation_provider.delay_seconds = 1.0
	if not cancellation_provider.set_response_mode(MockDialogueProvider.ResponseMode.DELAYED):
		return false
	cancellation_orchestrator = DialogueOrchestrator.new()
	cancellation_orchestrator.name = "DialogueCancellationProbe"
	add_child(cancellation_orchestrator)
	cancellation_orchestrator.dialogue_ready.connect(_on_cancellation_probe_response)
	var dispatcher: ActionDispatcher = ActionDispatcher.new()
	var policy: Dictionary = {
		"resolve_actor": Callable(self, "_resolve_dialogue_actor"),
		"mission_director": missions,
		"mission_permissions": {NPC_ID: ["retrieve_signal_cache"]},
	}
	var context: ContextSnapshot = dialogue_snapshot.build_context(NPC_ID, "Mara Vega", "night_market", ["retrieve_signal_cache"])
	return dispatcher.configure(policy) and cancellation_orchestrator.configure(cancellation_provider) and dialogue_ui.configure(cancellation_orchestrator, dispatcher, missions, context)


func _begin_dialogue_request(conversation_id: String, prompt_text: String) -> bool:
	if dialogue_ui == null or not _is_mara_live() or not dialogue_ui.begin_conversation(conversation_id):
		return false
	dialogue_ui.set_return_focus(inventory_ui)
	dialogue_ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").set("text", prompt_text)
	_last_model_request_usec = Time.get_ticks_usec()
	dialogue_ui.call("_submit_prompt")
	return true


func _pick_up_loot() -> bool:
	if cache_drop == null or not is_instance_valid(cache_drop) or player.global_position.distance_to(cache_drop.global_position) > 2.0:
		_status_label.text = "LOOT OUT OF REACH"
		return false
	var item: ItemInstance = loot_item.duplicate(true) as ItemInstance
	var accepted: bool = inventory.try_pickup_item(item, cache_drop)
	if accepted:
		cache_drop = null
		_status_label.text = "LOOT SECURED // SIGNAL SCRAP"
		return true
	_status_label.text = "INVENTORY FULL // LOOT REMAINS"
	return false


func _use_medkit() -> bool:
	var token: int = actions.begin_heal(Vector2i(0, 1))
	if token <= 0:
		_status_label.text = "HEALING UNAVAILABLE"
		return false
	var healed: bool = actions.complete_heal(token)
	_status_label.text = "VITALS RESTORED" if healed else "HEALING INTERRUPTED"
	return healed


func _unlock_service_door() -> bool:
	if service_door == null or hacking_service == null:
		return false
	var hacked: bool = hacking_service.request_hack(service_door, HackDefinition.Ability.UNLOCK_DOOR)
	_status_label.text = "SERVICE DOOR // UNLOCKED" if hacked else "HACK REJECTED // %s" % String(hacking_service.get_last_rejection_reason()).to_upper()
	return hacked


func _collect_signal_cache() -> bool:
	if not registry.has_entity(CACHE_UUID):
		return false
	var state: Dictionary = registry.get_entity_state(CACHE_UUID)
	if bool(state.get("collected", false)):
		return false
	return registry.try_commit_state_delta(CACHE_UUID, {"collected": true})


func _save_checkpoint() -> void:
	var error: Error = checkpoint.save_checkpoint(0)
	_status_label.text = "CHECKPOINT // SAVED" if error == OK else "CHECKPOINT // SAVE ERROR %d" % error


func _restore_checkpoint() -> void:
	var error: Error = checkpoint.restore_checkpoint(0)
	if error == OK:
		_refresh_hack_projection()
	_status_label.text = "CHECKPOINT // RESTORED" if error == OK else "CHECKPOINT // LOAD ERROR %d" % error


func _refresh_hack_projection() -> bool:
	if door_projection_root != null and is_instance_valid(door_projection_root):
		entity_hydrator.retire_chunk("night_market_service_lane", door_generation, door_projection_root)
		door_manager.update_player_position(Vector3(1000.0, 0.0, 0.0))
		if is_instance_valid(door_projection_root):
			door_projection_root.queue_free()
		service_door = null
	door_manager.update_player_position(player.global_position)
	var next_generation: int = door_manager.get_lifecycle_generation("night_market_service_lane")
	return _create_door_projection() and next_generation == door_generation


func _capture_domains() -> Dictionary:
	return {"inventory": inventory_snapshot.capture_snapshot(), "dialogue": dialogue_snapshot.capture_domains()}


func _prepare_domains(candidate: Variant) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY or not candidate.has("inventory") or not candidate.has("dialogue"):
		return {"ok": false, "prepared": {}}
	var inventory_plan: Dictionary = inventory_snapshot.prepare_snapshot(candidate["inventory"])
	var dialogue_plan: Dictionary = dialogue_snapshot.prepare_domains(candidate["dialogue"])
	if not inventory_plan.get("ok", false) or not dialogue_plan.get("ok", false):
		return {"ok": false, "prepared": {}}
	return {"ok": true, "prepared": {"inventory": inventory_plan["prepared"], "dialogue": dialogue_plan["prepared"]}}


func _commit_domains(prepared: Dictionary) -> void:
	inventory_snapshot.commit_prepared_snapshot(prepared["inventory"])
	dialogue_snapshot.commit_prepared_domains(prepared["dialogue"])


func _build_sign(position_value: Vector3, color_value: Color, size: Vector3) -> MeshInstance3D:
	var sign_node: MeshInstance3D = MeshInstance3D.new()
	sign_node.position = position_value
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color_value
	material.emission_enabled = true
	material.emission = color_value * 0.7
	mesh.material = material
	sign_node.mesh = mesh
	return sign_node


func _make_item(uuid: String, definition: ItemDefinition, cell: Vector2i, magazine: int = 0) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = uuid
	item.item_id = definition.item_id
	item.grid_position = cell
	item.dimensions = definition.dimensions
	item.rarity_tier = &"common"
	item.magazine_ammo = magazine
	return item


func _on_enemy_attack(target: Node3D, amount: int) -> void:
	if target == player and health != null:
		health.apply_damage(amount, "security")


func _on_enemy_death() -> void:
	if _status_label != null:
		_status_label.text = "SECURITY GOON // DOWN"


func _wait_for(predicate: Callable, timeout_seconds: float = MAX_WAIT_SECONDS) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return bool(predicate.call())


func _run_headless_smoke() -> void:
	await get_tree().process_frame
	_check(await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") != null and _is_mara_live()), "first streamed chunk activates with its attached NPC actor")
	var dialogue_started: bool = _begin_dialogue_request(CONVERSATION_ID, "What is hidden beneath the transit underpass?")
	_check(dialogue_started, "named NPC dialogue session starts with the installed local provider")
	player.global_position.x = -0.5
	_check(await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_b") != null), "neighbor chunk preloads before crossing the seam")
	player.global_position.x = 1.0
	_check(await _wait_for(func() -> bool: return player.is_on_floor() and _city_loader.get_active_instance("district_b") != null), "player crosses onto connected district geometry")
	player.global_position.x = -1.0
	_check(await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") != null), "backtracking retains the encounter chunk")
	player.global_position = Vector3(-4.0, 0.0, 0.0)
	await get_tree().physics_frame
	_check(_city_loader.get_active_instance("district_a") != null, "player returns to the encounter district")
	var shot: HitResult = actions.fire_current_weapon()
	_check(shot.fired and shot.target_node == goon and goon.health_state.current_hp < goon.maximum_health, "equipped pistol damages the configured security enemy")
	dialogue_ui.request_job()
	var mission_rows: Array = missions.capture_snapshot().get("missions", [])
	mission_id = String(mission_rows[0].get("mission_id", "")) if not mission_rows.is_empty() else ""
	var mission_offered: bool = not mission_id.is_empty()
	_check(mission_offered, "named NPC offers the authored retrieval mission")
	var inference_finished: bool = await _wait_for(func() -> bool: return _model_response_received, 35.0)
	_check(inference_finished and not _model_used_fallback, "local Ollama response completes during traversal and mission interaction")
	_check(_configure_cancellation_probe(), "delayed NPC provider configures for deterministic cancellation checks")
	player.global_position.x = 3.5
	_check(await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") == null and _city_loader.get_active_instance("district_b") != null), "old chunk retires after traversal into its neighbor")
	player.global_position.x = -1.0
	_check(await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") != null), "backtracking reloads the first district")
	player.global_position = Vector3(-4.0, 0.0, 0.0)
	_check(await _wait_for(func() -> bool: return _is_mara_live()), "backtracking reattaches the streamed NPC projection")
	var before_walkaway_cancel: int = _model_dialogue_count
	_dialogue_cancel_distance = 2.2
	var walkaway_request_started: bool = _begin_dialogue_request("world06_walkaway_cancel", "Confirm this request is abandoned when I leave.")
	player.global_position.x = -2.0
	var walkaway_closed: bool = await _wait_for(func() -> bool: return not dialogue_ui.visible)
	var walkaway_stale_response: bool = await _wait_for(func() -> bool: return _cancel_probe_response_count > 0, 1.2)
	_check(walkaway_request_started and walkaway_closed and _city_loader.get_active_instance("district_a") != null and _model_dialogue_count == before_walkaway_cancel and not walkaway_stale_response, "walking away cancels the in-flight NPC response without unloading its chunk")
	_dialogue_cancel_distance = 100.0
	var before_unload_cancel: int = _model_dialogue_count
	var unload_request_started: bool = _begin_dialogue_request("world06_unload_cancel", "Confirm this request is abandoned when the district unloads.")
	player.global_position.x = 3.5
	var source_unloaded: bool = await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") == null and _city_loader.get_active_instance("district_b") != null)
	var unload_dialogue_closed: bool = await _wait_for(func() -> bool: return not dialogue_ui.visible)
	var unload_stale_response: bool = await _wait_for(func() -> bool: return _cancel_probe_response_count > 0, 1.2)
	_check(unload_request_started and source_unloaded and unload_dialogue_closed and _model_dialogue_count == before_unload_cancel and not unload_stale_response, "chunk unload cancels the in-flight NPC response")
	player.global_position = Vector3(-4.0, 0.0, 0.0)
	_check(await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") != null and _is_mara_live()), "backtracking restores Mara after cancellation")
	var hacked: bool = _unlock_service_door()
	_check(hacked and service_door.open and registry.get_entity_state(DOOR_UUID).get("open", false), "validated door hack commits authoritative open state")
	var loot_picked: bool = _pick_up_loot()
	if not loot_picked or inventory.get_item_count() != 3:
		printerr("WORLD-06 loot diagnostics: picked=%s count=%d drop_valid=%s drop_inside=%s distance=%.3f player=%s" % [loot_picked, inventory.get_item_count(), is_instance_valid(cache_drop), cache_drop.is_inside_tree() if is_instance_valid(cache_drop) else false, player.global_position.distance_to(cache_drop.global_position) if is_instance_valid(cache_drop) else -1.0, player.global_position])
	_check(loot_picked and inventory.get_item_count() == 3, "world loot pickup transfers item into the player grid")
	var healed: bool = _use_medkit()
	if not healed or health.current_hp != 95:
		printerr("WORLD-06 heal diagnostics: healed=%s hp=%d token_action_status=%s" % [healed, health.current_hp, _status_label.text])
	_check(healed and health.current_hp == 95, "inventory medkit heals through the weapon action transaction")
	var written: Error = checkpoint.save_checkpoint(0)
	_check(written == OK, "integrated player, inventory, mission and world state save to disk")
	var before_death_cancel: int = _model_dialogue_count
	var death_request_started: bool = _begin_dialogue_request("world06_death_cancel", "Confirm this request is abandoned when the player dies.")
	health.apply_damage(200, "feasibility_dialogue_cancel")
	var death_dialogue_closed: bool = await _wait_for(func() -> bool: return not dialogue_ui.visible)
	var death_stale_response: bool = await _wait_for(func() -> bool: return _cancel_probe_response_count > 0, 1.2)
	_check(death_request_started and death_dialogue_closed and health.current_hp == 95 and _model_dialogue_count == before_death_cancel and not death_stale_response, "player death cancels dialogue before saved checkpoint recovery")
	var saved_position: Vector3 = player.global_position
	var saved_hp: int = health.current_hp
	var saved_inventory_count: int = inventory.get_item_count()
	var saved_mission: Dictionary = missions.get_mission(mission_id)
	var saved_registry: Dictionary = registry.get_entity_state(DOOR_UUID)
	player.global_position = Vector3(6.0, 0.0, 0.0)
	health.apply_damage(10, "smoke_mutation")
	registry.try_commit_state_delta(DOOR_UUID, {"locked": true, "open": false})
	var restored: Error = checkpoint.restore_checkpoint(0)
	var projected: bool = restored == OK and _refresh_hack_projection()
	_check(restored == OK and projected and player.global_position.is_equal_approx(saved_position) and health.current_hp == saved_hp and inventory.get_item_count() == saved_inventory_count and missions.get_mission(mission_id) == saved_mission and registry.get_entity_state(DOOR_UUID) == saved_registry and service_door.open, "checkpoint restores data domains and rehydrates the hacked door")
	var child_output: Array = []
	var child_exit: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/scenes/feasibility.tscn", "--", "--relaunch-check"], child_output, true)
	var child_text: String = "\n".join(PackedStringArray(child_output))
	print(child_text)
	_check(child_exit == 0 and child_text.contains("WORLD-06_RELAUNCH_PASS"), "fresh Godot process reloads feasibility checkpoint (exit %d)" % child_exit)
	var fallback_provider: MockDialogueProvider = MockDialogueProvider.new()
	var fallback_orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	fallback_orchestrator.name = "OfflineFallbackOrchestrator"
	add_child(fallback_orchestrator)
	fallback_orchestrator.dialogue_ready.connect(_on_offline_dialogue_ready)
	var offline_context: ContextSnapshot = dialogue_snapshot.build_context(NPC_ID, "Mara Vega", "night_market", ["retrieve_signal_cache"])
	var offline_configured: bool = fallback_provider.set_response_mode(MockDialogueProvider.ResponseMode.OFFLINE) and fallback_orchestrator.configure(fallback_provider) and fallback_orchestrator.begin_conversation(NPC_ID, "world06_offline_fallback", offline_context, "The authored fallback keeps the mission available.")
	if offline_configured:
		fallback_orchestrator.submit_dialogue_request(NPC_ID, "Where is the mission target?")
	_check(offline_configured and _offline_fallback_received and _offline_used_fallback, "offline provider failure returns authored fallback dialogue")
	var output: Dictionary = _build_benchmark_summary()
	_write_benchmark("headless_smoke.json", output)
	_print_summary()
	get_tree().quit(1 if _has_failures() else 0)


func _run_sustained_benchmark() -> void:
	_dialogue_cancel_distance = 100000.0
	var short_benchmark: bool = OS.get_cmdline_user_args().has("--benchmark-short")
	var baseline_seconds: float = 3.0 if short_benchmark else BENCHMARK_BASELINE_SECONDS
	var concurrent_seconds: float = 8.0 if short_benchmark else BENCHMARK_CONCURRENT_SECONDS
	var request_timeout_seconds: float = 7.0 if short_benchmark else 30.0
	var first_chunk_active: bool = await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") != null and _is_mara_live())
	if not first_chunk_active:
		_write_benchmark("sustained_load.json", {"all_assertions_passed": false, "failure": "initial chunk did not activate"})
		get_tree().quit(1)
		return
	var baseline_indices: Dictionary = _sampling_indices()
	var baseline_started_usec: int = Time.get_ticks_usec()
	print("WORLD-06 benchmark baseline started: tree_paused=%s" % get_tree().paused)
	await get_tree().create_timer(baseline_seconds).timeout
	var baseline: Dictionary = _phase_summary("game_only", baseline_started_usec, baseline_indices)
	var context: ContextSnapshot = dialogue_snapshot.build_context(NPC_ID, "Mara Vega", "night_market", ["retrieve_signal_cache"])
	var conversation_started: bool = context != null and dialogue_orchestrator.begin_conversation(NPC_ID, "world06_sustained_benchmark", context, "The underpass is hot. Bring back the signal cache and I'll pay you.")
	if not conversation_started:
		_write_benchmark("sustained_load.json", {"all_assertions_passed": false, "game_only": baseline, "failure": "benchmark dialogue context did not initialize"})
		get_tree().quit(1)
		return
	dialogue_ui.visible = false
	var latency_index: int = _model_latency_samples_ms.size()
	var concurrent_indices: Dictionary = _sampling_indices()
	var concurrent_started_usec: int = Time.get_ticks_usec()
	var request_count: int = 0
	var request_failures: int = 0
	var fallback_count: int = 0
	var boundary_samples: Array[Dictionary] = []
	if not dialogue_orchestrator.request_rejected.is_connected(_on_benchmark_request_rejected):
		dialogue_orchestrator.request_rejected.connect(_on_benchmark_request_rejected)
	print("WORLD-06 benchmark inference started: tree_paused=%s active_frames=%d" % [get_tree().paused, _frame_intervals_ms.size()])
	while float(Time.get_ticks_usec() - concurrent_started_usec) / 1000000.0 < concurrent_seconds:
		var response_count_before: int = _model_dialogue_count
		_last_model_request_usec = Time.get_ticks_usec()
		dialogue_orchestrator.submit_dialogue_request(NPC_ID, "Use only the supplied facts: a signal cache is stashed beneath the transit underpass. State its location in one concise sentence.")
		print("WORLD-06 benchmark request submitted")
		var completed: bool = await _wait_for(func() -> bool: return _model_dialogue_count > response_count_before, request_timeout_seconds)
		if not completed:
			request_failures += 1
			request_count += 1
			dialogue_orchestrator.cancel_current_conversation()
			break
		request_count += 1
		if _last_model_fallback:
			fallback_count += 1
		if request_count % BENCHMARK_CROSS_EVERY_REQUESTS == 0:
			var target_x: float = 3.5 if player.global_position.x < 0.0 else -4.0
			boundary_samples.append(await _measure_boundary_crossing(target_x))
		await get_tree().create_timer(0.2 if short_benchmark else BENCHMARK_REQUEST_PAUSE_SECONDS).timeout
	var concurrent: Dictionary = _phase_summary("concurrent_inference", concurrent_started_usec, concurrent_indices)
	var latency_samples: Array[float] = _samples_since(_model_latency_samples_ms, latency_index)
	var passed: bool = first_chunk_active and request_count > 0 and request_failures == 0 and not boundary_samples.is_empty()
	var result: Dictionary = {
		"task": "WORLD-06",
		"mode": "fullscreen local debug build; repeated in-game Ollama requests with streamed-chunk seam traversal",
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"renderer": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"window_mode": str(DisplayServer.window_get_mode()),
		"viewport_size": [get_viewport().size.x, get_viewport().size.y],
		"model": {"name": MODEL_NAME, "endpoint": MODEL_ENDPOINT, "context_length": 8192},
		"game_only": baseline,
		"concurrent_inference": concurrent,
		"inference_requests_completed": request_count - request_failures,
		"inference_request_failures": request_failures,
		"inference_fallbacks": fallback_count,
		"full_response_latency_ms": _stats(latency_samples),
		"boundary_crossings": boundary_samples,
		"all_assertions_passed": passed,
	}
	_write_benchmark("sustained_load.json", result)
	print("WORLD-06 sustained benchmark: %d responses, %d boundary crossings, game-only %.1fs, concurrent %.1fs" % [request_count - request_failures, boundary_samples.size(), baseline["duration_seconds"], concurrent["duration_seconds"]])
	get_tree().quit(0 if passed else 1)


func _measure_boundary_crossing(target_x: float) -> Dictionary:
	var first_frame_index: int = _frame_intervals_ms.size()
	var started_usec: int = Time.get_ticks_usec()
	var memory_before_bytes: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	player.global_position = Vector3(target_x, 0.0, 0.0)
	var reached: bool = false
	if target_x > 0.0:
		reached = await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") == null and _city_loader.get_active_instance("district_b") != null)
	else:
		reached = await _wait_for(func() -> bool: return _city_loader.get_active_instance("district_a") != null)
	var load_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0
	await get_tree().create_timer(0.5).timeout
	var frame_samples: Array[float] = _samples_since(_frame_intervals_ms, first_frame_index)
	var memory_after_bytes: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	return {
		"target_x": target_x,
		"activated": reached,
		"load_ms": load_ms,
		"settle_frame_interval_ms": _stats(frame_samples),
		"static_memory_before_bytes": memory_before_bytes,
		"static_memory_after_settle_bytes": memory_after_bytes,
		"static_memory_change_bytes": memory_after_bytes - memory_before_bytes,
	}


func _sampling_indices() -> Dictionary:
	return {
		"frame": _frame_intervals_ms.size(),
		"process": _process_times_ms.size(),
		"physics": _physics_times_ms.size(),
		"draw": _draw_calls.size(),
		"memory": _static_memory_bytes.size(),
	}


func _phase_summary(phase: String, started_usec: int, indices: Dictionary) -> Dictionary:
	return {
		"phase": phase,
		"duration_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
		"frame_interval_ms": _stats(_samples_since(_frame_intervals_ms, int(indices["frame"]))),
		"process_ms": _stats(_samples_since(_process_times_ms, int(indices["process"]))),
		"physics_process_ms": _stats(_samples_since(_physics_times_ms, int(indices["physics"]))),
		"render_draw_calls": _stats(_samples_since(_draw_calls, int(indices["draw"]))),
		"static_memory_bytes": _stats(_samples_since(_static_memory_bytes, int(indices["memory"]))),
	}


func _samples_since(values: Array[float], first_index: int) -> Array[float]:
	var result: Array[float] = []
	for index: int in range(clampi(first_index, 0, values.size()), values.size()):
		result.append(values[index])
	return result


func _run_fresh_process_check() -> void:
	var restored: Error = checkpoint.restore_checkpoint(0)
	var restored_missions: Array = missions.capture_snapshot().get("missions", [])
	print("WORLD-06 relaunch observed: error=%d position=%s hp=%d inventory=%d missions=%d door=%s" % [restored, player.global_position, health.current_hp, inventory.get_item_count(), restored_missions.size(), registry.get_entity_state(DOOR_UUID).get("open", false)])
	var success: bool = restored == OK and player.global_position.is_equal_approx(Vector3(-4.0, 0.0, 0.0)) and health.current_hp == 95 and inventory.get_item_count() == 2 and not restored_missions.is_empty() and registry.get_entity_state(DOOR_UUID).get("open", false)
	if success:
		_refresh_hack_projection()
		print("WORLD-06_RELAUNCH_PASS: player/inventory/mission/world records restored in a fresh process")
	else:
		printerr("WORLD-06_RELAUNCH_FAIL: fresh process did not restore feasibility checkpoint")
	get_tree().quit(0 if success else 1)


func _check(condition: bool, description: String) -> void:
	_checks.append({"passed": condition, "description": description})
	print("WORLD-06 %s: %s" % ["PASS" if condition else "FAIL", description])


func _on_model_dialogue_ready(_npc_id: String, _conversation_id: String, _generation: int, _response: LLMResponse, used_fallback: bool) -> void:
	_model_response_received = true
	_model_dialogue_count += 1
	_model_request_ms = float(Time.get_ticks_usec() - _last_model_request_usec) / 1000.0 if _last_model_request_usec > 0 else -1.0
	_model_used_fallback = used_fallback
	_last_model_fallback = used_fallback
	if used_fallback:
		_model_fallback_count += 1
	if _model_request_ms >= 0.0:
		_model_latency_samples_ms.append(_model_request_ms)


func _on_offline_dialogue_ready(_npc_id: String, _conversation_id: String, _generation: int, _response: LLMResponse, used_fallback: bool) -> void:
	_offline_fallback_received = true
	_offline_used_fallback = used_fallback


func _on_cancellation_probe_response(_npc_id: String, _conversation_id: String, _generation: int, _response: LLMResponse, _used_fallback: bool) -> void:
	_cancel_probe_response_count += 1


func _on_benchmark_request_rejected(_npc_id: String, reason: StringName) -> void:
	print("WORLD-06 benchmark request rejected: %s" % reason)


func _has_failures() -> bool:
	for check: Dictionary in _checks:
		if not bool(check["passed"]):
			return true
	return false


func _print_summary() -> void:
	var passed: int = 0
	for check: Dictionary in _checks:
		if bool(check["passed"]):
			passed += 1
	print("WORLD-06 smoke: %d/%d passed" % [passed, _checks.size()])


func _capture_startup() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(BENCHMARK_DIR + "/feasibility_startup.png"))


func _exit_tree() -> void:
	if _started_usec > 0 and not _headless_smoke and not _relaunch_check:
		_write_benchmark("runtime_metrics.json", _build_benchmark_summary())


func _build_benchmark_summary() -> Dictionary:
	return {
		"task": "WORLD-06",
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"renderer": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"window_mode": str(DisplayServer.window_get_mode()) if DisplayServer.get_name() != "headless" else "headless",
		"viewport_size": [get_viewport().size.x, get_viewport().size.y],
		"duration_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
		"samples": _frame_intervals_ms.size(),
		"frame_interval_ms": _stats(_frame_intervals_ms),
		"process_ms": _stats(_process_times_ms),
		"physics_process_ms": _stats(_physics_times_ms),
		"render_draw_calls": _stats(_draw_calls),
		"static_memory_bytes": _stats(_static_memory_bytes),
		"model_request_ms": _model_request_ms,
		"model_used_fallback": _model_used_fallback,
		"all_assertions_passed": not _has_failures(),
	}


func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "median": 0.0, "p95": 0.0, "max": 0.0}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return {
		"count": sorted.size(),
		"median": _percentile(sorted, 0.5),
		"p95": _percentile(sorted, 0.95),
		"max": sorted[-1],
	}


func _percentile(sorted: Array[float], percentile: float) -> float:
	return sorted[clampi(int(ceil(float(sorted.size() - 1) * percentile)), 0, sorted.size() - 1)]


func _trim_samples() -> void:
	_frame_intervals_ms = _frame_intervals_ms.slice(-10000)
	_process_times_ms = _process_times_ms.slice(-10000)
	_physics_times_ms = _physics_times_ms.slice(-10000)
	_draw_calls = _draw_calls.slice(-10000)
	_static_memory_bytes = _static_memory_bytes.slice(-10000)


func _write_benchmark(file_name: String, value: Dictionary) -> void:
	var output_directory: String = ProjectSettings.globalize_path(BENCHMARK_DIR)
	DirAccess.make_dir_recursive_absolute(output_directory)
	var file: FileAccess = FileAccess.open(output_directory.path_join(file_name), FileAccess.WRITE)
	if file == null:
		push_warning("Could not write WORLD-06 benchmark output: " + file_name)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	file.close()


func _make_loot_drop(item: ItemInstance) -> Node3D:
	var drop: Node3D = Node3D.new()
	drop.name = "WorldLootDrop"
	drop.set_meta("inventory_item", item.to_data())
	return drop
