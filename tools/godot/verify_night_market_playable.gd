extends SceneTree

const MAIN_SCENE_PATH := "res://world/districts/night_market/night_market.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var configured_main: String = String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(configured_main == MAIN_SCENE_PATH, "Night Market is configured as the game startup scene")
	_check(int(ProjectSettings.get_setting("display/window/size/mode", -1)) == 3,
		"The project starts in fullscreen mode")
	var packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	_check(packed != null, "Night Market startup scene loads")
	if packed == null:
		_finish()
		return
	var game: Node3D = packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	var player: CharacterBody3D = game.get_node_or_null("Player") as CharacterBody3D
	_check(player != null, "Existing first-person player is present")
	_check(player != null and bool(player.get("capture_mouse_on_start")),
		"Mouse-look capture is enabled for startup")
	var camera: Camera3D = game.get_node_or_null("Player/Head/Camera3D") as Camera3D
	_check(camera != null and camera.current, "Player camera is active")
	var hud: PlayerHUD = game.get_node_or_null("NightMarketRuntime/PlayerHUDLayer/PlayerHUD") as PlayerHUD
	_check(hud != null and hud.get_health_text() == "VITAL LINK   100 / 100" and hud.get_ammo_text() == "12   /   48",
		"Existing combat HUD is configured with starter health and ammunition")
	var inventory_ui: InventoryUI = game.get_node_or_null("NightMarketRuntime/InventoryLayer/InventoryUI") as InventoryUI
	_check(inventory_ui != null and inventory_ui.inventory != null and inventory_ui.equipment != null,
		"Starter inventory UI is configured with the pistol and field kit")
	if inventory_ui != null and player != null:
		var tab_event: InputEventKey = InputEventKey.new()
		tab_event.keycode = KEY_TAB
		tab_event.pressed = true
		Input.parse_input_event(tab_event)
		await process_frame
		_check(inventory_ui.visible and not player.can_act,
			"Tab opens inventory and releases first-person control")
		var escape_event: InputEventKey = InputEventKey.new()
		escape_event.keycode = KEY_ESCAPE
		escape_event.pressed = true
		Input.parse_input_event(escape_event)
		await process_frame
		_check(not inventory_ui.visible and player.can_act,
			"Escape closes inventory and restores first-person control")
	var resident_count: int = 0
	var runtime: Node = game.get_node_or_null("NightMarketRuntime")
	if runtime != null:
		for resident: Node in runtime.get_children():
			if resident.get_node_or_null("Nameplate") is Label3D:
				resident_count += 1
	_check(resident_count >= 3, "Named street residents are present")
	var dialogue_ui: DialogueUI = runtime.get("dialogue_ui") as DialogueUI if runtime != null else null
	var orchestrator: DialogueOrchestrator = runtime.get("dialogue_orchestrator") as DialogueOrchestrator if runtime != null else null
	var actions: WeaponStateMachine = runtime.get("actions") as WeaponStateMachine if runtime != null else null
	_check(dialogue_ui != null and orchestrator != null, "Mara dialogue UI and local-model orchestrator are configured")
	var guard: TacticalAgent = game.get_node_or_null("NightMarketRuntime/SecurityGoon") as TacticalAgent
	_check(guard != null and guard.is_configured() and guard.get_node_or_null("CollisionShape3D") != null,
		"Security NPC is a configured collidable damage target")
	var collision: StaticBody3D = game.get_node_or_null("CollisionBuilder/DistrictCollision") as StaticBody3D
	_check(collision != null, "Walkable district collision body is present")
	var shapes: Array = collision.find_children("*", "CollisionShape3D", true, false) if collision != null else []
	_check(shapes.size() >= 40, "Ground and structural blocker collision shapes were generated")
	if player == null or collision == null:
		_finish()
		return
	for _frame in 4:
		await physics_frame
	_check(player.global_position.y < 0.2, "Player starts at street-ground height")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(35.0, 1.0, -44.0), Vector3(35.0, 1.0, -20.0), 1)
	var wall_hit: Dictionary = space.intersect_ray(ray)
	_check(not wall_hit.is_empty() and wall_hit.get("collider") == collision,
		"Structural mesh collision blocks the path into a building")
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for _frame in 48:
		await physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.z < start.z - 0.7, "Player walks forward through the street")
	_check(player.global_position.y < 0.5, "Player remains grounded while moving")
	_check(player.is_on_floor(), "Player remains grounded according to physics")
	var movers: Array = runtime.get("_movers") as Array if runtime != null else []
	var mover: Node3D = movers[0].get("actor") as Node3D if not movers.is_empty() else null
	var initial_mover_x: float = mover.global_position.x if mover != null else 0.0
	await create_timer(1.0).timeout
	_check(mover != null and absf(mover.global_position.x - initial_mover_x) > 0.25,
		"An ambient pedestrian visibly walks along the street")
	var ai_response: Array[bool] = [false]
	var ai_fallback: Array[bool] = [true]
	var ai_text: Array[String] = [""]
	if dialogue_ui != null and orchestrator != null:
		var talk_event: InputEventKey = InputEventKey.new()
		talk_event.keycode = KEY_E
		talk_event.pressed = true
		Input.parse_input_event(talk_event)
		await process_frame
		_check(dialogue_ui.visible and not player.can_act, "E opens Mara's dialogue and locks player control")
		orchestrator.dialogue_ready.connect(func(_npc_id: String, _conversation_id: String, _generation: int,
			response: LLMResponse, used_fallback: bool) -> void:
			ai_response[0] = response != null
			ai_fallback[0] = used_fallback
			ai_text[0] = response.dialogue_text if response != null else "")
		var prompt: LineEdit = dialogue_ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt") as LineEdit
		prompt.text = "Reply with one short greeting."
		dialogue_ui.call("_submit_prompt")
		var deadline_msec: int = Time.get_ticks_msec() + 45000
		while not ai_response[0] and Time.get_ticks_msec() < deadline_msec:
			await create_timer(0.25).timeout
		_check(ai_response[0] and not ai_fallback[0] and not ai_text[0].strip_edges().is_empty(),
			"Mara displays a validated response from the installed local Ollama model")
		var provider: OllamaProvider = runtime.get_node_or_null("LocalOllamaProvider") as OllamaProvider
		if provider != null:
			provider.model_name = "night_market_missing_fallback_probe"
			ai_response[0] = false
			ai_fallback[0] = false
			ai_text[0] = ""
			prompt.text = "Can you still help if your comms are offline?"
			dialogue_ui.call("_submit_prompt")
			deadline_msec = Time.get_ticks_msec() + 15000
			while not ai_response[0] and Time.get_ticks_msec() < deadline_msec:
				await create_timer(0.25).timeout
		_check(ai_response[0] and ai_fallback[0] and not ai_text[0].strip_edges().is_empty(),
			"Unavailable model displays Mara's authored fallback")
		dialogue_ui.close_dialogue()
		await process_frame
		_check(not dialogue_ui.visible and player.can_act, "Closing Mara's dialogue restores player control")
	if guard != null and actions != null:
		var starting_ammo: String = hud.get_ammo_text() if hud != null else ""
		var first_hit: HitResult = actions.fire_current_weapon()
		_check(first_hit.fired and first_hit.target_node == guard and first_hit.damage_applied > 0,
			"Aimed starter pistol hits and damages the security NPC")
		var bullet: Node3D = runtime.get("last_bullet_visual") as Node3D
		var bullet_start: Vector3 = bullet.global_position if bullet != null else Vector3.ZERO
		await create_timer(0.04).timeout
		_check(bullet != null and is_instance_valid(bullet) and bullet.global_position.distance_to(bullet_start) > 0.1,
			"Pistol shot spawns a visible projectile that travels toward its hit point")
		for _shot in 3:
			await create_timer(0.22).timeout
			actions.fire_current_weapon()
		_check(guard.state == TacticalAgent.AIState.DEAD and guard.health_state.is_dead(), "Lethal pistol damage defeats the guard")
		_check((guard.get_node("SecurityStatus") as Label3D).text == "SECURITY // DOWN", "Defeated guard has a visible down state")
		_check(hud != null and hud.get_ammo_text() != starting_ammo, "Firing visibly consumes the pistol magazine")
		var reload_token: int = actions.begin_reload()
		_check(reload_token > 0, "Reload starts after defeating the guard")
		await create_timer(0.65).timeout
		_check(actions.complete_reload(reload_token), "Reload transfers reserve ammo into the magazine")
		var aim_camera: Camera3D = game.get_node("Player/Head/Camera3D") as Camera3D
		var civilians: Array[NightMarketResident] = []
		for child: Node in runtime.get_children():
			if child is NightMarketResident:
				civilians.append(child as NightMarketResident)
		_check(civilians.size() == 3, "Mara, the vendor and pedestrian have individual damageable NPC bodies")
		for civilian: NightMarketResident in civilians:
			var aim_point: Vector3 = civilian.global_position + Vector3(0.0, 0.95, 0.0)
			aim_camera.look_at(aim_point, Vector3.UP)
			await create_timer(0.22).timeout
			await process_frame
			var civilian_hit: HitResult = actions.fire_current_weapon()
			_check(civilian_hit.fired and civilian_hit.target_node == civilian
				and civilian_hit.damage_applied > 0 and civilian.health_state.current_hp < civilian.health_state.max_hp,
				"Starter pistol hits and damages %s" % civilian.display_name)
			for _shot in 3:
				if not civilian.is_alive:
					break
				await create_timer(0.22).timeout
				aim_point = civilian.global_position + Vector3(0.0, 0.95, 0.0)
				aim_camera.look_at(aim_point, Vector3.UP)
				actions.fire_current_weapon()
			await process_frame
			_check(not civilian.is_alive and (civilian.get_node("Nameplate") as Label3D).text.ends_with("// DOWN"),
				"Lethal pistol damage visibly downs %s" % civilian.display_name)
			_check((civilian.get_node("CollisionShape3D") as CollisionShape3D).disabled,
				"Down NPC collider is removed for %s" % civilian.display_name)
			if civilian == runtime.get("mara"):
				_check(runtime.call("_resolve_dialogue_actor", "mara_vega") == null,
					"Down Mara is unavailable to the dialogue authority")
	print("WORLD13_PLAYABLE player_position=%s collision_shapes=%d residents=%d guard_hp=%d model_fallback=%s" % [
		player.global_position, shapes.size(), resident_count, guard.health_state.current_hp if guard != null else -1,
		str(ai_fallback[0])])
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("WORLD13_PLAYABLE PASS")
		quit(0)
	else:
		print("WORLD13_PLAYABLE FAIL count=%d" % failures.size())
		quit(1)
