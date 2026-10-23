extends RefCounted
## CORE-05 checkpoint coordination and native child-process relaunch coverage.

const FIXTURE_PATH: String = "res://tests/scenes/checkpoint_fixture.tscn"
const CONTROLLER_PATH: String = "res://persistence/checkpoint_controller.gd"
const SAVE_DIRECTORY: String = "user://core05_checkpoint"
const SAVE_FILE: String = "user://core05_checkpoint/slot_00.save"
const PLAYER_UUID: String = "00000000-0000-4000-8000-000000000001"
const NPC_UUID: String = "00000000-0000-4000-8000-000000000002"

var _controller: Node
var _store: SaveStore
var _adapters: SnapshotAdapters
var _health: HealthState
var _player: Node3D
var _player_snapshot: PlayerSnapshot
var _registry: EntityRegistry
var _factions: FactionState
var _inventory: GridInventory
var _ammo: AmmoPouch
var _grants: ItemGrants
var _inventory_snapshot: InventorySnapshot
var _weapon_definition: ItemDefinition
var _reward_item: ItemInstance
var _memory: NpcMemory
var _missions: MissionDirector
var _dialogue_snapshot: DialogueSnapshot
var _hack_snapshot: HackSnapshot
var _mission_id: String = ""
var _expected_domains: Dictionary = {}
var _reenter_capture: bool = false
var _reenter_prepare: bool = false
var _nested_save_error: int = OK
var _nested_load_error: int = OK
var _recovery_signal_count: int = 0


func run(check: Callable) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	check.call(ResourceLoader.exists(CONTROLLER_PATH), "checkpoint controller resource exists")
	if not ResourceLoader.exists(CONTROLLER_PATH):
		return
	check.call(ResourceLoader.exists(FIXTURE_PATH), "checkpoint fixture resource exists")
	if not ResourceLoader.exists(FIXTURE_PATH):
		return
	if not _build_fixture():
		check.call(false, "checkpoint dependencies configure")
		return

	_reenter_capture = true
	check.call(_controller.call("save_checkpoint", 0) == OK, "checkpoint saves all participants")
	check.call(_nested_save_error == ERR_BUSY, "nested save is rejected while a save is active")
	check.call(_has_no_node_values(_registry.snapshot_records()) and _has_no_node_values(_expected_domains), "checkpoint fixture snapshot contains data only")

	var child_output: Array = []
	var project_path: String = ProjectSettings.globalize_path("res://")
	var child_exit: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", project_path, "--script", "res://tests/run_tests.gd",
		"--", "--suite", "checkpoint_relaunch_child",
	], child_output, true)
	var child_text: String = "\n".join(PackedStringArray(child_output))
	print(child_text)
	check.call(child_exit == 0 and child_text.contains("PASS: fresh process hydrates checkpoint data"), "fresh Godot process restores the saved checkpoint (exit %d)" % child_exit)

	_mutate_live_state()
	_health.apply_damage(5, "hostile")
	check.call(_matches_checkpoint(), "player death synchronously restores health, equipment and ammo, completed mission/reward, world flags, NPC facts and active hacks")
	var item_count_after_restore: int = _inventory.get_item_count()
	check.call(_grants.grant("checkpoint_loot", _reward_item) and _inventory.get_item_count() == item_count_after_restore, "restoring a checkpoint does not re-award a claimed loot transaction")
	var restored_credits: int = _missions.get_credits()
	check.call(_missions.complete_mission(_mission_id) and _missions.get_credits() == restored_credits, "restoring a completed mission does not award its credits again")

	_mutate_live_state()
	var missing_error: Error = _controller.call("restore_checkpoint", 2)
	check.call(missing_error != OK and _matches_checkpoint() and _recovery_signal_count == 1, "missing checkpoint returns disk error, emits recovery, and restores the last validated state")

	var file: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_string("{")
	file.close()
	_mutate_live_state()
	var corrupt_error: Error = _controller.call("restore_checkpoint", 0)
	check.call(corrupt_error == ERR_INVALID_DATA and _matches_checkpoint() and _recovery_signal_count == 2, "corrupt checkpoint fails safely, emits recovery, and restores without partial state")

	var invalid_candidate: Dictionary = _adapters.capture_snapshot()
	invalid_candidate["domains"]["inventory"]["items"].append(invalid_candidate["domains"]["inventory"]["items"][0].duplicate(true))
	var encoded: Dictionary = _store.call("_encode_value", invalid_candidate)
	var envelope: Dictionary = {"format": SaveStore.FORMAT_ID, "version": str(SaveStore.CURRENT_VERSION), "payload": encoded}
	file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	_mutate_live_state()
	var partial_error: Error = _controller.call("restore_checkpoint", 0)
	check.call(partial_error == ERR_INVALID_DATA and _matches_checkpoint() and _recovery_signal_count == 3, "invalid domain candidate is rejected before any participant partially commits")

	check.call(_controller.call("save_checkpoint", 0) == OK, "checkpoint can be saved again after recovery")
	_mutate_live_state()
	_reenter_prepare = true
	check.call(_controller.call("restore_checkpoint", 0) == OK, "validated checkpoint restore succeeds")
	check.call(_nested_load_error == ERR_BUSY and _matches_checkpoint(), "nested load is rejected without partial state")

	(_controller.get_parent() as Node).queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	_cleanup_test_save()
	_release_fixture_references()


