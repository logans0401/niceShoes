class_name CorpseLootSystem
extends Node

var _inventory: Node
var _trade: Node
var _inv_cfg: Resource
@export var corpse_decay_seconds: float = 60.0

## corpse_id -> { "bag": Array same shape as inventory bag, "position": Vector2, "ttl": float }
var _corpses: Dictionary = {}


func configure(inventory: Node, trade_system: Node, inv_balance: Resource) -> void:
	_inventory = inventory
	_trade = trade_system
	_inv_cfg = inv_balance
	if _inv_cfg == null:
		_inv_cfg = load("res://data/default_inventory_balance.tres") as Resource


func register_corpse(corpse_id: StringName, bag_snapshot: Array, world_position: Vector2) -> void:
	_corpses[corpse_id] = {"bag": bag_snapshot, "position": world_position, "ttl": corpse_decay_seconds}


func list_corpse_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in _corpses.keys():
		ids.append(StringName(str(key)))
	return ids


func get_corpse_bag(corpse_id: StringName) -> Array:
	var c: Dictionary = _corpses.get(corpse_id, {}) as Dictionary
	return (c.get("bag", []) as Array).duplicate(true)


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
	var qty: int = int(cdict.get("quantity", 0))
	var overflow: int = 0
	if _inventory.has_method("try_add_cell"):
		overflow = int(_inventory.call("try_add_cell", looter_id, cdict.duplicate(true)))
	else:
		var item_id: StringName = cdict.get("item_id", &"") as StringName
		overflow = _inventory.try_add_item(looter_id, item_id, qty)
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


func _process(delta: float) -> void:
	var erase_ids: Array = []
	for key in _corpses.keys():
		var c: Dictionary = _corpses[key] as Dictionary
		var ttl: float = float(c.get("ttl", corpse_decay_seconds)) - delta
		c["ttl"] = ttl
		if ttl <= 0.0:
			erase_ids.append(key)
	for key2 in erase_ids:
		_corpses.erase(key2)
