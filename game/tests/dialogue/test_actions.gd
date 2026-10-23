extends RefCounted

const RETRIEVAL_TARGET_UUID: String = "00000000-0000-4000-8000-000000000032"


class ActionFixture extends RefCounted:
	var actors: Dictionary = {}
	var player: Node3D
	var stock_available: bool = true
	var facts_available: Dictionary = {"fixer_mara|old_tunnel": true}
	var trade_calls: Array[Dictionary] = []
	var disclosure_calls: Array[Dictionary] = []
	var entitlements: Dictionary = {}

	func resolve_actor(npc_id: String) -> Variant:
		return actors.get(npc_id)

	func resolve_player() -> Variant:
		return player

	func validate_stock(inventory_id: String, _npc_id: String) -> bool:
		return stock_available and inventory_id == "mara_stock"

	func open_trade(inventory_id: String, npc_id: String, transaction_id: String) -> bool:
		trade_calls.append({"inventory_id": inventory_id, "npc_id": npc_id, "transaction_id": transaction_id})
		return true

	func has_fact(npc_id: String, fact_id: String) -> bool:
		return facts_available.get("%s|%s" % [npc_id, fact_id], false)

	func disclose_fact(npc_id: String, fact_id: String, transaction_id: String) -> bool:
		disclosure_calls.append({"npc_id": npc_id, "fact_id": fact_id, "transaction_id": transaction_id})
		return true

	func resolve_item_entitlement(npc_id: String, item_id: String) -> Variant:
		return entitlements.get("%s|%s" % [npc_id, item_id])


class CombatTarget extends Node3D:
	func apply_damage(_amount: int, _source_faction: String) -> void:
		pass


