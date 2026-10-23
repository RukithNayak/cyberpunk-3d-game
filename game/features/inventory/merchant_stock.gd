extends RefCounted
class_name MerchantStock
## One runtime-authored Night Market vendor. All offers and prices are code-owned.

const MERCHANT_ID: String = "mara_vega"
const INVENTORY_ID: String = "mara_market_stock"
const MEDKIT_OFFER: String = "street_medkit"
const MEDKIT_PRICE: int = 40

var _inventory: GridInventory
var _credits: MissionDirector
var _definition: ItemDefinition
var _remaining: int = 3
var _purchases: Dictionary = {}


func configure(inventory: GridInventory, credits: MissionDirector, definition: ItemDefinition) -> bool:
	if _inventory != null or inventory == null or credits == null or definition == null or not definition.is_valid():
		return false
	if definition.item_id != &"street_medkit":
		return false
	_inventory = inventory
	_credits = credits
	_definition = definition.duplicate(true) as ItemDefinition
	return true


func is_available(inventory_id: String, owner_id: String) -> bool:
	return inventory_id == INVENTORY_ID and owner_id == MERCHANT_ID and _inventory != null and _remaining > 0


func get_offer() -> Dictionary:
	return {"offer_id": MEDKIT_OFFER, "name": _definition.display_name if _definition != null else "STREET MEDKIT", "price": MEDKIT_PRICE, "remaining": _remaining}


## Resolve only an explicit player purchase request for the one authored item.
func purchase_offer_from_text(player_text: String) -> String:
	if _inventory == null or player_text.strip_edges().is_empty():
		return ""
	var normalized: String = player_text.to_lower().replace("’", "'")
	if not normalized.contains("medkit") or normalized.contains("don't") or normalized.contains("do not") or normalized.contains("no thanks"):
		return ""
	for phrase: String in ["buy", "purchase", "i'll take", "ill take", "i'd like", "id like", "i want", "can i get", "could i get", "can i have", "get me", "grab me", "take a"]:
		if normalized.contains(phrase):
			return MEDKIT_OFFER
	return ""


func purchase(owner_id: String, offer_id: String, transaction_id: String) -> Dictionary:
	if not _valid_transaction_id(transaction_id):
		return _failure("invalid_transaction")
	if _purchases.has(transaction_id):
		return (_purchases[transaction_id] as Dictionary).duplicate(true)
	if owner_id != MERCHANT_ID or offer_id != MEDKIT_OFFER or _inventory == null or _credits == null:
		return _failure("merchant_not_authorized")
	if _remaining <= 0:
		return _failure("stock_exhausted")
	if _credits.get_credits() < MEDKIT_PRICE:
		return _failure("insufficient_funds")
	var item: ItemInstance = ItemInstance.new()
	item.uuid = item.generate_uuid()
	item.item_id = _definition.item_id
	item.dimensions = _definition.dimensions
	var inserted: bool = false
	for y: int in range(_inventory.grid_size.y):
		for x: int in range(_inventory.grid_size.x):
			item.grid_position = Vector2i(x, y)
			if _inventory.try_add_item(item):
				inserted = true
				break
		if inserted:
			break
	if not inserted:
		return _failure("inventory_full")
	if not _credits.spend_credits(MEDKIT_PRICE):
		_inventory.remove_item(item.uuid)
		return _failure("insufficient_funds")
	_remaining -= 1
	var result: Dictionary = {"ok": true, "item_id": MEDKIT_OFFER, "price": MEDKIT_PRICE, "remaining": _remaining}
	_purchases[transaction_id] = result.duplicate(true)
	return result


func _valid_transaction_id(value: String) -> bool:
	return not value.is_empty() and value.length() <= 128 and value.is_valid_identifier()


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