func run_relaunch_child(check: Callable) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	if not _build_fixture():
		check.call(false, "fresh process checkpoint dependencies configure")
		return
	_mutate_live_state()
	var load_error: Error = _controller.call("restore_checkpoint", 0)
	check.call(load_error == OK and _matches_checkpoint(), "fresh process hydrates checkpoint data")
	(_controller.get_parent() as Node).queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	_release_fixture_references()


func _build_fixture() -> bool:
	var fixture: Node3D = (load(FIXTURE_PATH) as PackedScene).instantiate() as Node3D
	(Engine.get_main_loop() as SceneTree).root.add_child(fixture)
	_player = fixture.get_node("PlayerProjection") as Node3D
	_controller = fixture.get_node("CheckpointController")
	_health = HealthState.new(100)
	_health.restore(72, 100)
	_player_snapshot = PlayerSnapshot.new(_player, _health)
	_player.global_position = Vector3(2.0, 0.0, 3.0)
	_registry = EntityRegistry.new()
	_registry.register_entity(PLAYER_UUID, {"door_open": false, "loot_claimed": true})
	_registry.register_entity(NPC_UUID, {"dead": true, "zone_flag": "checkpoint"})
	_registry.register_entity("00000000-0000-4000-8000-000000000032", {"collected": false})
	_factions = FactionState.new(["corpo", "night_market"])
	_factions.set_faction_standing("corpo", 25)
	_factions.set_faction_standing("night_market", 25)
	_setup_domain_owners()
	_expected_domains = _capture_composed_domains()
	_adapters = SnapshotAdapters.new(
		_registry, _factions,
		Callable(_player_snapshot, "capture"), Callable(_player_snapshot, "prepare"), Callable(_player_snapshot, "commit_prepared"),
		_capture_domains, _prepare_domains, _commit_domains,
	)
	_store = SaveStore.new(
		SAVE_DIRECTORY, Callable(_adapters, "capture_snapshot"), Callable(_adapters, "validate_snapshot"), Callable(_adapters, "apply_snapshot"),
	)
	var configured: bool = bool(_controller.call("configure", _store, _adapters, _health, 0))
	_controller.connect("checkpoint_recovered", _on_checkpoint_recovered)
	return configured


