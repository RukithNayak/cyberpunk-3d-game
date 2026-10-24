extends Node
## Adds the existing player-facing HUD and lightweight street population.

const HUD_SCENE: PackedScene = preload("res://ui/player_hud.tscn")
const INVENTORY_SCENE: PackedScene = preload("res://ui/inventory_ui.tscn")
const DIALOGUE_SCENE: PackedScene = preload("res://ui/dialogue_ui.tscn")
const SECURITY_SCENE: PackedScene = preload("res://features/npcs/goon.tscn")
const RESIDENT_SCRIPT: Script = preload("res://world/districts/night_market/night_market_resident.gd")
const PLAYER_UUID: String = "00000000-0000-4000-8000-000000000001"
const CACHE_UUID: String = "00000000-0000-4000-8000-000000000032"
const MODEL_ENDPOINT: String = "http://127.0.0.1:11434"
const MODEL_NAME: String = "llama3:willowbrook"
const CACHE_TEMPLATE: MissionTemplate = preload("res://features/missions/retrieve_signal_cache.tres")
const FACADE_TINT: Color = Color(0.72, 0.86, 1.0)
const PANEL_TINT: Color = Color(0.95, 0.62, 0.95)
const WINDOW_TINT: Color = Color(1.0, 0.76, 0.48)
const RESIDENTS: Array[Dictionary] = [
	{"name": "MARA // MARKET CONTACT", "position": Vector3(33.0, 0.0, -51.0), "accent": Color("ffb52e"), "model": "res://assets/characters/night_market/mara_vega.glb"},
	{"name": "NIGHT MARKET // VENDOR", "position": Vector3(37.8, 0.0, -60.0), "accent": Color("36f0de"), "model": "res://assets/characters/night_market/crowd/market_vendor.glb"},
	{"name": "NIGHT MARKET // RESIDENT", "position": Vector3(38.5, 0.0, -54.0), "accent": Color("d95ad9"), "model": "res://assets/characters/night_market/crowd/market_courier.glb"},
]

var player: PlayerController
var health: HealthState
var actions: WeaponStateMachine
var equipment: EquipmentService
var inventory_ui: InventoryUI
var inventory: GridInventory
var merchant_stock: MerchantStock
var medkit_definition: ItemDefinition
var registry: EntityRegistry
var factions: FactionState
var missions: MissionDirector
var npc_memory: NpcMemory
var dialogue_snapshot: DialogueSnapshot
var dialogue_orchestrator: DialogueOrchestrator
var dialogue_ui: DialogueUI
var mara: Node3D
var security: TacticalAgent
var security_status: Label3D
var last_bullet_visual: Node3D
var _movers: Array[Dictionary] = []
var _pulsing_lights: Array[OmniLight3D] = []
var _elapsed: float = 0.0


func _ready() -> void:
	_apply_district_palette()
	_configure_hud_and_inventory()
	_configure_world_authority()
	for resident_data: Dictionary in RESIDENTS:
		var resident: Node3D = _build_resident(resident_data)
		add_child(resident)
		if String(resident_data["name"]).begins_with("MARA"):
			mara = resident
			_add_interaction_marker(mara)
		elif String(resident_data["name"]).contains("RESIDENT"):
			_register_mover(resident, 37.5, 40.0, -54.0, 0.8, 0.0)
		elif String(resident_data["name"]).contains("VENDOR"):
			_register_mover(resident, 36.0, 40.0, -60.0, 0.55, 1.7)
	_build_security()
	_configure_dialogue()
	_build_neon_wayfinding()
	_set_hud_status("E // TALK MARA      LMB // FIRE      R // RELOAD")
	print("NIGHT_MARKET_READY controls=E_talk,LMB_fire,R_reload,Tab_inventory model=%s" % MODEL_NAME)