func run(check: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	var dispatcher_script: Script = load("res://features/dialogue/action_dispatcher.gd") as Script
	check.call(dispatcher_script != null, "guarded ActionDispatcher implementation is available")
	if dispatcher_script == null:
		return
	await _test_allowed_and_rejected_actions(check, tree, dispatcher_script)
	await _test_generation_actor_and_conversation_guards(check, tree, dispatcher_script)
	await _test_fight_transition(check, tree, dispatcher_script)
	await _test_full_inventory_entitlement(check, tree, dispatcher_script)


func _test_allowed_and_rejected_actions(check: Callable, tree: SceneTree, dispatcher_script: Script) -> void:
	var fixture: ActionFixture = ActionFixture.new()
	var actors: Dictionary = {}
	var fixer: Node3D = Node3D.new()
	fixer.name = "FixerMara"
	tree.root.add_child(fixer)
	actors["fixer_mara"] = fixer
	fixture.actors = actors
	fixture.player = Node3D.new()
	fixture.player.name = "Player"
	fixture.player.position = Vector3(0.0, 0.0, -4.0)
	tree.root.add_child(fixture.player)
	await tree.physics_frame

	var registry: EntityRegistry = EntityRegistry.new()
	registry.register_entity(RETRIEVAL_TARGET_UUID, {"collected": false})
	var factions: FactionState = FactionState.new(["night_market", "player", "security", "corporate"])
	var template: MissionTemplate = load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate
	var mission_director: MissionDirector = MissionDirector.new()
	check.call(mission_director.configure([template], registry, factions, func(_uuid: String) -> bool: return true), "action fixture configures authoritative mission service")

	var inventory: GridInventory = GridInventory.new(Vector2i(10, 6))
	var signal_key_definition: ItemDefinition = _item_definition("signal_key", "Signal Key", Vector2i.ONE)
	var backup_key_definition: ItemDefinition = _item_definition("backup_signal_key", "Backup Signal Key", Vector2i.ONE)
	var bulk_definition: ItemDefinition = _item_definition("bulk_cache", "Bulk Cache", Vector2i(10, 6))
	var definitions: Dictionary = {
		"signal_key": signal_key_definition,
		"backup_signal_key": backup_key_definition,
		"bulk_cache": bulk_definition,
	}
	var grants: ItemGrants = ItemGrants.new(inventory, definitions)
	fixture.entitlements["fixer_mara|signal_key"] = _item_blueprint("93000000-0000-4000-8000-000000000101", "signal_key", Vector2i.ONE)
	fixture.entitlements["fixer_mara|backup_signal_key"] = _item_blueprint("93000000-0000-4000-8000-000000000102", "backup_signal_key", Vector2i.ONE)

	var dispatcher: Object = dispatcher_script.new()
	var policy: Dictionary = {
		"resolve_actor": Callable(fixture, "resolve_actor"),
		"mission_director": mission_director,
		"mission_permissions": {"fixer_mara": ["retrieve_signal_cache"]},
		"merchant_inventory_owners": {"mara_stock": "fixer_mara"},
		"validate_merchant_stock": Callable(fixture, "validate_stock"),
		"open_trade": Callable(fixture, "open_trade"),
		"faction_state": factions,
		"faction_acceptance_rules": {"night_market": {"allowed_npc_ids": ["fixer_mara"], "minimum_standing": 0, "accepted_standing": 50}},
		"fight_allowed_npc_ids": ["security_boss"],
		"resolve_player": Callable(fixture, "resolve_player"),
		"player_faction_id": "player",
		"fact_available": Callable(fixture, "has_fact"),
		"commit_disclosure": Callable(fixture, "disclose_fact"),
		"item_grants": grants,
		"resolve_item_entitlement": Callable(fixture, "resolve_item_entitlement"),
	}
	check.call(bool(dispatcher.call("configure", policy)), "dispatcher accepts explicit authority adapters and allowlists")

	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_mara_1")), "dispatcher binds a live actor to a conversation")
	var offer_result: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_1", 1, "offer_mission", {"template_id": "retrieve_signal_cache"})
	check.call(offer_result.get("ok", false) and (mission_director.get_mission(offer_result["mission"]["mission_id"]).get("state") == "offered"), "authorized mission proposal calls MissionDirector to create an offered job")
	var offer_duplicate: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_1", 1, "offer_mission", {"template_id": "retrieve_signal_cache"})
	check.call(offer_duplicate.get("duplicate", false) and mission_director.capture_snapshot()["missions"].size() == 1, "duplicate mission response is served from transaction cache without a second commit")
	var invented_offer: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_1", 2, "offer_mission", {"template_id": "invented_job"})
	check.call(not invented_offer.get("ok", false) and invented_offer.get("reason") == "mission_not_authorized", "invented mission template is rejected before MissionDirector mutation")

	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_mara_2")), "dispatcher replaces the active conversation")
	var trade_result: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_2", 1, "initiate_trade", {"inventory_id": "mara_stock"})
	check.call(trade_result.get("ok", false) and fixture.trade_calls.size() == 1, "authorized live merchant stock opens the trade adapter")
	var trade_duplicate: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_2", 1, "initiate_trade", {"inventory_id": "mara_stock"})
	check.call(trade_duplicate.get("duplicate", false) and fixture.trade_calls.size() == 1, "duplicate trade response does not open a second trade")
	fixture.stock_available = false
	var stale_stock: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_2", 2, "initiate_trade", {"inventory_id": "mara_stock"})
	check.call(not stale_stock.get("ok", false) and fixture.trade_calls.size() == 1, "trade rechecks current stock and rejects a stale merchant inventory")
	var invented_stock: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_2", 3, "initiate_trade", {"inventory_id": "other_stock"})
	check.call(not invented_stock.get("ok", false) and invented_stock.get("reason") == "merchant_not_authorized", "invented merchant inventory is rejected")
	fixture.stock_available = true

	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_mara_3")), "faction action receives a fresh conversation")
	var faction_result: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_3", 1, "accept_into_faction", {"faction_id": "night_market"})
	check.call(faction_result.get("ok", false) and factions.get_faction_standing("night_market") >= 50 and factions.is_allied("night_market"), "authored faction rule commits the allowed allied standing")
	var unauthorized_faction: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_3", 2, "accept_into_faction", {"faction_id": "corporate"})
	check.call(not unauthorized_faction.get("ok", false) and factions.get_faction_standing("corporate") == 0, "faction without an authored eligibility rule cannot mutate standing")

	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_mara_4")), "fact disclosure receives a fresh conversation")
	var disclosure: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_4", 1, "disclose_fact", {"fact_id": "old_tunnel"})
	check.call(disclosure.get("ok", false) and fixture.disclosure_calls.size() == 1, "known disclosable fact reaches the authoritative fact commit adapter")
	var invented_fact: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_4", 2, "disclose_fact", {"fact_id": "secret_archive"})
	check.call(not invented_fact.get("ok", false) and fixture.disclosure_calls.size() == 1, "unknown fact is rejected without disclosure")

	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_mara_5")), "item action receives a fresh conversation")
	var item_grant: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_5", 1, "give_item", {"item_id": "signal_key"})
	check.call(item_grant.get("ok", false) and not item_grant.get("pending", true) and inventory.get_item_count() == 1, "preauthorized item blueprint is granted through ItemGrants")
	var item_duplicate: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_5", 1, "give_item", {"item_id": "signal_key"})
	check.call(item_duplicate.get("duplicate", false) and inventory.get_item_count() == 1, "duplicate item response cannot duplicate its inventory reward")
	var invented_item: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_mara_5", 2, "give_item", {"item_id": "prototype_weapon"})
	check.call(not invented_item.get("ok", false) and invented_item.get("reason") == "item_not_entitled", "invented item without a live entitlement is rejected")

	var tampered: LLMResponse = _response("give_item", {"item_id": "signal_key", "count": 999})
	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_mara_tamper")), "tamper test binds a live conversation")
	var tampered_result: Dictionary = dispatcher.call("dispatch_response", "fixer_mara", "talk_mara_tamper", 1, tampered)
	check.call(not tampered_result.get("ok", false) and inventory.get_item_count() == 1, "dispatcher revalidates exact action parameter keys before any commit")

	dispatcher.call("end_conversation", "fixer_mara", "talk_mara_tamper")
	fixer.queue_free()
	fixture.player.queue_free()
	await tree.process_frame


func _test_generation_actor_and_conversation_guards(check: Callable, tree: SceneTree, dispatcher_script: Script) -> void:
	var fixture: ActionFixture = ActionFixture.new()
	var actor: Node3D = Node3D.new()
	tree.root.add_child(actor)
	fixture.actors = {"fixer_mara": actor}
	fixture.facts_available["fixer_mara|old_tunnel"] = true
	var dispatcher: Object = dispatcher_script.new()
	check.call(bool(dispatcher.call("configure", {"resolve_actor": Callable(fixture, "resolve_actor"), "fact_available": Callable(fixture, "has_fact"), "commit_disclosure": Callable(fixture, "disclose_fact")})), "minimal dispatcher configuration permits only supplied actions")
	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_generation_a")), "dispatcher begins first guarded conversation")
	var first: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_generation_a", 5, "disclose_fact", {"fact_id": "old_tunnel"})
	var stale: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_generation_a", 4, "disclose_fact", {"fact_id": "old_tunnel"})
	check.call(first.get("ok", false) and not stale.get("ok", false) and stale.get("reason") == "stale_generation" and fixture.disclosure_calls.size() == 1, "out-of-order generation cannot replay a prior action")
	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "talk_generation_b")), "conversation replacement invalidates previous identity")
	var stale_conversation: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_generation_a", 6, "disclose_fact", {"fact_id": "old_tunnel"})
	check.call(not stale_conversation.get("ok", false) and stale_conversation.get("reason") == "stale_conversation" and fixture.disclosure_calls.size() == 1, "response from a replaced conversation cannot commit")
	fixture.actors.erase("fixer_mara")
	var missing_actor: Dictionary = _dispatch(dispatcher, "fixer_mara", "talk_generation_b", 1, "disclose_fact", {"fact_id": "old_tunnel"})
	check.call(not missing_actor.get("ok", false) and missing_actor.get("reason") == "actor_unavailable" and fixture.disclosure_calls.size() == 1, "actor unload invalidates a response before its commit adapter runs")
	actor.queue_free()
	await tree.process_frame


