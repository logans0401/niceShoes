class_name CorpseLootSystem
extends Node

var _inventory: Node
var _trade: Node
var _inv_cfg: Resource

## corpse_id -> { "bag": Array same shape as inventory bag, "position": Vector2 }
var _corpses: Dictionary = {}


func configure(inventory: Node, trade_system: Node, inv_balance: Resource) -> void:
	_inventory = inventory
	_trade = trade_system
	_inv_cfg = inv_balance
	if _inv_cfg == null:
		_inv_cfg = load("res://data/default_inventory_balance.tres") as Resource


func register_corpse(corpse_id: StringName, bag_snapshot: Array, world_position: Vector2) -> void:
	_corpses[corpse_id] = {"bag": bag_snapshot, "position": world_position}


func get_corpse_position(corpse_id: StringName) -> Vector2:
	var c: Dictionary = _corpses.get(corpse_id, {}) as Dictionary
	return c.get("position", Vector2.ZERO) as Vector2


func loot_bag_slot_to_character(
	looter_id: StringName,
	corpse_id: StringName,
	corpse_slot: int,
) -> Error:
	if _inventory == null or _trade == null:
		return FAILED
	var corpse: Dictionary = _corpses.get(corpse_id, {}) as Dictionary
	if corpse.is_empty():
		return ERR_DOES_NOT_EXIST
	var bag: Array = corpse.get("bag", []) as Array
	if corpse_slot < 0 or corpse_slot >= bag.size():
		return FAILED
	var cell: Variant = bag[corpse_slot]
	if cell == null:
		return ERR_DOES_NOT_EXIST
	var looter_pos: Vector2 = _trade.get_character_position(looter_id)
	var corpse_pos: Vector2 = get_corpse_position(corpse_id)
	var max_r: float = float(_inv_cfg.trade_range)
	if looter_pos.distance_to(corpse_pos) > max_r:
		return FAILED
	var cdict: Dictionary = cell as Dictionary
	var item_id: StringName = cdict.get("item_id", &"") as StringName
	var qty: int = int(cdict.get("quantity", 0))
	var overflow: int = _inventory.try_add_item(looter_id, item_id, qty)
	if overflow > 0:
		if overflow == qty:
			return FAILED
		cdict["quantity"] = overflow
		bag[corpse_slot] = cdict
	else:
		bag[corpse_slot] = null
	_remove_corpse_if_empty(corpse_id, bag)
	return OK


func _remove_corpse_if_empty(corpse_id: StringName, bag: Array) -> void:
	var any: bool = false
	for c in bag:
		if c != null:
			any = true
			break
	if not any:
		_corpses.erase(corpse_id)


func snapshot_character_bag(character_id: StringName) -> Array:
	if _inventory == null:
		return []
	return _inventory.get_bag_copy(character_id).duplicate(true)