func _process(delta: float) -> void:
	_elapsed += delta
	for mover: Dictionary in _movers:
		var actor: Node3D = mover["actor"] as Node3D
		if not is_instance_valid(actor):
			continue
		if actor is NightMarketResident and not (actor as NightMarketResident).is_alive:
			continue
		var direction: float = float(mover["direction"])
		var next_x: float = actor.position.x + direction * float(mover["speed"]) * delta
		if next_x <= float(mover["min_x"]) or next_x >= float(mover["max_x"]):
			direction = -direction
			mover["direction"] = direction
			next_x = clampf(next_x, float(mover["min_x"]), float(mover["max_x"]))
			actor.rotation.y = -PI / 2.0 if direction > 0.0 else PI / 2.0
		actor.position.x = next_x
		_play_character_clip(actor, "walk")
		actor.position.y = sin(_elapsed * 14.0 + float(mover["phase"])) * 0.035
	for light_index: int in range(_pulsing_lights.size()):
		_pulsing_lights[light_index].light_energy = 5.6 + sin(_elapsed * (1.1 + light_index * 0.17)) * 0.6


func _apply_district_palette() -> void:
	var district: Node = get_parent().get_node_or_null("District")
	if district == null:
		return
	var palette_materials: Dictionary = {}
	for mesh_instance: MeshInstance3D in district.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source: Material = mesh_instance.get_active_material(surface_index)
			if not source is StandardMaterial3D:
				continue
			var source_material: StandardMaterial3D = source as StandardMaterial3D
			var material_key: int = source_material.get_instance_id()
			if not palette_materials.has(material_key):
				var tuned: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
				var material_name: String = source_material.resource_name.to_lower()
				if material_name.contains("architectural_alloy"):
					tuned.albedo_color = FACADE_TINT
				elif material_name.contains("small_metal_panels"):
					tuned.albedo_color = PANEL_TINT
				elif material_name.contains("asphalt"):
					tuned.albedo_color = Color(2.8, 3.0, 4.0)
					tuned.emission_enabled = true
					tuned.emission = Color("07132b")
					tuned.emission_energy_multiplier = 1.4
				elif material_name.contains("warm_windows"):
					tuned.albedo_color = WINDOW_TINT
					tuned.emission_energy_multiplier = minf(tuned.emission_energy_multiplier, 0.55)
				elif material_name.contains("emissive_neon"):
					tuned.emission_energy_multiplier = minf(tuned.emission_energy_multiplier, 0.8)
				palette_materials[material_key] = tuned
			mesh_instance.set_surface_override_material(surface_index, palette_materials[material_key])


func _configure_hud_and_inventory() -> void:
	player = get_parent().get_node_or_null("Player") as PlayerController
	if player == null:
		push_error("Night Market runtime could not find the player")
		return
	var pistol_definition: ItemDefinition = ItemDefinition.new()
	pistol_definition.item_id = &"night_market_pistol"
	pistol_definition.display_name = "NIGHT MARKET SIDEARM"
	pistol_definition.weapon_family = &"pistol"
	pistol_definition.magazine_capacity = 12
	pistol_definition.base_stats = {"damage": 24.0, "fire_rate_per_second": 5.0, "range_m": 40.0, "spread_degrees": 0.2, "recoil_degrees": 0.4}
	medkit_definition = ItemDefinition.new()
	medkit_definition.item_id = &"street_medkit"
	medkit_definition.display_name = "STREET MEDKIT"
	medkit_definition.consumable_heal_amount = 25
	var definitions: Dictionary = {"night_market_pistol": pistol_definition, "street_medkit": medkit_definition}
	inventory = GridInventory.new(Vector2i(6, 4))
	var pistol: ItemInstance = _make_item("00000000-0000-4000-8000-000000000101", pistol_definition, Vector2i.ZERO, 12)
	var medkit: ItemInstance = _make_item("00000000-0000-4000-8000-000000000102", medkit_definition, Vector2i(0, 1), 0)
	if not inventory.try_add_item(pistol) or not inventory.try_add_item(medkit):
		push_error("Night Market starter items did not fit the inventory")
		return
	var ammo: AmmoPouch = AmmoPouch.new(100)
	ammo.add_ammo("pistol", 48)
	equipment = EquipmentService.new(inventory, definitions, ammo)
	if not equipment.equip_item(pistol.uuid):
		push_error("Night Market starter pistol could not be equipped")
		return
	health = HealthState.new(100)
	var consumables: ConsumableService = ConsumableService.new(inventory, definitions, health)
	var weapon: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
	actions = player.get_node_or_null("WeaponStateMachine") as WeaponStateMachine
	if weapon == null or actions == null:
		push_error("Night Market player combat nodes are missing")
		return
	actions.configure(player, weapon, equipment, consumables, health)
	actions.shot_committed.connect(_on_shot_committed)
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "PlayerHUDLayer"
	hud_layer.layer = 1
	add_child(hud_layer)
	var hud: PlayerHUD = HUD_SCENE.instantiate() as PlayerHUD
	hud_layer.add_child(hud)
	hud.configure(health, actions, equipment, player)
	var inventory_layer: CanvasLayer = CanvasLayer.new()
	inventory_layer.name = "InventoryLayer"
	inventory_layer.layer = 3
	add_child(inventory_layer)
	inventory_ui = INVENTORY_SCENE.instantiate() as InventoryUI
	inventory_layer.add_child(inventory_ui)
	inventory_ui.configure(inventory, equipment, consumables, health, player)
	inventory_ui.close_inventory()


