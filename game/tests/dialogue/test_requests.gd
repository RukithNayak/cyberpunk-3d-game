extends RefCounted


class ControlledProvider extends Node:
	signal response_completed(npc_id: String, conversation_id: String, generation: int, response_json: String)
	var requests: Array[Dictionary] = []
	var accepts_requests: bool = true
	var emit_response_on_cancel: bool = false
	var last_request: Dictionary = {}

	func submit_dialogue_request(npc_id: String, conversation_id: String, generation: int, payload: Dictionary) -> bool:
		if not accepts_requests:
			return false
		last_request = {"npc_id": npc_id, "conversation_id": conversation_id, "generation": generation, "payload": payload}
		requests.append(last_request)
		return true

	func deliver(request: Dictionary, response_json: String) -> void:
		response_completed.emit(String(request["npc_id"]), String(request["conversation_id"]), int(request["generation"]), response_json)

	func cancel_request() -> void:
		if emit_response_on_cancel and not last_request.is_empty():
			deliver(last_request, JSON.stringify({"dialogue_text": "Canceled response", "proposed_action": null}))


func run(check: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await _test_success_serialization_and_duplicates(check, tree)
	await _test_timeout_fallback_and_late_drop(check, tree)
	await _test_replacement_and_queue_saturation(check, tree)
	await _test_offline_fallback(check, tree)
	await _test_invalid_model_output_fallback(check, tree)
	await _test_cancel_invalidates_before_transport(check, tree)
	await _test_ollama_http_errors_and_model_switch(check, tree)


func _test_success_serialization_and_duplicates(check: Callable, tree: SceneTree) -> void:
	var provider: ControlledProvider = ControlledProvider.new()
	var orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	tree.root.add_child(provider)
	tree.root.add_child(orchestrator)
	check.call(orchestrator.configure(provider), "orchestrator accepts mock transport and bounded config")
	check.call(orchestrator.max_queued_requests == DialogueOrchestrator.DEFAULT_MAX_QUEUED_REQUESTS and orchestrator.request_timeout_seconds == 15.0, "default queue and timeout remain bounded at two queued and fifteen seconds")
	check.call(orchestrator.begin_conversation("fixer_mara", "talk_1", _context(), "Fallback."), "orchestrator binds scoped conversation")
	var events: Array[Dictionary] = []
	orchestrator.dialogue_ready.connect(func(npc: String, conversation: String, generation: int, response: LLMResponse, fallback: bool) -> void:
		events.append({"npc": npc, "conversation": conversation, "generation": generation, "text": response.dialogue_text, "fallback": fallback}))
	orchestrator.submit_dialogue_request("fixer_mara", "Where is the gate?")
	check.call(provider.requests.size() == 1, "request submission returns without waiting for provider completion")
	orchestrator.submit_dialogue_request("fixer_mara", "Who controls it?")
	orchestrator.submit_dialogue_request("fixer_mara", "x".repeat(DialogueOrchestrator.MAX_PROMPT_LENGTH + 1))
	check.call(provider.requests.size() == 1 and provider.requests[0]["payload"]["prompt"] == "Where is the gate?", "only one dialogue request is in flight")
	provider.deliver(provider.requests[0], _valid_response("The gate is west."))
	await tree.process_frame
	check.call(events.size() == 1 and not events[0]["fallback"], "validated provider response is delivered once")
	check.call(provider.requests.size() == 2 and provider.requests[1]["payload"]["prompt"] == "Who controls it?", "next queued dialogue starts after completion")
	provider.deliver(provider.requests[0], _valid_response("duplicate"))
	provider.deliver(provider.requests[1], _valid_response("The market controls it."))
	await tree.process_frame
	check.call(events.size() == 2 and events[1]["text"] == "The market controls it.", "duplicate old response is ignored and next result delivered")
	orchestrator.queue_free()
	provider.queue_free()
	await tree.process_frame


func _test_timeout_fallback_and_late_drop(check: Callable, tree: SceneTree) -> void:
	var provider: ControlledProvider = ControlledProvider.new()
	var orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	tree.root.add_child(provider)
	tree.root.add_child(orchestrator)
	orchestrator.configure(provider, null, 1.0, 2)
	orchestrator.begin_conversation("fixer_mara", "talk_2", _context(), "Authored fallback.")
	var events: Array[Dictionary] = []
	orchestrator.dialogue_ready.connect(func(_npc: String, _conversation: String, _generation: int, response: LLMResponse, fallback: bool) -> void:
		events.append({"text": response.dialogue_text, "fallback": fallback}))
	orchestrator.submit_dialogue_request("fixer_mara", "Never replies")
	var request: Dictionary = provider.requests[0]
	provider.emit_response_on_cancel = true
	await tree.create_timer(1.05).timeout
	check.call(events.size() == 1 and events[0]["fallback"] and events[0]["text"] == "Authored fallback.", "timeout returns authored fallback exactly once")
	provider.deliver(request, _valid_response("Too late"))
	await tree.process_frame
	check.call(events.size() == 1, "late provider output after timeout is discarded")
	orchestrator.queue_free()
	provider.queue_free()
	await tree.process_frame


func _test_replacement_and_queue_saturation(check: Callable, tree: SceneTree) -> void:
	var provider: ControlledProvider = ControlledProvider.new()
	var orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	tree.root.add_child(provider)
	tree.root.add_child(orchestrator)
	orchestrator.configure(provider, null, 1.0, 1)
	orchestrator.begin_conversation("fixer_mara", "talk_3", _context(), "Fallback.")
	var events: Array[Dictionary] = []
	var rejected: Array[StringName] = []
	orchestrator.dialogue_ready.connect(func(_npc: String, _conversation: String, _generation: int, response: LLMResponse, fallback: bool) -> void:
		events.append({"text": response.dialogue_text, "fallback": fallback}))
	orchestrator.request_rejected.connect(func(_npc: String, reason: StringName) -> void: rejected.append(reason))
	orchestrator.submit_dialogue_request("fixer_mara", "first")
	orchestrator.submit_dialogue_request("fixer_mara", "second")
	orchestrator.submit_dialogue_request("fixer_mara", "third")
	check.call(provider.requests.size() == 1 and rejected == [&"queue_full"], "bounded queue rejects requests beyond one active plus configured capacity")
	var old_request: Dictionary = provider.requests[0]
	orchestrator.begin_conversation("fixer_mara", "talk_4", _context(), "New fallback.")
	provider.deliver(old_request, _valid_response("Stale conversation"))
	await tree.process_frame
	check.call(events.is_empty(), "conversation replacement invalidates old generation before late output")
	orchestrator.submit_dialogue_request("fixer_mara", "new conversation")
	provider.deliver(provider.requests[1], _valid_response("Current conversation"))
	await tree.process_frame
	check.call(events.size() == 1 and events[0]["text"] == "Current conversation" and not events[0]["fallback"], "new conversation remains responsive after replacement")
	orchestrator.queue_free()
	provider.queue_free()
	await tree.process_frame


func _test_offline_fallback(check: Callable, tree: SceneTree) -> void:
	var provider: ControlledProvider = ControlledProvider.new()
	provider.accepts_requests = false
	var orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	tree.root.add_child(provider)
	tree.root.add_child(orchestrator)
	orchestrator.configure(provider, null, 1.0, 2)
	orchestrator.begin_conversation("fixer_mara", "talk_offline", _context(), "Provider offline fallback.")
	var events: Array[bool] = []
	orchestrator.dialogue_ready.connect(func(_npc: String, _conversation: String, _generation: int, _response: LLMResponse, fallback: bool) -> void: events.append(fallback))
	orchestrator.submit_dialogue_request("fixer_mara", "Hello")
	check.call(events.size() == 1 and events[0], "offline provider immediately returns authored fallback")
	orchestrator.queue_free()
	provider.queue_free()
	await tree.process_frame


func _context() -> ContextSnapshot:
	var context: ContextSnapshot = ContextSnapshot.new()
	context.configure("fixer_mara", "Mara", "night_market", [], "", [], 0)
	return context


func _valid_response(text: String) -> String:
	return JSON.stringify({"dialogue_text": text, "proposed_action": null})


func _test_invalid_model_output_fallback(check: Callable, tree: SceneTree) -> void:
	var provider: ControlledProvider = ControlledProvider.new()
	var orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	tree.root.add_child(provider)
	tree.root.add_child(orchestrator)
	orchestrator.configure(provider, null, 1.0, 2)
	orchestrator.begin_conversation("fixer_mara", "talk_invalid", _context(), "Malformed output fallback.")
	var events: Array[Dictionary] = []
	orchestrator.dialogue_ready.connect(func(_npc: String, _conversation: String, _generation: int, response: LLMResponse, fallback: bool) -> void:
		events.append({"text": response.dialogue_text, "fallback": fallback}))
	orchestrator.submit_dialogue_request("fixer_mara", "Return JSON")
	provider.deliver(provider.requests[0], "{malformed")
	check.call(events.size() == 1 and events[0]["fallback"] and events[0]["text"] == "Malformed output fallback.", "invalid model JSON returns authored fallback exactly once")
	orchestrator.queue_free()
	provider.queue_free()
	await tree.process_frame


func _test_ollama_http_errors_and_model_switch(check: Callable, tree: SceneTree) -> void:
	var provider: OllamaProvider = OllamaProvider.new()
	tree.root.add_child(provider)
	await tree.process_frame
	check.call(not provider.configure("http://127.0.0.1:11434", ""), "Ollama provider requires an explicit model name")
	check.call(provider.configure("http://127.0.0.1:11434/", "test-model"), "Ollama provider accepts local endpoint and model configuration")
	var events: Array[String] = []
	provider.response_completed.connect(func(_npc: String, _conversation: String, _generation: int, raw_json: String) -> void: events.append(raw_json))
	for response_code: int in [404, 500]:
		provider.set("_request_active", true)
		provider.set("_active_npc_id", "fixer_mara")
		provider.set("_active_conversation_id", "talk_http")
		provider.set("_active_generation", response_code)
		check.call(not provider.configure("http://127.0.0.1:11434", "switched-model"), "model cannot switch during an active HTTP request")
		provider.call("_on_http_response_completed", HTTPRequest.RESULT_SUCCESS, response_code, PackedStringArray(), "server error".to_utf8_buffer())
	check.call(events.size() == 2 and events[0] == "{}" and events[1] == "{}", "HTTP 4xx and 5xx responses become rejectable model output for authored fallback")
	provider.set("_request_active", true)
	provider.set("_active_npc_id", "fixer_mara")
	provider.set("_active_conversation_id", "talk_http")
	provider.set("_active_generation", 91)
	provider.call("_on_http_response_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{broken".to_utf8_buffer())
	check.call(events.size() == 3 and events[2] == "{}", "malformed Ollama HTTP envelope becomes rejectable model output")
	check.call(provider.configure("http://127.0.0.1:11434", "switched-model"), "model can switch safely after the active request ends")
	provider.queue_free()
	await tree.process_frame


func _test_cancel_invalidates_before_transport(check: Callable, tree: SceneTree) -> void:
	var provider: ControlledProvider = ControlledProvider.new()
	provider.emit_response_on_cancel = true
	var orchestrator: DialogueOrchestrator = DialogueOrchestrator.new()
	tree.root.add_child(provider)
	tree.root.add_child(orchestrator)
	orchestrator.configure(provider, null, 1.0, 2)
	orchestrator.begin_conversation("fixer_mara", "talk_cancel", _context(), "Fallback.")
	var events: Array[String] = []
	orchestrator.dialogue_ready.connect(func(_npc: String, _conversation: String, _generation: int, response: LLMResponse, _fallback: bool) -> void: events.append(response.dialogue_text))
	orchestrator.submit_dialogue_request("fixer_mara", "Cancel me")
	orchestrator.cancel_current_conversation()
	check.call(events.is_empty(), "synchronous transport callback during cancellation is invalidated before it can publish")
	orchestrator.queue_free()
	provider.queue_free()
	await tree.process_frame
