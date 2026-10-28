extends Control
## Playable NPC-06 fixture using authored data and the deterministic mock provider.

const CACHE_UUID: String = "00000000-0000-4000-8000-000000000032"

var _registry: EntityRegistry
var _dialogue: DialogueUI
var dialogue_provider: MockDialogueProvider
var mission_director: MissionDirector
var mission_factions: FactionState


func _ready() -> void:
	_registry = EntityRegistry.new()
	_registry.register_entity(CACHE_UUID, {"collected": false})
	mission_factions = FactionState.new(["night_market"])
	mission_factions.set_faction_standing("night_market", 0)
	var mission_template: MissionTemplate = load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate
	mission_director = MissionDirector.new()
	mission_director.configure([mission_template], _registry, mission_factions, func(_uuid: String) -> bool: return true)
	var actor: Node = Node.new()
	actor.name = "MaraVega"
	add_child(actor)
	dialogue_provider = MockDialogueProvider.new()
	var orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	orchestrator.name = "DialogueOrchestrator"
	add_child(orchestrator)
	orchestrator.configure(dialogue_provider)
	var dispatcher: ActionDispatcher = ActionDispatcher.new()
	dispatcher.configure({"resolve_actor": func(npc_id: String) -> Node: return actor if npc_id == "mara_vega" else null})
	var context: ContextSnapshot = ContextSnapshot.new()
	context.configure("mara_vega", "Mara Vega", "night_market", ["The transit underpass contains a signal cache."], "", ["retrieve_signal_cache"], 0)
	_dialogue = get_node("DialogueUI") as DialogueUI
	_dialogue.set_recovery_action(Callable(self, "_collect_cache"))
	_dialogue.configure(orchestrator, dispatcher, mission_director, context)
	_dialogue.begin_conversation("mara_vega_session_01")


func _collect_cache() -> bool:
	return _registry.try_commit_state_delta(CACHE_UUID, {"collected": true})