func _configure_world_authority() -> void:
	registry = EntityRegistry.new()
	registry.register_entity(PLAYER_UUID, {"checkpoint": "night_market"})
	registry.register_entity(CACHE_UUID, {"collected": false})
	factions = FactionState.new(["player", "security", "night_market"])
	factions.set_faction_standing("security", -100)
	factions.set_faction_standing("night_market", 0)
	missions = MissionDirector.new()
	if not missions.configure([CACHE_TEMPLATE], registry, factions, Callable(self, "_is_cache_reachable"), 100):
		push_error("Night Market mission service failed to configure")
		return
	npc_memory = NpcMemory.new()
	if not npc_memory.configure(
		{"underpass_signal_cache": "A signal cache was stashed beneath the transit underpass."},
		Callable(self, "_authorize_fact_evidence")
	):
		push_error("Night Market NPC memory failed to configure")
		return
	dialogue_snapshot = DialogueSnapshot.new()
	if not dialogue_snapshot.configure(npc_memory, missions, factions):
		push_error("Night Market dialogue snapshot failed to configure")


func _configure_dialogue() -> void:
	if mara == null or missions == null or dialogue_snapshot == null:
		return
	var provider: OllamaProvider = OllamaProvider.new()
	provider.name = "LocalOllamaProvider"
	add_child(provider)
	if not provider.configure(MODEL_ENDPOINT, MODEL_NAME, 30.0):
		push_error("Night Market Ollama provider failed to configure")
		return
	dialogue_orchestrator = DialogueOrchestrator.new()
	dialogue_orchestrator.name = "DialogueOrchestrator"
	add_child(dialogue_orchestrator)
	if not dialogue_orchestrator.configure(provider, null, 30.0, 2):
		push_error("Night Market dialogue orchestrator failed to configure")
		return
	var dispatcher: ActionDispatcher = ActionDispatcher.new()
	var policy: Dictionary = {
		"resolve_actor": Callable(self, "_resolve_dialogue_actor"),
		"mission_director": missions,
		"mission_permissions": {"mara_vega": ["retrieve_signal_cache"]},
		"merchant_inventory_owners": {MerchantStock.INVENTORY_ID: MerchantStock.MERCHANT_ID},
		"validate_merchant_stock": Callable(self, "_validate_merchant_stock"),
		"open_trade": Callable(self, "_open_merchant_stock"),
	}
	merchant_stock = MerchantStock.new()
	if not merchant_stock.configure(inventory, missions, medkit_definition):
		push_error("Night Market merchant stock failed to configure")
		return
	if not dispatcher.configure(policy):
		push_error("Night Market dialogue authority failed to configure")
		return
	var eligible: Array[String] = ["retrieve_signal_cache"]
	var context: ContextSnapshot = dialogue_snapshot.build_context("mara_vega", "Mara Vega", "night_market", eligible)
	if context == null:
		push_error("Night Market Mara context failed to build")
		return
	var dialogue_layer: CanvasLayer = CanvasLayer.new()
	dialogue_layer.name = "DialogueLayer"
	dialogue_layer.layer = 2
	add_child(dialogue_layer)
	dialogue_ui = DIALOGUE_SCENE.instantiate() as DialogueUI
	dialogue_ui.name = "DialogueUI"
	dialogue_layer.add_child(dialogue_ui)
	if not dialogue_ui.configure(dialogue_orchestrator, dispatcher, missions, context,
		"mara_vega", "MARA VEGA", "Hey. Looking for a decent deal, a lead, or just a place to catch your breath?"):
		push_error("Night Market dialogue UI failed to configure")
		dialogue_ui.visible = false
		return
	dialogue_ui.set_recovery_action(Callable(self, "_collect_signal_cache"))
	dialogue_ui.configure_market_stock(merchant_stock)
	dialogue_ui.visible = false
	dialogue_ui.visibility_changed.connect(_on_dialogue_visibility_changed)


