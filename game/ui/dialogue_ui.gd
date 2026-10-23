extends Control
class_name DialogueUI
## Responsive named-NPC conversation panel, wired only to authoritative services.

const NPC_ID: String = "mara_vega"
const TEMPLATE_ID: String = "retrieve_signal_cache"

var _orchestrator: DialogueOrchestrator
var _dispatcher: ActionDispatcher
var _missions: MissionDirector
var _context: ContextSnapshot
var _audio: GenerationAudio
var _log: RichTextLabel
var _status: Label
var _prompt: LineEdit
var _submit: Button
var _cancel: Button
var _close: Button
var _request_job: Button
var _accept_job: Button
var _recover_job: Button
var _subtitles: CheckButton
var _volume: HSlider
var _npc_label: Label
var _conversation_id: String = ""
var _mission_id: String = ""
var _fallback_text: String = ""
var _recovery_action: Callable
var _return_focus: Control
var _npc_name: String = "MARA VEGA"
var _pending: bool = false


func _ready() -> void:
	_build_interface()
	_audio = GenerationAudio.new()
	_audio.name = "GenerationAudio"
	add_child(_audio)
	set_process_unhandled_key_input(true)


func configure(orchestrator: DialogueOrchestrator, dispatcher: ActionDispatcher, missions: MissionDirector, context: ContextSnapshot, npc_id: String = NPC_ID, npc_name: String = _npc_name, fallback_text: String = "The underpass is hot. Bring back the signal cache and I'll pay you.") -> bool:
	if orchestrator == null or dispatcher == null or missions == null or context == null:
		return false
	if npc_id != NPC_ID or not context.is_configured() or context.npc_identity.get("npc_id") != npc_id:
		return false
	if _orchestrator != null:
		_disconnect_services()
	_orchestrator = orchestrator
	_dispatcher = dispatcher
	_missions = missions
	_context = context
	_npc_name = npc_name
	_fallback_text = fallback_text
	_orchestrator.dialogue_ready.connect(_on_dialogue_ready)
	_orchestrator.request_rejected.connect(_on_request_rejected)
	_npc_label.text = _npc_name.to_upper()
	var journal: MissionJournal = get_node("Root/Center/Panel/Columns/Journal") as MissionJournal
	journal.configure(_missions)
	return true


func begin_conversation(conversation_id: String) -> bool:
	if _orchestrator == null or conversation_id.strip_edges().is_empty():
		return false
	_conversation_id = conversation_id
	if not _dispatcher.begin_conversation(NPC_ID, _conversation_id):
		_status.text = "CONTACT UNAVAILABLE"
		return false
	if not _orchestrator.begin_conversation(NPC_ID, _conversation_id, _context, _fallback_text):
		_dispatcher.end_conversation(NPC_ID, _conversation_id)
		return false
	show_dialogue()
	_append("[color=#f2b84b]%s // LINK ESTABLISHED[/color]" % _npc_name.to_upper())
	return true


func request_job() -> void:
	if _missions == null:
		return
	var offer: Dictionary = _missions.offer_mission(TEMPLATE_ID)
	if not offer.get("ok", false):
		_status.text = _friendly_reason(String(offer.get("reason", "mission_unavailable")))
		_append("[color=#ff625d]%s[/color]" % _status.text)
		return
	_mission_id = String(offer["mission_id"])
	_accept_job.disabled = String(offer["mission"].get("state", "")) != "offered"
	_status.text = "CONTRACT OFFERED  // 125 CR"
	_append("[color=#49d8dc]CONTRACT OFFERED[/color]\n%s" % String(offer.get("fallback_text", "Retrieve the signal cache.")))
	_audio.play_blip()


func accept_job() -> bool:
	if _missions == null or _mission_id.is_empty():
		request_job()
	if _mission_id.is_empty():
		return false
	var accepted: bool = _missions.accept_mission(_mission_id) and _missions.activate_mission(_mission_id)
	if accepted:
		_accept_job.disabled = true
		_recover_job.disabled = false
		_status.text = "CONTRACT ACTIVE  // RECOVER SIGNAL CACHE"
		_append("[color=#f2b84b]CONTRACT ACTIVE[/color]  // Retrieve the marked signal cache.")
		_audio.play_blip()
	return accepted


## Called by the world interaction after the authoritative target registry has changed.
func notify_target_collected(target_uuid: String) -> bool:
	if _missions == null or _mission_id.is_empty():
		return false
	var mission: Dictionary = _missions.get_mission(_mission_id)
	if String(mission.get("target_uuid", "")) != target_uuid:
		return false
	var completed: bool = _missions.complete_mission(_mission_id)
	if completed:
		_recover_job.disabled = true
		_status.text = "CONTRACT COMPLETE  // +%d CR" % int(mission.get("reward_credits", 0))
		_append("[color=#f2b84b]CACHE VERIFIED[/color]  // Reward transferred.")
		_audio.play_blip()
	return completed