func _test_fight_transition(check: Callable, tree: SceneTree, dispatcher_script: Script) -> void:
	var fixture: ActionFixture = ActionFixture.new()
	var actors: Dictionary = {}
	var factions: FactionState = FactionState.new(["security", "player"])
	factions.set_faction_standing("security", -50)
	var scene: PackedScene = load("res://features/npcs/goon.tscn") as PackedScene
	var agent: TacticalAgent = scene.instantiate() as TacticalAgent
	agent.process_ai = false
	agent.position = Vector3(0.0, 0.9, 0.0)
	tree.root.add_child(agent)
	fixture.player = CombatTarget.new()
	fixture.player.position = Vector3(0.0, 0.9, -4.0)
	tree.root.add_child(fixture.player)
	await tree.physics_frame
	check.call(agent.configure(factions, "security"), "fight fixture configures a live tactical actor")
	actors["security_boss"] = agent
	fixture.actors = actors
	var dispatcher: Object = dispatcher_script.new()
	var policy: Dictionary = {
		"resolve_actor": Callable(fixture, "resolve_actor"),
		"fight_allowed_npc_ids": ["security_boss"],
		"resolve_player": Callable(fixture, "resolve_player"),
		"player_faction_id": "player",
	}
	check.call(bool(dispatcher.call("configure", policy)) and bool(dispatcher.call("begin_conversation", "security_boss", "fight_allowed")), "fight permission binds only the authored live NPC")
	var fight_result: Dictionary = _dispatch(dispatcher, "security_boss", "fight_allowed", 1, "begin_fight", {})
	check.call(fight_result.get("ok", false), "authorized fight proposal commits a live combat transition")
	agent.tick(1.0 / 60.0)
	check.call(agent.state == TacticalAgent.AIState.COMBAT, "live hostile TacticalAgent enters combat against the current player")
	var fixer: Node3D = Node3D.new()
	tree.root.add_child(fixer)
	actors["fixer_mara"] = fixer
	check.call(bool(dispatcher.call("begin_conversation", "fixer_mara", "fight_denied")), "unsupported actor can still have a conversation")
	var denied: Dictionary = _dispatch(dispatcher, "fixer_mara", "fight_denied", 1, "begin_fight", {})
	check.call(not denied.get("ok", false) and denied.get("reason") == "fight_not_authorized", "noncombat NPC cannot be coerced into hostility")
	agent.apply_damage(agent.health_state.max_hp, "player")
	check.call(not bool(dispatcher.call("begin_conversation", "security_boss", "dead_actor")), "dead TacticalAgent cannot start a new authorized action conversation")
	fixture.player.queue_free()
	fixer.queue_free()
	agent.queue_free()
	await tree.process_frame


