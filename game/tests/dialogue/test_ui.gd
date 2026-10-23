extends RefCounted


func run(check: Callable) -> void:
	var fixture: Control = (load("res://tests/scenes/dialogue_demo.tscn") as PackedScene).instantiate() as Control
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(fixture)
	await tree.process_frame
	await tree.process_frame
	var ui: DialogueUI = fixture.get_node("DialogueUI") as DialogueUI
	check.call(ui != null and ui.visible and ui.find_child("NpcName", true, false).get("text") == "MARA VEGA", "named NPC opens responsive conversation UI with initial focus target")
	var provider: MockDialogueProvider = fixture.get("dialogue_provider") as MockDialogueProvider
	var orchestrator: DialogueOrchestrator = fixture.get_node("DialogueOrchestrator") as DialogueOrchestrator
	var log: RichTextLabel = ui.find_child("Transcript", true, false) as RichTextLabel
	var status: Label = ui.find_child("Status", true, false) as Label
	var audio: GenerationAudio = ui.get_node("GenerationAudio") as GenerationAudio
	check.call(ui.get_viewport().gui_get_focus_owner() == ui.find_child("Prompt", true, false), "conversation opens with keyboard text-entry focus")
	var volume: HSlider = ui.find_child("AudioVolume", true, false) as HSlider
	volume.value = 0.4
	check.call(is_equal_approx(audio.get_volume(), 0.4), "audio slider changes generated dialogue volume")
	var mute: CheckButton = ui.find_child("Mute", true, false) as CheckButton
	mute.toggled.emit(true)
	check.call(audio.is_muted(), "accessible mute control disables generated UI audio")
	mute.toggled.emit(false)
	ui.call("request_job")
	var accepted: bool = bool(ui.call("accept_job"))
	var collected: bool = bool(fixture.call("_collect_cache")) and ui.notify_target_collected("00000000-0000-4000-8000-000000000032")
	check.call(accepted and collected, "authored fallback accepts and completes the retrieval contract after authoritative collection")
	var journal: MissionJournal = fixture.get_node("DialogueUI/Root/Center/Panel/Columns/Journal") as MissionJournal
	check.call((journal.get_node("Credits") as Label).text == "CREDITS  // 125", "mission journal refreshes from lifecycle events with committed reward credits")
	var source_director: MissionDirector = fixture.get("mission_director") as MissionDirector
	var restored: MissionDirector = MissionDirector.new()
	var restore_ok: bool = restored.configure([load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate], fixture.get("_registry") as EntityRegistry, fixture.get("mission_factions") as FactionState, func(_uuid: String) -> bool: return true)
	var prepared: Dictionary = restored.prepare_snapshot(source_director.capture_snapshot())
	if prepared.get("ok", false):
		restored.commit_prepared_snapshot(prepared["prepared"])
	var restored_journal: MissionJournal = MissionJournal.new()
	ui.add_child(restored_journal)
	check.call(restore_ok and prepared.get("ok", false) and restored_journal.configure(restored) and restored_journal.get_node("Credits").text == "CREDITS  // 125", "mission journal reconstructs completed job and credits from the data-only saved snapshot")

	provider.valid_response_json = JSON.stringify({"dialogue_text": "Trade desk is offline.", "proposed_action": {"action": "initiate_trade", "parameters": {"inventory_id": "market_stock"}}})
	ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").text = "open trade"
	ui.call("_submit_prompt")
	await tree.create_timer(0.08).timeout
	check.call(log.get_parsed_text().contains("TRADE UNAVAILABLE"), "unauthorized inventory-backed trade is explained without claiming a panel or transaction")

	provider.valid_response_json = JSON.stringify({"dialogue_text": "I can offer you something else.", "proposed_action": {"action": "retrieve_signal_cache", "parameters": []}})
	ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").text = "Can you sell me a military rifle?"
	ui.call("_submit_prompt")
	await tree.process_frame
	check.call(String(status.text).contains("FALLBACK") and not log.get_parsed_text().contains("offer you something else"), "model's unknown retrieval action is rejected and never presented as a committed action")

	provider.response_mode = MockDialogueProvider.ResponseMode.OFFLINE
	ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").text = "Are you there?"
	ui.call("_submit_prompt")
	await tree.process_frame
	check.call(String(status.text).contains("FALLBACK"), "offline provider routes to authored fallback")

	provider.response_mode = MockDialogueProvider.ResponseMode.DELAYED
	provider.delay_seconds = 0.3
	ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").text = "Timeout check"
	ui.call("_submit_prompt")
	await tree.process_frame
	audio.play_blip()
	orchestrator.call("_on_request_timeout")
	check.call(String(status.text).contains("FALLBACK") and not (audio.get_node("GenerationBlipPlayer") as AudioStreamPlayer).playing, "timeout emits authored fallback and stops any generation audio")

	provider.response_mode = MockDialogueProvider.ResponseMode.DELAYED
	provider.delay_seconds = 0.15
	ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").text = "Wait for me"
	ui.call("_submit_prompt")
	await tree.process_frame
	ui.call("_cancel_request")
	await tree.create_timer(0.2).timeout
	check.call(status.text == "REQUEST CANCELLED" and not (audio.get_node("GenerationBlipPlayer") as AudioStreamPlayer).playing, "mid-dialogue cancellation invalidates late response and stops generated audio")
	check.call(audio.get_volume() >= 0.0 and audio.get_volume() <= 1.0 and not audio.is_muted(), "generation audio exposes bounded volume and mute state")
	var return_focus: Button = Button.new()
	return_focus.name = "ReturnFocus"
	return_focus.text = "Talk to Mara"
	fixture.add_child(return_focus)
	ui.set_return_focus(return_focus)
	audio.play_blip()
	ui.call("close_dialogue")
	await tree.process_frame
	check.call(not ui.visible and not (audio.get_node("GenerationBlipPlayer") as AudioStreamPlayer).playing, "close cancels active work, stops audio and releases dialogue focus")
	check.call(ui.get_viewport().gui_get_focus_owner() == return_focus, "close returns keyboard focus to the interaction that opened the conversation")
	fixture.queue_free()
	await tree.process_frame
