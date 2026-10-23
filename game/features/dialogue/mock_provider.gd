extends DialogueProvider
class_name MockDialogueProvider
## Deterministic test provider for valid, delayed and malformed response paths.

enum ResponseMode { VALID, DELAYED, INVALID }

const VALID_RESPONSE: String = "{\"dialogue_text\":\"The transit gate is clear.\",\"proposed_action\":null}"
const INVALID_RESPONSE: String = "{mock-invalid-json"

var delay_seconds: float = 0.05
var response_mode: ResponseMode = ResponseMode.VALID
var valid_response_json: String = VALID_RESPONSE
var invalid_response_json: String = INVALID_RESPONSE
var _identifier_regex: RegEx = RegEx.new()


func _init() -> void:
	_identifier_regex.compile(ContextSnapshot.IDENTIFIER_PATTERN)


func set_response_mode(mode: ResponseMode) -> bool:
	if mode < ResponseMode.VALID or mode > ResponseMode.INVALID:
		return false
	response_mode = mode
	return true


func submit_dialogue_request(npc_id: String, conversation_id: String, request_generation: int, context_payload: Dictionary) -> bool:
	if _identifier_regex.search(npc_id) == null or _identifier_regex.search(conversation_id) == null or request_generation < 0:
		return false
	if context_payload.is_empty():
		return false
	var is_orchestrator_payload: bool = typeof(context_payload.get("context")) == TYPE_DICTIONARY and typeof(context_payload.get("prompt")) == TYPE_STRING
	var is_context_snapshot_payload: bool = context_payload.has("npc_identity") and context_payload.has("scoped_facts") and context_payload.has("faction_standing")
	if not is_orchestrator_payload and not is_context_snapshot_payload:
		return false
	var encoded_context: String = JSON.stringify(context_payload)
	if encoded_context.to_utf8_buffer().size() > ContextSnapshot.MAX_JSON_BYTES:
		return false
	var response_json: String = invalid_response_json if response_mode == ResponseMode.INVALID else valid_response_json
	var should_delay: bool = response_mode == ResponseMode.DELAYED
	call_deferred("_deliver_response", npc_id, conversation_id, request_generation, response_json, should_delay)
	return true


func _deliver_response(npc_id: String, conversation_id: String, request_generation: int, response_json: String, should_delay: bool) -> void:
	if should_delay:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.create_timer(delay_seconds).timeout
	response_completed.emit(npc_id, conversation_id, request_generation, response_json)
