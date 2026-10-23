extends RefCounted
class_name ActionDispatcher
## Runtime-only authority gate for deterministic actions proposed by dialogue models.

const IDENTIFIER_PATTERN: String = "^[a-z0-9][a-z0-9_.-]{0,79}$"
const MAX_TRANSACTIONS: int = 512

var _policy: Dictionary = {}
var _active_npc_id: String = ""
var _active_conversation_id: String = ""
var _last_generation: int = -1
var _transactions: Dictionary = {}
var _identifier_regex: RegEx = RegEx.new()


func _init() -> void:
	_identifier_regex.compile(IDENTIFIER_PATTERN)


func configure(policy: Dictionary) -> bool:
	var resolver: Variant = policy.get("resolve_actor")
	if typeof(resolver) != TYPE_CALLABLE or not (resolver as Callable).is_valid():
		return false
	_policy = policy.duplicate()
	_active_npc_id = ""
	_active_conversation_id = ""
	_last_generation = -1
	_transactions.clear()
	return true


func begin_conversation(npc_id: String, conversation_id: String) -> bool:
	if not _valid_identifier(npc_id) or not _valid_identifier(conversation_id):
		return false
	var actor: Node = _resolve_actor(npc_id)
	if actor == null or not _actor_available(actor) or (actor is TacticalAgent and not _live_tactical_agent(actor as TacticalAgent)):
		return false
	_active_npc_id = npc_id
	_active_conversation_id = conversation_id
	_last_generation = -1
	return true


func end_conversation(npc_id: String, conversation_id: String) -> void:
	if npc_id == _active_npc_id and conversation_id == _active_conversation_id:
		_active_npc_id = ""
		_active_conversation_id = ""
		_last_generation = -1


func dispatch_response(npc_id: String, conversation_id: String, generation: int, response: LLMResponse) -> Dictionary:
	if npc_id != _active_npc_id or conversation_id != _active_conversation_id:
		return _failure("stale_conversation")
	if generation < 0:
		return _failure("stale_generation")
	var actor: Node = _resolve_actor(npc_id)
	if actor == null or not _actor_available(actor):
		return _failure("actor_unavailable")
	var transaction_id: String = _transaction_id(npc_id, conversation_id, generation)
	if _transactions.has(transaction_id):
		var previous: Dictionary = (_transactions[transaction_id] as Dictionary).duplicate(true)
		previous["duplicate"] = true
		return previous
	if generation <= _last_generation:
		return _failure("stale_generation")
	if response == null:
		_last_generation = generation
		return _remember(transaction_id, _failure("invalid_response"))
	var validation: Dictionary = ResponseValidator.new().validate_json(JSON.stringify(response.to_dictionary()))
	if not validation.get("ok", false):
		_last_generation = generation
		return _remember(transaction_id, _failure("invalid_response"))
	var validated_response: LLMResponse = validation["response"] as LLMResponse
	if validated_response.proposed_action == null:
		_last_generation = generation
		return _remember(transaction_id, _failure("no_action"))
	_last_generation = generation
	var action: Dictionary = validated_response.proposed_action
	var parameters: Dictionary = action["parameters"]
	var result: Dictionary = _dispatch_action(npc_id, actor, String(action["action"]), parameters, transaction_id)
	return _remember(transaction_id, result)


func _dispatch_action(npc_id: String, original_actor: Node, action_name: String, parameters: Dictionary, transaction_id: String) -> Dictionary:
	# Actor identity is deliberately resolved again at the commit boundary.
	var actor: Node = _resolve_actor(npc_id)
	if actor == null or actor != original_actor or not _actor_available(actor):
		return _failure("actor_unavailable")
	match action_name:
		"offer_mission":
			return _offer_mission(npc_id, actor, String(parameters["template_id"]))
		"initiate_trade":
			return _initiate_trade(npc_id, actor, String(parameters["inventory_id"]), transaction_id)
		"accept_into_faction":
			return _accept_into_faction(npc_id, String(parameters["faction_id"]))
		"begin_fight":
			return _begin_fight(npc_id, actor)
		"disclose_fact":
			return _disclose_fact(npc_id, actor, String(parameters["fact_id"]), transaction_id)
		"give_item":
			return _give_item(npc_id, actor, String(parameters["item_id"]), transaction_id)
	return _failure("unsupported_action")