func _resolve_dialogue_actor(npc_id: String) -> Node:
	if npc_id == "mara_vega" and is_instance_valid(mara) and mara.is_inside_tree() \
		and mara is NightMarketResident and (mara as NightMarketResident).is_alive:
		return mara
	return null


func _validate_merchant_stock(inventory_id: String, owner_id: String) -> bool:
	return merchant_stock != null and merchant_stock.is_available(inventory_id, owner_id)


func _open_merchant_stock(inventory_id: String, owner_id: String, _transaction_id: String) -> bool:
	if not _validate_merchant_stock(inventory_id, owner_id) or dialogue_ui == null:
		return false
	dialogue_ui.open_market_stock()
	return true


func _authorize_fact_evidence(_npc_id: String, fact_id: String, source: String, evidence_id: String) -> bool:
	return fact_id == "underpass_signal_cache" and source == "witnessed" and evidence_id == CACHE_UUID \
		and registry != null and registry.get_entity_state(CACHE_UUID).get("collected", true) == true


func _is_cache_reachable(target_uuid: String) -> bool:
	return target_uuid == CACHE_UUID and registry != null and registry.get_entity_state(CACHE_UUID).get("collected", true) == false


func _collect_signal_cache() -> bool:
	if registry == null or registry.get_entity_state(CACHE_UUID).get("collected", true):
		return false
	return registry.try_commit_state_delta(CACHE_UUID, {"collected": true})


func _open_mara_dialogue() -> bool:
	if dialogue_ui == null or mara == null or not is_instance_valid(mara) or player == null \
		or not (mara as NightMarketResident).is_alive:
		return false
	if player.global_position.distance_to(mara.global_position) > 5.5:
		_set_hud_status("MOVE CLOSER TO MARA  // E TO CONNECT")
		return false
	if dialogue_ui.visible:
		return true
	var began: bool = dialogue_ui.begin_conversation("night_market_mara")
	if began:
		_play_character_clip(mara, "interact")
	return began


func _on_dialogue_visibility_changed() -> void:
	if player == null or dialogue_ui == null:
		return
	if dialogue_ui.visible:
		player.add_control_lock(&"dialogue")
	else:
		_play_character_clip(mara, "idle")
		player.remove_control_lock(&"dialogue")
		player.resume_mouse_capture()


func _set_hud_status(message: String) -> void:
	var hud: PlayerHUD = get_node_or_null("PlayerHUDLayer/PlayerHUD") as PlayerHUD
	if hud != null:
		hud.set_status_message(message)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key: InputEventKey = event as InputEventKey
	if key.keycode == KEY_E:
		_open_mara_dialogue()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_R and actions != null and player != null and player.can_act:
		var token: int = actions.begin_reload()
		if token > 0:
			_set_hud_status("RELOADING // SIDEARM")
			_finish_reload_after_delay(token)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and dialogue_ui != null and dialogue_ui.visible:
		dialogue_ui.close_dialogue()
		get_viewport().set_input_as_handled()


func _finish_reload_after_delay(token: int) -> void:
	await get_tree().create_timer(0.65).timeout
	if is_instance_valid(self) and actions != null and actions.complete_reload(token):
		_set_hud_status("SIDEARM RELOADED")


func _build_security() -> void:
	if player == null or factions == null:
		return
	security = SECURITY_SCENE.instantiate() as TacticalAgent
	security.name = "SecurityGoon"
	security.position = Vector3(35.0, 0.0, -57.0)
	add_child(security)
	_play_character_clip(security, "idle")
	security.process_ai = false
	var navigation: Node = security.get_node_or_null("NavigationDriver")
	if navigation != null:
		navigation.set("process_navigation", false)
	if not security.configure(factions, "security"):
		push_error("Night Market security target failed to configure")
		return
	security.set_candidate_target(player, "player")
	security.set_authored_hostility("player", true)
	security.agent_died.connect(_on_security_died)
	security.health_state.health_changed.connect(_on_security_health_changed)
	security_status = Label3D.new()
	security_status.name = "SecurityStatus"
	security_status.text = "SECURITY // 80 HP"
	security_status.position = Vector3(0.0, 2.0, 0.0)
	security_status.font_size = 28
	security_status.outline_size = 8
	security_status.modulate = Color("ff5369")
	security_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	security.add_child(security_status)


