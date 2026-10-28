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
	provider.valid_response_json = JSON.stringify({"dialogue_text": "Hey\\nHow's the market treating you?", "proposed_action": null})
	ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").text = "hey"
	ui.call("_submit_prompt")
	await tree.create_timer(0.08).timeout
	check.call(log.get_parsed_text().contains("Hey\nHow's the market treating you?") and not log.get_parsed_text().contains("\\n"), "NPC transcript renders model newlines as line breaks, not visible escape sequences")
	check.call(ui.find_child("MarketStock", true, false) != null, "Mara conversation exposes her authored market stock panel")
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
	var market_inventory: GridInventory = GridInventory.new(Vector2i(2, 2))
	var market_medkit: ItemDefinition = ItemDefinition.new()
	market_medkit.item_id = &"street_medkit"
	market_medkit.display_name = "STREET MEDKIT"
	market_medkit.consumable_heal_amount = 25
	var market_stock: MerchantStock = MerchantStock.new()
	var stock_configured: bool = market_stock.configure(market_inventory, source_director, market_medkit)
	ui.configure_market_stock(market_stock)
	check.call(market_stock.purchase_offer_from_text("Could I get one medkit?") == MerchantStock.MEDKIT_OFFER and market_stock.purchase_offer_from_text("Don't buy a medkit") == "", "text intent recognizes a clear purchase and ignores an explicit negative request")
	check.call(not ui.find_child("MarketStock", true, false).visible, "text purchase can be made without opening or clicking the stock panel")
	var purchase_prompt: LineEdit = ui.find_child("Prompt", true, false) as LineEdit
	purchase_prompt.text = "Could I get a medkit?"
	ui.call("_submit_prompt")
	var first_purchase: Dictionary = {"ok": market_inventory.get_item_count() == 1}
	var purchase_credits: int = source_director.get_credits()
	var purchase_items: int = market_inventory.get_item_count()
	var purchase_stock: int = int(market_stock.get_offer()["remaining"])
	var replay_purchase: Dictionary = market_stock.purchase("mara_vega", MerchantStock.MEDKIT_OFFER, "mara_text_buy_1")
	var denied_purchase: Dictionary = market_stock.purchase("someone_else", MerchantStock.MEDKIT_OFFER, "market_test_purchase_2")
	(ui.find_child("MarketStockButton", true, false) as Button).pressed.emit()
	check.call(stock_configured and ui.find_child("MarketStock", true, false).visible, "Mara opens her configured stock panel from the conversation")
	check.call(first_purchase.get("ok", false) and purchase_credits == 85 and purchase_items == 1 and purchase_stock == 2 and log.get_parsed_text().contains("Sure, I've got a medkit for you."), "player buys an authored medkit by asking Mara in text and receives a conversational confirmation")
	check.call(replay_purchase.get("ok", false) and source_director.get_credits() == 85 and market_inventory.get_item_count() == 1 and int(market_stock.get_offer()["remaining"]) == 2, "replayed merchant purchase does not charge twice or duplicate the item")
	check.call(not denied_purchase.get("ok", false) and denied_purchase.get("reason") == "merchant_not_authorized", "purchase rejects a caller that does not own the merchant")
	var rich_wallet: MissionDirector = MissionDirector.new()
	rich_wallet.configure([load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate], fixture.get("_registry") as EntityRegistry, fixture.get("mission_factions") as FactionState, func(_uuid: String) -> bool: return true)
	var rich_snapshot: Dictionary = source_director.capture_snapshot()
	rich_snapshot["credits"] = 125
	var rich_prepared: Dictionary = rich_wallet.prepare_snapshot(rich_snapshot)
	if rich_prepared.get("ok", false):
		rich_wallet.commit_prepared_snapshot(rich_prepared["prepared"])
	var exhausted_stock: MerchantStock = MerchantStock.new()
	exhausted_stock.configure(GridInventory.new(Vector2i(4, 2)), rich_wallet, market_medkit)
	var sale_one: Dictionary = exhausted_stock.purchase("mara_vega", MerchantStock.MEDKIT_OFFER, "market_test_sale_1")
	var sale_two: Dictionary = exhausted_stock.purchase("mara_vega", MerchantStock.MEDKIT_OFFER, "market_test_sale_2")
	var sale_three: Dictionary = exhausted_stock.purchase("mara_vega", MerchantStock.MEDKIT_OFFER, "market_test_sale_3")
	var sold_out: Dictionary = exhausted_stock.purchase("mara_vega", MerchantStock.MEDKIT_OFFER, "market_test_sale_4")
	check.call(rich_prepared.get("ok", false) and sale_one.get("ok", false) and sale_two.get("ok", false) and sale_three.get("ok", false) and sold_out.get("reason") == "stock_exhausted", "fixed merchant stock sells out and then rejects further purchases")
	var full_inventory: GridInventory = GridInventory.new(Vector2i.ONE)
	var blocking_item: ItemInstance = ItemInstance.new()
	blocking_item.uuid = blocking_item.generate_uuid()
	blocking_item.item_id = &"street_medkit"
	full_inventory.try_add_item(blocking_item)
	var full_stock: MerchantStock = MerchantStock.new()
	full_stock.configure(full_inventory, source_director, market_medkit)
	var full_result: Dictionary = full_stock.purchase("mara_vega", MerchantStock.MEDKIT_OFFER, "market_test_full")
	check.call(full_result.get("reason") == "inventory_full" and source_director.get_credits() == 85 and int(full_stock.get_offer()["remaining"]) == 3, "full inventory rejects purchase without charging or consuming stock")
	source_director.spend_credits(50)
	var funds_result: Dictionary = market_stock.purchase("mara_vega", MerchantStock.MEDKIT_OFFER, "market_test_funds")
	check.call(funds_result.get("reason") == "insufficient_funds" and market_inventory.get_item_count() == 1 and int(market_stock.get_offer()["remaining"]) == 2, "insufficient credits reject purchase without changing inventory or stock")
	var restored: MissionDirector = MissionDirector.new()
	var restore_ok: bool = restored.configure([load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate], fixture.get("_registry") as EntityRegistry, fixture.get("mission_factions") as FactionState, func(_uuid: String) -> bool: return true)
	var prepared: Dictionary = restored.prepare_snapshot(source_director.capture_snapshot())
	if prepared.get("ok", false):
		restored.commit_prepared_snapshot(prepared["prepared"])
	var restored_journal: MissionJournal = MissionJournal.new()
	ui.add_child(restored_journal)
	check.call(restore_ok and prepared.get("ok", false) and restored.get_credits() == 35 and restored_journal.configure(restored) and restored_journal.get_node("Credits").text == "CREDITS  // 35", "mission journal restores the remaining balance after vendor purchases")

	provider.valid_response_json = JSON.stringify({"dialogue_text": "Trade desk is offline.", "proposed_action": {"action": "initiate_trade", "parameters": {"inventory_id": "market_stock"}}})
	ui.get_node("Root/Center/Panel/Columns/Conversation/MessageInput/Prompt").text = "open trade"
	ui.call("_submit_prompt")
	await tree.create_timer(0.08).timeout
	check.call(log.get_parsed_text().contains("I don't have that on the counter"), "unauthorized inventory-backed trade receives a natural in-character response")

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