func _offer_mission(npc_id: String, actor: Node, template_id: String) -> Dictionary:
	var permissions: Variant = _policy.get("mission_permissions")
	var director: Variant = _policy.get("mission_director")
	if typeof(permissions) != TYPE_DICTIONARY or typeof((permissions as Dictionary).get(npc_id)) != TYPE_ARRAY or not ((permissions as Dictionary)[npc_id] as Array).has(template_id) or not director is MissionDirector:
		return _failure("mission_not_authorized")
	if not _same_live_actor(npc_id, actor):
		return _failure("actor_unavailable")
	var result: Dictionary = (director as MissionDirector).offer_mission(template_id)
	return {"ok": true, "mission": result.get("mission", {}), "mission_id": result.get("mission_id", "")} if result.get("ok", false) else _failure("mission_unavailable")


func _initiate_trade(npc_id: String, actor: Node, inventory_id: String, transaction_id: String) -> Dictionary:
	var owners: Variant = _policy.get("merchant_inventory_owners")
	var validate_stock: Callable = _callable("validate_merchant_stock")
	var open_trade: Callable = _callable("open_trade")
	if typeof(owners) != TYPE_DICTIONARY or (owners as Dictionary).get(inventory_id, "") != npc_id or not validate_stock.is_valid() or not open_trade.is_valid():
		return _failure("merchant_not_authorized")
	if validate_stock.call(inventory_id, npc_id) != true:
		return _failure("merchant_stock_unavailable")
	# Re-read actor and stock immediately before the external deterministic commit.
	if not _same_live_actor(npc_id, actor) or (owners as Dictionary).get(inventory_id, "") != npc_id or validate_stock.call(inventory_id, npc_id) != true:
		return _failure("merchant_stock_unavailable")
	if not _same_live_actor(npc_id, actor):
		return _failure("actor_unavailable")
	if open_trade.call(inventory_id, npc_id, transaction_id) != true:
		return _failure("trade_rejected")
	return {"ok": true, "transaction_id": transaction_id}


func _accept_into_faction(npc_id: String, faction_id: String) -> Dictionary:
	var rules: Variant = _policy.get("faction_acceptance_rules")
	var faction_state: Variant = _policy.get("faction_state")
	if typeof(rules) != TYPE_DICTIONARY or not (rules as Dictionary).has(faction_id) or not faction_state is FactionState:
		return _failure("faction_not_authorized")
	var rule: Variant = (rules as Dictionary)[faction_id]
	if typeof(rule) != TYPE_DICTIONARY:
		return _failure("faction_not_authorized")
	var allowed: Variant = rule.get("allowed_npc_ids")
	var minimum: Variant = rule.get("minimum_standing")
	var accepted: Variant = rule.get("accepted_standing")
	var factions: FactionState = faction_state as FactionState
	if typeof(allowed) != TYPE_ARRAY or not (allowed as Array).has(npc_id) or typeof(minimum) != TYPE_INT or typeof(accepted) != TYPE_INT:
		return _failure("faction_not_authorized")
	if accepted < FactionState.DEFAULT_ALLIED_THRESHOLD or accepted > FactionState.MAX_STANDING or minimum < FactionState.MIN_STANDING or minimum > FactionState.MAX_STANDING:
		return _failure("faction_not_authorized")
	var standings: Dictionary = factions.snapshot_standings()
	if not standings.has(faction_id):
		return _failure("faction_not_authorized")
	var current: int = factions.get_faction_standing(faction_id)
	if current < minimum:
		return _failure("faction_ineligible")
	# The authored rule grants a bounded relationship delta; it cannot lower standing.
	var next_standing: int = maxi(current, accepted)
	if not factions.set_faction_standing(faction_id, next_standing) or not factions.is_allied(faction_id):
		factions.set_faction_standing(faction_id, current)
		return _failure("faction_commit_failed")
	return {"ok": true, "faction_id": faction_id, "standing": factions.get_faction_standing(faction_id)}