func set_recovery_action(action: Callable) -> void:
	_recovery_action = action


func set_return_focus(target: Control) -> void:
	_return_focus = target


func show_dialogue() -> void:
	visible = true
	$Root/Center/Panel/Columns/Conversation/MessageInput/Prompt.grab_focus()


func close_dialogue() -> void:
	if _orchestrator != null:
		_orchestrator.cancel_current_conversation()
	if _dispatcher != null and not _conversation_id.is_empty():
		_dispatcher.end_conversation(NPC_ID, _conversation_id)
	if _audio != null:
		_audio.stop()
	_pending = false
	visible = false
	$Root/Center/Panel/Columns/Conversation/MessageInput/Prompt.release_focus()
	if is_instance_valid(_return_focus) and not _return_focus.is_queued_for_deletion():
		_return_focus.call_deferred("grab_focus")


func _build_interface() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	var root: MarginContainer = MarginContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_top", 36)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_bottom", 36)
	add_child(root)
	var center: MarginContainer = MarginContainer.new()
	center.name = "Center"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("margin_left", 10)
	center.add_theme_constant_override("margin_top", 10)
	center.add_theme_constant_override("margin_right", 10)
	center.add_theme_constant_override("margin_bottom", 10)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2.ZERO
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(panel)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 20)
	panel.add_child(columns)
	var journal: VBoxContainer = VBoxContainer.new()
	journal.name = "Journal"
	journal.set_script(load("res://ui/mission_journal.gd"))
	journal.custom_minimum_size = Vector2(250, 0)
	journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(journal)
	var separator: VSeparator = VSeparator.new()
	columns.add_child(separator)
	var conversation: VBoxContainer = VBoxContainer.new()
	conversation.name = "Conversation"
	conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conversation.add_theme_constant_override("separation", 14)
	columns.add_child(conversation)
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "TopBar"
	conversation.add_child(top)
	var heading: VBoxContainer = VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	_npc_label = Label.new()
	_npc_label.name = "NpcName"
	_npc_label.text = _npc_name
	_npc_label.theme_type_variation = &"CyberpunkHeader"
	heading.add_child(_npc_label)
	var subtitle: Label = Label.new()
	subtitle.text = "NIGHT MARKET // PRIVATE CHANNEL"
	subtitle.theme_type_variation = &"CyberpunkMuted"
	heading.add_child(subtitle)
	_close = Button.new()
	_close.text = "DISCONNECT  ×"
	_close.pressed.connect(close_dialogue)
	top.add_child(_close)
	_log = RichTextLabel.new()
	_log.name = "Transcript"
	_log.bbcode_enabled = true
	_log.fit_content = false
	_log.scroll_following = true
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(400, 240)
	conversation.add_child(_log)
	_status = Label.new()
	_status.name = "Status"
	_status.text = "CHANNEL READY"
	_status.theme_type_variation = &"CyberpunkAccent"
	conversation.add_child(_status)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	conversation.add_child(action_row)
	_request_job = Button.new()
	_request_job.text = "REQUEST RETRIEVAL CONTRACT"
	_request_job.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_request_job.pressed.connect(request_job)
	action_row.add_child(_request_job)
	_accept_job = Button.new()
	_accept_job.text = "ACCEPT"
	_accept_job.disabled = true
	_accept_job.pressed.connect(accept_job)
	action_row.add_child(_accept_job)
	_recover_job = Button.new()
	_recover_job.text = "RECOVER CACHE"
	_recover_job.disabled = true
	_recover_job.pressed.connect(_recover_signal_cache)
	action_row.add_child(_recover_job)
	var input: HBoxContainer = HBoxContainer.new()
	input.name = "MessageInput"
	conversation.add_child(input)
	_prompt = LineEdit.new()
	_prompt.name = "Prompt"
	_prompt.placeholder_text = "Transmit a message…"
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt.text_submitted.connect(_on_prompt_submitted)
	input.add_child(_prompt)
	_submit = Button.new()
	_submit.text = "SEND"
	_submit.pressed.connect(_submit_prompt)
	input.add_child(_submit)
	_cancel = Button.new()
	_cancel.text = "CANCEL REQUEST"
	_cancel.disabled = true
	_cancel.pressed.connect(_cancel_request)
	input.add_child(_cancel)
	var settings: HBoxContainer = HBoxContainer.new()
	conversation.add_child(settings)
	_subtitles = CheckButton.new()
	_subtitles.text = "TEXT / SUBTITLES"
	_subtitles.button_pressed = true
	_subtitles.toggled.connect(func(enabled: bool) -> void: _log.visible = enabled)
	settings.add_child(_subtitles)
	var volume_label: Label = Label.new()
	volume_label.text = "GEN AUDIO"
	volume_label.theme_type_variation = &"CyberpunkMuted"
	settings.add_child(volume_label)
	_volume = HSlider.new()
	_volume.name = "AudioVolume"
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = 0.65
	_volume.custom_minimum_size = Vector2(120, 0)
	_volume.value_changed.connect(func(value: float) -> void: _audio.set_volume(value))
	settings.add_child(_volume)
	var mute: CheckButton = CheckButton.new()
	mute.name = "Mute"
	mute.text = "MUTE"
	mute.toggled.connect(func(enabled: bool) -> void: _audio.set_muted(enabled))
	settings.add_child(mute)


