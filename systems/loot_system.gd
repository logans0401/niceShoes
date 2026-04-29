class_name LootSystem
extends Node

signal loot_generated(context_id: StringName, drops: Array)

var _ground: Node
var _corpse: Node
var _inventory: Node
var _item_instances: Node = null
var _combat_balance: Resource = null
var _loot_table: Resource = null


func configure(
	ground_items: Node,
	corpse_loot: Node,
	inventory: Node,
	item_instances: Node = null,
	combat_balance: Resource = null,
	loot_table: Resource = null,
) -> void:
	_ground = ground_items
	_corpse = corpse_loot
	_inventory = inventory
	_item_instances = item_instances
	_combat_balance = combat_balance
	if _combat_balance == null:
		_combat_balance = load("res://data/default_combat_balance.tres") as Resource
	_loot_table = loot_table
	if _loot_table == null:
		_loot_table = load("res://data/default_loot_table.tres") as Resource


func roll_drops(context_id: StringName, table_id: StringName) -> Array:
	var tier: int = 1
	var ts: String = String(table_id)
	if ts.begins_with("tier_"):
		tier = int(ts.trim_prefix("tier_"))
	elif ts.is_valid_int():
		tier = int(ts)
	tier = clampi(tier, 1, 20)
	var pool: Array = _loot_table.get_pool_for_tier(tier)
	var count: int = 1 + (1 if randf() < minf(0.75, float(tier) * 0.035) else 0)
	var drops: Array = []
	for i in range(count):
		var raw_item: Variant = pool[randi_range(0, pool.size() - 1)]
		var item_id: StringName = raw_item as StringName if raw_item is StringName else StringName(str(raw_item))
		if _item_instances != null and _item_instances.has_method("create_cell"):
			drops.append(_item_instances.call("create_cell", item_id, 1, tier, String(context_id)))
		else:
			drops.append({"item_id": item_id, "quantity": 1})
	loot_generated.emit(context_id, drops)
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


func register_corpse_with_drops(corpse_id: StringName, world_position: Vector2, loot_tier: int) -> void:
	if _corpse == null:
		return
	var drops: Array = roll_drops(corpse_id, StringName("tier_%d" % clampi(loot_tier, 1, 20)))
	_corpse.register_corpse(corpse_id, drops, world_position)


func level_to_loot_tier(level: int) -> int:
	if _combat_balance == null:
		_combat_balance = load("res://data/default_combat_balance.tres") as Resource
	return _combat_balance.level_to_loot_tier(level)
