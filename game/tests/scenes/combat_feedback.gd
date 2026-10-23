extends Node3D
## Fullscreen combat HUD fixture with a weapon, health and family-ammo services.

@onready var _player: PlayerController = $Player
@onready var _weapon: WeaponController = $Player/WeaponController
@onready var _actions: WeaponStateMachine = $Player/WeaponStateMachine
@onready var _hud: PlayerHUD = $PlayerHUD

var _health: HealthState
var _inventory: GridInventory
var _ammo: AmmoPouch
var _equipment: EquipmentService


func _ready() -> void:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = &"fixture_pistol"
	definition.display_name = "Street Pistol"
	definition.weapon_family = &"pistol"
	definition.magazine_capacity = 12
	definition.base_stats = {"damage": 24.0, "fire_rate_per_second": 5.0, "range_m": 40.0, "spread_degrees": 0.2, "recoil_degrees": 0.4}
	_inventory = GridInventory.new(Vector2i(4, 3))
	_ammo = AmmoPouch.new(100)
	_ammo.add_ammo("pistol", 36)
	var pistol: ItemInstance = ItemInstance.new()
	pistol.uuid = "00000000-0000-4000-8000-000000000001"
	pistol.item_id = definition.item_id
	pistol.grid_position = Vector2i.ZERO
	pistol.dimensions = Vector2i.ONE
	pistol.rarity_tier = &"common"
	pistol.magazine_ammo = 9
	_inventory.try_add_item(pistol)
	_equipment = EquipmentService.new(_inventory, {"fixture_pistol": definition}, _ammo)
	_equipment.equip_item(pistol.uuid)
	_health = HealthState.new(100)
	_health.apply_damage(18, "fixture")
	_actions.configure(_player, _weapon, _equipment, ConsumableService.new(_inventory, {"fixture_pistol": definition}, _health), _health)
	_hud.configure(_health, _actions, _equipment)