func _setup_domain_owners() -> void:
	_weapon_definition = ItemDefinition.new()
	_weapon_definition.item_id = &"checkpoint_pistol"
	_weapon_definition.display_name = "Checkpoint Pistol"
	_weapon_definition.dimensions = Vector2i.ONE
	_weapon_definition.weapon_family = &"pistol"
	_weapon_definition.magazine_capacity = 12
	var reward_definition: ItemDefinition = ItemDefinition.new()
	reward_definition.item_id = &"checkpoint_scrap"
	reward_definition.display_name = "Reward Scrap"
	reward_definition.dimensions = Vector2i.ONE
	var definitions: Dictionary = {"checkpoint_pistol": _weapon_definition, "checkpoint_scrap": reward_definition}
	_inventory = GridInventory.new(Vector2i(4, 3))
	_ammo = AmmoPouch.new()
	_grants = ItemGrants.new(_inventory, definitions)
	_inventory_snapshot = InventorySnapshot.new(_inventory, _ammo, definitions, _grants)
	var weapon: ItemInstance = _make_item("00000000-0000-4000-8000-000000000003", _weapon_definition, Vector2i.ZERO, 7)
	_inventory.try_add_item(weapon)
	var equipment: EquipmentService = EquipmentService.new(_inventory, definitions, _ammo)
	equipment.equip_item(weapon.uuid, "primary")
	_reward_item = _make_item("00000000-0000-4000-8000-000000000004", reward_definition, Vector2i(1, 0))
	_grants.grant("checkpoint_loot", _reward_item)
	_ammo.add_ammo("pistol", 23)
	var template: MissionTemplate = load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate
	_missions = MissionDirector.new()
	_missions.configure([template], _registry, _factions, func(_uuid: String) -> bool: return true)
	var offered: Dictionary = _missions.offer_mission("retrieve_signal_cache")
	_mission_id = String(offered.get("mission_id", ""))
	_missions.accept_mission(_mission_id)
	_missions.activate_mission(_mission_id)
	_registry.try_commit_state_delta("00000000-0000-4000-8000-000000000032", {"collected": true})
	_missions.complete_mission(_mission_id)
	_memory = NpcMemory.new()
	_memory.configure({"blacksite_door_code": "The access code is 7419."}, func(_npc_id: String, _fact_id: String, _source: String, _evidence_id: String) -> bool: return true)
	_memory.record_fact("fixer_mara", "blacksite_door_code", "witnessed", "world_event_01")
	_dialogue_snapshot = DialogueSnapshot.new()
	_dialogue_snapshot.configure(_memory, _missions, _factions)
	_hack_snapshot = HackSnapshot.new()
	var active_hack: Dictionary = _hack_snapshot.prepare_domain({"active_hacks": [{
		"target_uuid": NPC_UUID,
		"ability_id": HackDefinition.Ability.DISABLE_CAMERA,
		"remaining_seconds": 4.5,
		"chunk_id": "night_market",
	}]})
	_hack_snapshot.commit_domain(active_hack)


func _make_item(uuid: String, definition: ItemDefinition, position: Vector2i, magazine: int = 0) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = uuid
	item.item_id = definition.item_id
	item.grid_position = position
	item.dimensions = definition.dimensions
	item.rarity_tier = &"common"
	item.magazine_ammo = magazine
	return item


func _mutate_live_state() -> void:
	_health.restore(5, 100)
	_player.global_position = Vector3(99.0, 5.0, -20.0)
	_registry.try_commit_state_delta(PLAYER_UUID, {"door_open": true, "loot_claimed": false})
	_registry.try_commit_state_delta(NPC_UUID, {"dead": false, "zone_flag": "after_checkpoint"})
	_registry.try_commit_state_delta("00000000-0000-4000-8000-000000000032", {"collected": false})
	_factions.set_faction_standing("corpo", -80)
	_inventory.remove_item("00000000-0000-4000-8000-000000000003")
	_inventory.remove_item("00000000-0000-4000-8000-000000000004")
	_ammo.consume_ammo("pistol", _ammo.get_ammo("pistol"))
	var mission_candidate: Dictionary = _missions.capture_snapshot()
	mission_candidate["credits"] = 0
	mission_candidate["missions"][0]["state"] = "active"
	mission_candidate["missions"][0]["reward_claimed"] = false
	var mission_prepared: Dictionary = _missions.prepare_snapshot(mission_candidate)
	if mission_prepared.get("ok", false):
		_missions.commit_prepared_snapshot(mission_prepared["prepared"])
	var empty_memory: Dictionary = {"version": NpcMemory.SNAPSHOT_VERSION, "npcs": []}
	var memory_prepared: Dictionary = _memory.prepare_snapshot(empty_memory)
	if memory_prepared.get("ok", false):
		_memory.commit_prepared_snapshot(memory_prepared["prepared"])
	var empty_hacks: Dictionary = _hack_snapshot.prepare_domain({"active_hacks": []})
	_hack_snapshot.commit_domain(empty_hacks)


