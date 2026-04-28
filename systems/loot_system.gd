class_name LootSystem
extends Node

signal loot_generated(context_id: StringName, drops: Array)

var _ground: Node
var _corpse: Node
var _inventory: Node


func configure(ground_items: Node, corpse_loot: Node, inventory: Node) -> void:
	_ground = ground_items
	_corpse = corpse_loot
	_inventory = inventory


func roll_drops(_context_id: StringName, _table_id: StringName) -> Array:
	var drops: Array = []
	loot_generated.emit(_context_id, drops)
	return drops


func drop_item_to_ground(item_id: StringName, quantity: int, world_position: Vector2) -> void:
	if _ground != null and _ground.has_method("spawn_drop"):
		_ground.spawn_drop(item_id, quantity, world_position)


func register_corpse_from_character(
	character_id: StringName,
	corpse_id: StringName,
	world_position: Vector2,
) -> void:
	if _corpse == null or _inventory == null:
		return
	var snap: Array = _inventory.get_bag_copy(character_id).duplicate(true)
	_corpse.register_corpse(corpse_id, snap, world_position)
