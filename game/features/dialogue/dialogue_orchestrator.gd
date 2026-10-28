extends Node
class_name DialogueOrchestrator
## Serializes requests, invalidates stale generations, validates results, and falls back once.

signal dialogue_ready(npc_id: String, conversation_id: String, request_generation: int, response: LLMResponse, used_fallback: bool)
signal request_rejected(npc_id: String, reason: StringName)

const DEFAULT_TIMEOUT_SECONDS: float = 15.0
const DEFAULT_MAX_QUEUED_REQUESTS: int = 2
const MAX_PROMPT_LENGTH: int = 1000

@export_range(1.0, 120.0, 1.0) var request_timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
@export_range(0, 16, 1) var max_queued_requests: int = DEFAULT_MAX_QUEUED_REQUESTS

var _provider: Object
var _validator: ResponseValidator
var _configured: bool = false
var _npc_id: String = ""
var _conversation_id: String = ""
var _context: ContextSnapshot
var _fallback_text: String = ""
var _generation_counter: int = 0
var _queue: Array[Dictionary] = []
var _active_request: Dictionary = {}
var _timeout_timer: Timer


func _ready() -> void:
	_timeout_timer = Timer.new()
	_timeout_timer.name = "DialogueRequestTimeout"
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_request_timeout)
	add_child(_timeout_timer)


func _exit_tree() -> void:
	cancel_current_conversation()


func configure(provider: Object, validator: ResponseValidator = null, timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS, queue_limit: int = DEFAULT_MAX_QUEUED_REQUESTS) -> bool:
	if _configured or not is_inside_tree() or provider == null or not provider.has_method("submit_dialogue_request") or not provider.has_signal("response_completed"):
		return false
	if not is_finite(timeout_seconds) or timeout_seconds < 1.0 or timeout_seconds > 120.0 or queue_limit < 0 or queue_limit > 16:
		return false
	_provider = provider
	_validator = validator if validator != null else ResponseValidator.new()
	request_timeout_seconds = timeout_seconds
	max_queued_requests = queue_limit
	_provider.connect("response_completed", _on_provider_response_completed)
	_configured = true
	return true


func begin_conversation(npc_id: String, conversation_id: String, context: ContextSnapshot, fallback_text: String) -> bool:
	if not _configured or not _valid_identifier(npc_id) or not _valid_identifier(conversation_id):
		return false
	if context == null or not context.is_configured() or context.npc_identity.get("npc_id") != npc_id:
		return false
	if fallback_text.strip_edges().is_empty() or fallback_text.length() > ResponseValidator.MAX_DIALOGUE_LENGTH:
		return false
	cancel_current_conversation()
	_npc_id = npc_id
	_conversation_id = conversation_id
	_context = context
	_fallback_text = fallback_text
	return true


func submit_dialogue_request(npc_id: String, prompt: String) -> void:
	if not _configured or _context == null or npc_id != _npc_id:
		request_rejected.emit(npc_id, &"conversation_unavailable")
		return
	if prompt.strip_edges().is_empty() or prompt.length() > MAX_PROMPT_LENGTH:
		request_rejected.emit(npc_id, &"invalid_prompt")
		return
	if _queue.size() >= max_queued_requests:
		request_rejected.emit(npc_id, &"queue_full")
		return
	var payload: Dictionary = {"context": _context.to_payload(), "prompt": prompt}
	if JSON.stringify(payload).to_utf8_buffer().size() > ContextSnapshot.MAX_JSON_BYTES:
		request_rejected.emit(npc_id, &"context_too_large")
		return
	_generation_counter += 1
	_queue.append({
		"npc_id": _npc_id,
		"conversation_id": _conversation_id,
		"generation": _generation_counter,
		"payload": payload,
	})
	_start_next_request()


func cancel_current_conversation() -> void:
	_generation_counter += 1
	if _timeout_timer != null:
		_timeout_timer.stop()
	var should_cancel_provider: bool = not _active_request.is_empty() and _provider != null and _provider.has_method("cancel_request")
	_active_request.clear()
	_queue.clear()
	_context = null
	_npc_id = ""
	_conversation_id = ""
	_fallback_text = ""
	if should_cancel_provider:
		_provider.call("cancel_request")


func _start_next_request() -> void:
	if not _configured or not _active_request.is_empty() or _queue.is_empty():
		return
	_active_request = _queue.pop_front()
	_timeout_timer.start(request_timeout_seconds)
	var request: Dictionary = _active_request
	var accepted: bool = bool(_provider.call(
		"submit_dialogue_request",
		String(request["npc_id"]), String(request["conversation_id"]), int(request["generation"]), request["payload"]))
	if not accepted:
		_finish_with_fallback(request, &"provider_unavailable")


func _on_provider_response_completed(npc_id: String, conversation_id: String, request_generation: int, response_json: String) -> void:
	if _active_request.is_empty():
		return
	if npc_id != _active_request["npc_id"] or conversation_id != _active_request["conversation_id"] or request_generation != _active_request["generation"]:
		return
	_timeout_timer.stop()
	var result: Dictionary = _validator.validate_json(response_json)
	if not result.get("ok", false):
		_finish_with_fallback(_active_request, &"invalid_response")
		return
	var request: Dictionary = _active_request
	_active_request.clear()
	dialogue_ready.emit(npc_id, conversation_id, request_generation, result["response"], false)
	call_deferred("_start_next_request")


func _on_request_timeout() -> void:
	if _active_request.is_empty():
		return
	var request: Dictionary = _active_request.duplicate(true)
	_finish_with_fallback(request, &"timeout")
	if _provider.has_method("cancel_request"):
		_provider.call("cancel_request")


func _finish_with_fallback(request: Dictionary, reason: StringName) -> void:
	if _active_request.is_empty() or int(request.get("generation", -1)) != int(_active_request.get("generation", -2)):
		return
	var completed_request: Dictionary = request.duplicate(true)
	_timeout_timer.stop()
	var fallback: LLMResponse = LLMResponse.new()
	if not fallback.configure(_fallback_text, null):
		return
	_active_request.clear()
	dialogue_ready.emit(String(completed_request["npc_id"]), String(completed_request["conversation_id"]), int(completed_request["generation"]), fallback, true)
	request_rejected.emit(String(completed_request["npc_id"]), reason)
	call_deferred("_start_next_request")


func _valid_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > ContextSnapshot.MAX_IDENTIFIER_LENGTH:
		return false
	var first: int = value.unicode_at(0)
	if not (first >= 48 and first <= 57 or first >= 97 and first <= 122):
		return false
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		var valid: bool = codepoint >= 48 and codepoint <= 57 or codepoint >= 97 and codepoint <= 122 or codepoint in [45, 46, 95]
		if not valid:
			return false
	return true
