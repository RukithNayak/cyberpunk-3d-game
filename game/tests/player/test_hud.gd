extends RefCounted


class ShotStub extends WeaponController:
	func fire_weapon(_stats: Resource) -> HitResult:
		var result: HitResult = HitResult.new()
		result.fired = true
		return result


class PlayerStub extends Node3D:
	var is_alive: bool = true
	var can_act: bool = true
	var reduced_camera_shake: bool = false
	var settings: PlayerInputSettings = PlayerInputSettings.new("user://player_hud_pause_test.json")
	var locks: Dictionary = {}
	var mouse_resumed: bool = false
	var applied_settings: PlayerInputSettings

	func can_fire() -> bool:
		return is_alive and can_act

	func set_reduced_camera_shake(enabled: bool) -> void:
		reduced_camera_shake = enabled

	func add_control_lock(lock_id: StringName) -> void:
		locks[lock_id] = true
		can_act = false

	func remove_control_lock(lock_id: StringName) -> void:
		locks.erase(lock_id)
		can_act = locks.is_empty()

	func resume_mouse_capture() -> bool:
		mouse_resumed = locks.is_empty()
		return mouse_resumed

	func get_settings() -> PlayerInputSettings:
		return settings

	func apply_settings(value: PlayerInputSettings) -> void:
		settings = value
		applied_settings = value


func run(check: Callable) -> void:
	var hud_scene: PackedScene = load("res://ui/player_hud.tscn") as PackedScene
	check.call(hud_scene != null, "gameplay HUD scene is available")
	var pause_scene: PackedScene = load("res://ui/pause_settings.tscn") as PackedScene
	check.call(pause_scene != null, "pause/settings scene is available")
	if hud_scene == null:
		return
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = &"hud_pistol"
	definition.display_name = "HUD Pistol"
	definition.weapon_family = &"pistol"
	definition.magazine_capacity = 6
	definition.base_stats = {"damage": 22.0, "fire_rate_per_second": 6.0, "range_m": 30.0}
	var inventory: GridInventory = GridInventory.new(Vector2i(3, 2))
	var pouch: AmmoPouch = AmmoPouch.new(100)
	var item: ItemInstance = ItemInstance.new()
	item.uuid = "00000000-0000-4000-8000-000000000001"
	item.item_id = definition.item_id
	item.grid_position = Vector2i.ZERO
	item.dimensions = Vector2i.ONE
	item.rarity_tier = &"common"
	item.magazine_ammo = 2
	check.call(inventory.try_add_item(item) and pouch.add_ammo("pistol", 8), "HUD model weapon and reserve are valid")
	var equipment: EquipmentService = EquipmentService.new(inventory, {"hud_pistol": definition}, pouch)
	equipment.equip_item(item.uuid)
	var health: HealthState = HealthState.new(100)
	var player: PlayerStub = PlayerStub.new()
	var weapon: ShotStub = ShotStub.new()
	var actions: WeaponStateMachine = WeaponStateMachine.new()
	actions.configure(player, weapon, equipment, ConsumableService.new(inventory, {"hud_pistol": definition}, health), health)
	var hud: PlayerHUD = hud_scene.instantiate() as PlayerHUD
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	tree.root.add_child(actions)
	tree.root.add_child(hud)
	await tree.process_frame
	hud.configure(health, actions, equipment, player)
	check.call(not tree.paused and not hud.pause_menu.is_open(), "pause menu starts closed")
	var pause_event: InputEventAction = InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud.pause_menu.call("_unhandled_input", pause_event)
	check.call(tree.paused and hud.pause_menu.is_open() and not player.can_act and player.locks.has(&"pause_menu"), "pause locks gameplay and pauses the scene tree")
	hud.pause_menu.show_settings()
	check.call(hud.pause_menu.is_settings_visible() and hud.get_viewport().gui_get_focus_owner() == hud.pause_menu._fov_slider, "settings opens with keyboard focus on the first control")
	hud.pause_menu._fov_slider.value = 105.0
	hud.pause_menu._sensitivity_slider.value = 0.004
	hud.pause_menu._invert_toggle.button_pressed = true
	hud.pause_menu._on_invert_toggled(true)
	var persisted_settings: PlayerInputSettings = PlayerInputSettings.new("user://player_hud_pause_test.json")
	check.call(hud.pause_menu.is_settings_visible() and persisted_settings.load_settings() and persisted_settings.get_fov() == 105.0 and persisted_settings.get_sensitivity() == 0.004 and persisted_settings.get_invert_look() and player.applied_settings == player.settings, "pause settings persist and apply camera options")
	hud.pause_menu.resume_game()
	check.call(not tree.paused and player.can_act and not player.locks.has(&"pause_menu") and player.mouse_resumed, "resume releases pause lock and restores mouse capture")
	check.call(hud.get_health_text().contains("100 / 100"), "HUD reads initial health from HealthState")
	check.call(hud.get_ammo_text().contains("02") and hud.get_ammo_text().contains("08") and hud.get_crosshair_text() == "+", "HUD reads equipped magazine/reserve and presents center crosshair")
	hud.call("_toggle_camera_comfort")
	check.call(hud.is_camera_shake_reduced() and player.reduced_camera_shake, "HUD comfort toggle reduces player camera recoil")
	health.apply_damage(15, "hud_test")
	check.call(hud.get_health_text().contains("085 / 100"), "HUD refreshes from authoritative health signal")
	var fired: HitResult = actions.fire_current_weapon()
	check.call(fired.fired and hud.get_feedback_event_count() == 1 and hud.get_ammo_text().contains("01"), "one accepted shot produces one feedback event and updates magazine")
	var reload_token: int = actions.begin_reload()
	check.call(reload_token > 0 and actions.complete_reload(reload_token) and hud.get_ammo_text().contains("06") and hud.get_ammo_text().contains("03"), "HUD refreshes after transactional reload")
	health.heal(10)
	check.call(hud.get_health_text().contains("095 / 100"), "HUD refreshes after healing")
	health.restore(75, 100)
	check.call(hud.get_health_text().contains("075 / 100"), "HUD reflects checkpoint health restoration")
	tree.root.remove_child(hud)
	hud.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://player_hud_pause_test.json"))
	tree.root.remove_child(actions)
	actions.free()
	tree.root.remove_child(player)
	player.free()
	weapon.free()
