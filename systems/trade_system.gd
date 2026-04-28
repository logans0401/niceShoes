class_name TradeSystem
extends Node

var _inventory: Node
var _inv_cfg: Resource
## character_id -> last known world position (simulation / map updates this)
var _positions: Dictionary = {}


func configure(inventory: Node, inv_balance: Resource) -> void:
	_inventory = inventory
	_inv_cfg = inv_balance
	if _inv_cfg == null:
		_inv_cfg = load("res://data/default_inventory_balance.tres") as Resource


func set_character_position(character_id: StringName, world_position: Vector2) -> void:
	_positions[character_id] = world_position


func get_character_position(character_id: StringName) -> Vector2:
	return _positions.get(character_id, Vector2.ZERO) as Vector2


func are_in_trade_range(a: StringName, b: StringName) -> bool:
	var pa: Vector2 = get_character_position(a)
	var pb: Vector2 = get_character_position(b)
	var limit: float = float(_inv_cfg.trade_range)
	return pa.distance_to(pb) <= limit


func trade_swap_bag_slots(
	char_a: StringName,
	idx_a: int,
	char_b: StringName,
	idx_b: int,
) -> Error:
	if not are_in_trade_range(char_a, char_b):
		return FAILED
	if _inventory == null or not _inventory.has_method("trade_swap_slots"):
		return FAILED
	return _inventory.trade_swap_slots(char_a, idx_a, char_b, idx_b)