func _on_security_health_changed(current: int, maximum: int) -> void:
	if security_status != null:
		security_status.text = "SECURITY // %d / %d HP" % [current, maximum]
		security_status.modulate = Color("ff344f")
		security_status.outline_size = 12
	_set_hud_status("HOSTILE HIT  // %d HP REMAIN" % current)


func _on_security_died() -> void:
	if security_status != null:
		security_status.text = "SECURITY // DOWN"
		security_status.modulate = Color("7f9398")
	var shape: CollisionShape3D = security.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.set_deferred("disabled", true)
	var visual: Node3D = security.get_node_or_null("CharacterModel") as Node3D
	if visual != null:
		if not _play_character_clip(visual, "death"):
			var tween: Tween = create_tween()
			tween.tween_property(visual, "rotation:z", deg_to_rad(82.0), 0.35)
			tween.parallel().tween_property(visual, "position:y", 0.42, 0.35)
	_set_hud_status("THREAT NEUTRALIZED")


func _on_shot_committed(result: HitResult, _weapon_uuid: String) -> void:
	if result == null or not result.fired:
		return
	var muzzle: Marker3D = player.get_node_or_null("Head/Camera3D/Muzzle") as Marker3D
	if muzzle == null or result.hit_position.is_zero_approx():
		return
	var direction: Vector3 = result.hit_position - muzzle.global_position
	if direction.length_squared() < 0.0001:
		return
	var bullet: Node3D = Node3D.new()
	bullet.name = "BulletVisual"
	add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.look_at(result.hit_position, Vector3.UP)
	var casing: MeshInstance3D = MeshInstance3D.new()
	var shell: CapsuleMesh = CapsuleMesh.new()
	shell.radius = 0.045
	shell.height = 0.42
	var shell_material: StandardMaterial3D = StandardMaterial3D.new()
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_material.albedo_color = Color("fff2b0")
	shell_material.emission_enabled = true
	shell_material.emission = Color("ff9c26")
	shell_material.emission_energy_multiplier = 3.2
	shell.material = shell_material
	casing.mesh = shell
	casing.rotation.x = -PI / 2.0
	bullet.add_child(casing)
	var duration: float = clampf(direction.length() / 150.0, 0.075, 0.24)
	last_bullet_visual = bullet
	var travel: Tween = create_tween()
	travel.tween_property(bullet, "global_position", result.hit_position, duration).set_trans(Tween.TRANS_LINEAR)
	travel.tween_callback(bullet.queue_free)


func _make_item(uuid: String, definition: ItemDefinition, cell: Vector2i, magazine: int) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = uuid
	item.item_id = definition.item_id
	item.grid_position = cell
	item.dimensions = definition.dimensions
	item.rarity_tier = &"common"
	item.magazine_ammo = magazine
	return item


func _build_resident(data: Dictionary) -> Node3D:
	var resident: CharacterBody3D = CharacterBody3D.new()
	resident.set_script(RESIDENT_SCRIPT)
	resident.set("display_name", String(data["name"]))
	resident.collision_layer = 4
	resident.collision_mask = 0
	resident.name = String(data["name"]).replace(" ", "_").replace("/", "_")
	resident.position = data["position"]
	var body_shape: CapsuleShape3D = CapsuleShape3D.new()
	body_shape.radius = 0.32
	body_shape.height = 1.8
	var body_collision: CollisionShape3D = CollisionShape3D.new()
	body_collision.name = "CollisionShape3D"
	body_collision.position.y = 0.9
	body_collision.shape = body_shape
	resident.add_child(body_collision)
	var visuals: Node3D = Node3D.new()
	visuals.name = "Visuals"
	resident.add_child(visuals)
	var model_scene: PackedScene = load(String(data["model"])) as PackedScene
	if model_scene == null:
		push_error("Night Market resident model failed to load: %s" % String(data["model"]))
	else:
		var character_model: Node3D = model_scene.instantiate() as Node3D
		character_model.name = "CharacterModel"
		visuals.add_child(character_model)
		_play_character_clip(character_model, "idle")
	var nameplate: Label3D = Label3D.new()
	nameplate.name = "Nameplate"
	nameplate.text = String(data["name"])
	nameplate.position = Vector3(0.0, 2.05, 0.0)
	nameplate.font_size = 30
	nameplate.outline_size = 8
	nameplate.modulate = data["accent"]
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	resident.add_child(nameplate)
	return resident