func _test_full_inventory_entitlement(check: Callable, tree: SceneTree, dispatcher_script: Script) -> void:
	var fixture: ActionFixture = ActionFixture.new()
	var actor: Node3D = Node3D.new()
	tree.root.add_child(actor)
	fixture.actors = {"fixer_mara": actor}
	var inventory: GridInventory = GridInventory.new(Vector2i(10, 6))
	var backup_definition: ItemDefinition = _item_definition("backup_signal_key", "Backup Signal Key", Vector2i.ONE)
	var bulk_definition: ItemDefinition = _item_definition("bulk_cache", "Bulk Cache", Vector2i(10, 6))
	var grants: ItemGrants = ItemGrants.new(inventory, {"backup_signal_key": backup_definition, "bulk_cache": bulk_definition})
	var full_item: ItemInstance = _item_blueprint("93000000-0000-4000-8000-000000000103", "bulk_cache", Vector2i(10, 6))
	check.call(inventory.try_add_item(full_item), "full inventory fixture occupies every grid cell")
	fixture.entitlements["fixer_mara|backup_signal_key"] = _item_blueprint("93000000-0000-4000-8000-000000000102", "backup_signal_key", Vector2i.ONE)
	var dispatcher: Object = dispatcher_script.new()
	var policy: Dictionary = {
		"resolve_actor": Callable(fixture, "resolve_actor"),
		"item_grants": grants,
		"resolve_item_entitlement": Callable(fixture, "resolve_item_entitlement"),
	}
	check.call(bool(dispatcher.call("configure", policy)) and bool(dispatcher.call("begin_conversation", "fixer_mara", "full_grid")), "item-only dispatcher safely configures entitlement adapter")
	var pending: Dictionary = _dispatch(dispatcher, "fixer_mara", "full_grid", 1, "give_item", {"item_id": "backup_signal_key"})
	var transaction_id: String = String(pending.get("transaction_id", ""))
	check.call(pending.get("ok", false) and pending.get("pending", false) and grants.has_pending(transaction_id) and inventory.get_item_count() == 1, "full inventory preserves the preauthorized reward entitlement for retry")
	inventory.remove_item(full_item.uuid)
	check.call(grants.retry_pending(transaction_id) and inventory.get_item_count() == 1 and not grants.has_pending(transaction_id), "pending item entitlement grants exactly once after space becomes available")
	actor.queue_free()
	await tree.process_frame


func _dispatch(dispatcher: Object, npc_id: String, conversation_id: String, generation: int, action_name: String, parameters: Dictionary) -> Dictionary:
	return dispatcher.call("dispatch_response", npc_id, conversation_id, generation, _response(action_name, parameters))


func _response(action_name: String, parameters: Dictionary) -> LLMResponse:
	var response: LLMResponse = LLMResponse.new()
	response.configure("Proposal awaiting authority validation.", {"action": action_name, "parameters": parameters})
	return response


func _item_definition(item_id: String, display_name: String, dimensions: Vector2i) -> ItemDefinition:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = StringName(item_id)
	definition.display_name = display_name
	definition.dimensions = dimensions
	return definition


func _item_blueprint(uuid: String, item_id: String, dimensions: Vector2i) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = uuid
	item.item_id = StringName(item_id)
	item.dimensions = dimensions
	item.grid_position = Vector2i.ZERO
	item.rarity_tier = &"common"
	return item