func _begin_fight(npc_id: String, actor: Node) -> Dictionary:
	var allowed: Variant = _policy.get("fight_allowed_npc_ids")
	var player_resolver: Callable = _callable("resolve_player")
	var player_faction: Variant = _policy.get("player_faction_id")
	if typeof(allowed) != TYPE_ARRAY or not (allowed as Array).has(npc_id):
		return _failure("fight_not_authorized")
	if not actor is TacticalAgent or not player_resolver.is_valid() or typeof(player_faction) != TYPE_STRING or not _valid_identifier(player_faction):
		return _failure("fight_precondition_failed")
	var agent: TacticalAgent = actor as TacticalAgent
	var player_variant: Variant = player_resolver.call()
	if not _live_tactical_agent(agent) or not player_variant is Node3D or not _actor_available(player_variant as Node3D):
		return _failure("fight_precondition_failed")
	# Revalidate both live objects and permission immediately before transition.
	if _resolve_actor(npc_id) != agent or not _live_tactical_agent(agent) or not (allowed as Array).has(npc_id) or player_resolver.call() != player_variant:
		return _failure("fight_precondition_failed")
	if not agent.set_authored_hostility(String(player_faction), true):
		return _failure("fight_commit_failed")
	if not agent.set_candidate_target(player_variant as Node3D, String(player_faction)):
		agent.clear_authored_hostility(String(player_faction))
		return _failure("fight_commit_failed")
	return {"ok": true, "npc_id": npc_id, "target_faction": String(player_faction)}


func _disclose_fact(npc_id: String, actor: Node, fact_id: String, transaction_id: String) -> Dictionary:
	var available: Callable = _callable("fact_available")
	var commit: Callable = _callable("commit_disclosure")
	if not available.is_valid() or not commit.is_valid() or available.call(npc_id, fact_id) != true:
		return _failure("fact_not_disclosable")
	if not _same_live_actor(npc_id, actor) or available.call(npc_id, fact_id) != true:
		return _failure("fact_not_disclosable")
	if not _same_live_actor(npc_id, actor):
		return _failure("actor_unavailable")
	if commit.call(npc_id, fact_id, transaction_id) != true:
		return _failure("fact_commit_failed")
	return {"ok": true, "fact_id": fact_id, "transaction_id": transaction_id}


func _give_item(npc_id: String, actor: Node, item_id: String, transaction_id: String) -> Dictionary:
	var grants: Variant = _policy.get("item_grants")
	var resolver: Callable = _callable("resolve_item_entitlement")
	if not grants is ItemGrants or not resolver.is_valid():
		return _failure("item_not_entitled")
	var item_variant: Variant = resolver.call(npc_id, item_id)
	if not item_variant is ItemInstance or String((item_variant as ItemInstance).item_id) != item_id:
		return _failure("item_not_entitled")
	if not _same_live_actor(npc_id, actor):
		return _failure("actor_unavailable")
	var item: ItemInstance = item_variant as ItemInstance
	var granted: bool = (grants as ItemGrants).grant(transaction_id, item)
	var pending: bool = (grants as ItemGrants).has_pending(transaction_id)
	if not granted and not pending:
		return _failure("item_grant_failed")
	return {"ok": true, "pending": pending, "transaction_id": transaction_id}


func _remember(transaction_id: String, result: Dictionary) -> Dictionary:
	if _transactions.size() < MAX_TRANSACTIONS:
		_transactions[transaction_id] = result.duplicate(true)
	return result


func _transaction_id(npc_id: String, conversation_id: String, generation: int) -> String:
	return "npc_action_" + ("%s|%s|%d" % [npc_id, conversation_id, generation]).sha256_text()


func _resolve_actor(npc_id: String) -> Node:
	var resolver: Callable = _callable("resolve_actor")
	if not resolver.is_valid():
		return null
	var actor: Variant = resolver.call(npc_id)
	return actor as Node if actor is Node else null


func _actor_available(actor: Node) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree():
		return false
	if actor is TacticalAgent:
		var agent: TacticalAgent = actor as TacticalAgent
		return agent.is_configured() and agent.health_state != null and not agent.health_state.is_dead() and agent.state != TacticalAgent.AIState.DEAD
	return true


func _same_live_actor(npc_id: String, actor: Node) -> bool:
	return _resolve_actor(npc_id) == actor and _actor_available(actor)


func _live_tactical_agent(agent: TacticalAgent) -> bool:
	return _actor_available(agent) and agent.is_configured()


func _callable(key: String) -> Callable:
	var value: Variant = _policy.get(key)
	return value as Callable if typeof(value) == TYPE_CALLABLE else Callable()


func _valid_identifier(value: String) -> bool:
	return _identifier_regex.search(value) != null


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