func _submit_prompt() -> void:
	if _orchestrator == null or _pending or _conversation_id.is_empty():
		return
	var text: String = _prompt.text.strip_edges()
	if text.is_empty():
		return
	_append("[color=#9eb0b1]YOU[/color]  // %s" % text)
	_prompt.clear()
	_pending = true
	_submit.disabled = true
	_cancel.disabled = false
	_status.text = "WAITING FOR LOCAL PROVIDER…"
	_orchestrator.submit_dialogue_request(NPC_ID, text)


func _on_prompt_submitted(_text: String) -> void:
	_submit_prompt()


func _recover_signal_cache() -> void:
	const TARGET_UUID: String = "00000000-0000-4000-8000-000000000032"
	if _recovery_action.is_valid() and _recovery_action.call() == true:
		notify_target_collected(TARGET_UUID)
	else:
		_status.text = "CACHE UNAVAILABLE  // WORLD INTERACTION REQUIRED"


func _cancel_request() -> void:
	if _orchestrator != null:
		_orchestrator.cancel_current_conversation()
	if _dispatcher != null and not _conversation_id.is_empty():
		_dispatcher.end_conversation(NPC_ID, _conversation_id)
	_pending = false
	_submit.disabled = false
	_cancel.disabled = true
	_status.text = "REQUEST CANCELLED"
	_audio.stop()
	_prompt.grab_focus()


func _on_dialogue_ready(npc_id: String, conversation_id: String, generation: int, response: LLMResponse, used_fallback: bool) -> void:
	if npc_id != NPC_ID or conversation_id != _conversation_id:
		return
	_pending = false
	_submit.disabled = false
	_cancel.disabled = true
	_status.text = "AUTHORED FALLBACK" if used_fallback else "LOCAL RESPONSE"
	var response_text: String = response.dialogue_text
	if response.proposed_action != null and _dispatcher != null:
		var result: Dictionary = _dispatcher.dispatch_response(npc_id, conversation_id, generation, response)
		response_text += "\n\n" + _action_message(result)
	_append("[color=#f2b84b]%s[/color]  // %s" % [_npc_name.to_upper(), response_text.c_escape()])
	if _audio != null:
		_audio.play_blip()
	_prompt.grab_focus()


func _on_request_rejected(npc_id: String, reason: StringName) -> void:
	if npc_id != NPC_ID:
		return
	if reason == &"timeout" or reason == &"provider_unavailable" or reason == &"invalid_response":
		_audio.stop()
		_pending = false
		_submit.disabled = false
		_cancel.disabled = true
		if reason == &"timeout":
			_status.text = "PROVIDER TIMEOUT  // FALLBACK READY"


func _action_message(result: Dictionary) -> String:
	if result.get("ok", false):
		return "[color=#49d8dc]AUTHORIZED ACTION COMMITTED[/color]"
	var reason: String = String(result.get("reason", "action_unavailable"))
	if reason.begins_with("merchant_") or reason == "trade_rejected":
		return "[color=#ffb84c]TRADE UNAVAILABLE[/color]  // This contact has no configured stock panel."
	return "[color=#ff625d]ACTION NOT AVAILABLE[/color]  // %s" % _friendly_reason(reason)


func _friendly_reason(reason: String) -> String:
	match reason:
		"target_unreachable": return "Signal cache is outside the active route."
		"target_missing", "target_unavailable": return "Signal cache is no longer available."
		"faction_ineligible": return "Standing is too low for this contract."
		"merchant_stock_unavailable", "merchant_not_authorized": return "Trade is unavailable for this contact."
		_: return "Request unavailable  // %s" % reason.replace("_", " ").to_upper()


func _append(markup: String) -> void:
	_log.append_text(markup + "\n\n")


func _disconnect_services() -> void:
	if _orchestrator.dialogue_ready.is_connected(_on_dialogue_ready):
		_orchestrator.dialogue_ready.disconnect(_on_dialogue_ready)
	if _orchestrator.request_rejected.is_connected(_on_request_rejected):
		_orchestrator.request_rejected.disconnect(_on_request_rejected)


func _exit_tree() -> void:
	if _orchestrator != null:
		_disconnect_services()
	if _audio != null:
		_audio.stop()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