func _play_character_clip(actor: Node, clip_key: String) -> bool:
	var players: Array[Node] = actor.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return false
	var animation_player: AnimationPlayer = players[0] as AnimationPlayer
	for animation_name: StringName in animation_player.get_animation_list():
		if String(animation_name).to_lower().contains(clip_key):
			if animation_player.current_animation != animation_name:
				animation_player.play(animation_name)
			return true
	return false


func _build_neon_wayfinding() -> void:
	_add_neon_sign("NIGHT MARKET // OPEN", Vector3(35.0, 4.0, -54.0), Color("27e8dc"), Vector3(3.7, 0.75, 0.18))
	_add_neon_sign("ECHO RAMEN // 24H", Vector3(39.5, 4.8, -66.0), Color("ff4fa3"), Vector3(3.0, 0.65, 0.18))
	_add_neon_sign("REPAIR / AUGMENTS", Vector3(30.5, 4.4, -69.0), Color("ffb52e"), Vector3(3.2, 0.65, 0.18))
	_add_street_light("MarketCyanLight", Vector3(29.0, 5.5, -57.0), Color("20bbd2"))
	_add_street_light("MarketMagentaLight", Vector3(42.0, 5.5, -68.0), Color("cb3f99"))


func _add_neon_sign(sign_text: String, sign_position: Vector3, glow_color: Color, size: Vector3) -> void:
	var sign_node: Node3D = Node3D.new()
	sign_node.name = sign_text.replace(" ", "_").replace("/", "_")
	sign_node.position = sign_position
	var board: BoxMesh = BoxMesh.new()
	board.size = size
	var board_material: StandardMaterial3D = StandardMaterial3D.new()
	board_material.albedo_color = Color("111821")
	board_material.metallic = 0.25
	board.material = board_material
	var board_instance: MeshInstance3D = MeshInstance3D.new()
	board_instance.mesh = board
	sign_node.add_child(board_instance)
	var lettering: Label3D = Label3D.new()
	lettering.name = "NeonLettering"
	lettering.text = sign_text
	lettering.position.z = size.z * 0.65
	lettering.font_size = 52
	lettering.outline_size = 5
	lettering.modulate = glow_color
	lettering.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_node.add_child(lettering)
	add_child(sign_node)


func _add_street_light(node_name: String, light_position: Vector3, light_color: Color) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = light_color
	light.light_energy = 6.0
	light.omni_range = 28.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = false
	add_child(light)
	_pulsing_lights.append(light)


func _add_interaction_marker(actor: Node3D) -> void:
	var marker: Label3D = Label3D.new()
	marker.name = "InteractionPrompt"
	marker.text = "E  //  TALK"
	marker.position = Vector3(0.0, 2.38, 0.0)
	marker.font_size = 34
	marker.outline_size = 9
	marker.modulate = Color("ffbb42")
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.add_child(marker)


func _register_mover(actor: Node3D, minimum_x: float, maximum_x: float, lane_z: float, speed: float, phase: float) -> void:
	actor.position.z = lane_z
	_movers.append({"actor": actor, "min_x": minimum_x, "max_x": maximum_x, "speed": speed, "direction": 1.0, "phase": phase})


func _add_capsule(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: Material, tilt: Vector3 = Vector3.ZERO) -> void:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	instance.rotation = tilt
	instance.mesh = mesh
	parent.add_child(instance)


func _add_sphere(parent: Node3D, node_name: String, local_position: Vector3, radius: float, material: Material) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	instance.mesh = mesh
	parent.add_child(instance)


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	instance.mesh = mesh
	parent.add_child(instance)