func _matches_checkpoint() -> bool:
	return _health.current_hp == 72 \
		and _player.global_position.is_equal_approx(Vector3(2.0, 0.0, 3.0)) \
		and _registry.get_entity_state(PLAYER_UUID) == {"door_open": false, "loot_claimed": true} \
		and _registry.get_entity_state(NPC_UUID) == {"dead": true, "zone_flag": "checkpoint"} \
		and _factions.get_faction_standing("corpo") == 25 \
		and _capture_composed_domains() == _expected_domains


func _capture_domains() -> Dictionary:
	if _reenter_capture:
		_reenter_capture = false
		_nested_save_error = _controller.call("save_checkpoint", 1)
	return _capture_composed_domains()


func _prepare_domains(candidate: Variant) -> Dictionary:
	if _reenter_prepare:
		_reenter_prepare = false
		_nested_load_error = _controller.call("restore_checkpoint", 0)
	if typeof(candidate) != TYPE_DICTIONARY or not candidate.has("inventory") or not candidate.has("npc_memory") or not candidate.has("missions") or not candidate.has("active_hacks"):
		return {"ok": false}
	var dialogue_plan: Dictionary = _dialogue_snapshot.prepare_domains(candidate)
	var inventory_plan: Dictionary = _inventory_snapshot.prepare_snapshot(candidate["inventory"])
	var hack_plan: Dictionary = _hack_snapshot.prepare_domain({"active_hacks": candidate["active_hacks"]})
	if not dialogue_plan.get("ok", false) or not inventory_plan.get("ok", false) or not hack_plan.get("ok", false):
		return {"ok": false}
	return {"ok": true, "prepared": {"dialogue": dialogue_plan["prepared"], "inventory": inventory_plan["prepared"], "hacking": hack_plan}}


func _commit_domains(prepared: Dictionary) -> void:
	_dialogue_snapshot.commit_prepared_domains(prepared["dialogue"])
	_inventory_snapshot.commit_prepared_snapshot(prepared["inventory"])
	_hack_snapshot.commit_domain(prepared["hacking"])


func _capture_composed_domains() -> Dictionary:
	var result: Dictionary = _dialogue_snapshot.capture_domains()
	result["inventory"] = _inventory_snapshot.capture_snapshot()
	result["active_hacks"] = _hack_snapshot.capture_domain()["active_hacks"]
	return result


func _on_checkpoint_recovered(_slot: int, _disk_error: Error) -> void:
	_recovery_signal_count += 1


func _cleanup_test_save() -> void:
	var path: String = ProjectSettings.globalize_path(SAVE_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var directory: String = ProjectSettings.globalize_path(SAVE_DIRECTORY)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)


func _release_fixture_references() -> void:
	_controller = null
	_store = null
	_adapters = null
	_health = null
	_player = null
	_player_snapshot = null
	_registry = null
	_factions = null
	_inventory = null
	_ammo = null
	_grants = null
	_inventory_snapshot = null
	_weapon_definition = null
	_reward_item = null
	_memory = null
	_missions = null
	_dialogue_snapshot = null
	_hack_snapshot = null


func _has_no_node_values(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT:
			return value is not Node
		TYPE_ARRAY:
			for child: Variant in value:
				if not _has_no_node_values(child):
					return false
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not _has_no_node_values(value[key]):
					return false
	return true
