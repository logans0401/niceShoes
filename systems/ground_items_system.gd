class_name GroundItemsSystem
extends Node

var _catalog: Node
var _inventory: Node
var _inv_cfg: Resource

## Each: { "item_id": StringName, "quantity": int, "position": Vector2, "ttl": float }
var _drops: Array = []


func configure(catalog: Node, inventory: Node, inv_balance: Resource) -> void:
	_catalog = catalog
	_inventory = inventory
	_inv_cfg = inv_balance
	if _inv_cfg == null:
		_inv_cfg = load("res://data/default_inventory_balance.tres") as Resource


func spawn_drop(item_id: StringName, quantity: int, world_position: Vector2, ttl_override: float = -1.0) -> void:
	if quantity <= 0:
		return
	var ttl: float = ttl_override
	if ttl < 0.0:
		ttl = float(_inv_cfg.ground_item_decay_seconds)
	_drops.append(
		{
			"item_id": item_id,
			"quantity": quantity,
			"position": world_position,
			"ttl": ttl,
		}
	)


func get_drop_count() -> int:
	return _drops.size()


func _process(delta: float) -> void:
	var i: int = _drops.size() - 1
	while i >= 0:
		var d: Dictionary = _drops[i] as Dictionary
		var ttl: float = float(d.get("ttl", 0.0))
		ttl -= delta
		d["ttl"] = ttl
		if ttl <= 0.0:
			_drops.remove_at(i)
		i -= 1


func try_pickup(character_id: StringName, picker_position: Vector2) -> bool:
	if _inventory == null:
		return false
	var radius: float = float(_inv_cfg.pickup_radius)
	var idx: int = -1
	var best_d: Dictionary = {}
	var best_dist: float = INF
	for j in range(_drops.size()):
		var d: Dictionary = _drops[j] as Dictionary
		var pos: Vector2 = d.get("position", Vector2.ZERO) as Vector2
		var dist: float = pos.distance_to(picker_position)
		if dist <= radius and dist < best_dist:
			best_dist = dist
			best_d = d
			idx = j
	if idx < 0:
		return false
	var item_id: StringName = best_d.get("item_id", &"") as StringName
	var qty: int = int(best_d.get("quantity", 0))
	var left: int = _inventory.try_add_item(character_id, item_id, qty)
	if left == qty:
		return false
	if left > 0:
		best_d["quantity"] = left
		_drops[idx] = best_d
	else:
		_drops.remove_at(idx)
	return true
