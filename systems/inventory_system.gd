class_name InventorySystem
extends Node

const _InvBalScr := preload("res://data/inventory_balance_config.gd")
const _EqScr := preload("res://scripts/equipment_schema.gd")

signal inventory_changed(character_id: StringName)

var _catalog: Node
var _registry: Node
var _equipment: Node
var _inv_cfg: Resource
var _item_instances: Node = null

## character_id -> Array of slot cells (null or { "item_id": StringName, "instance_id": StringName, "quantity": int })
var _bags: Dictionary = {}


func configure(catalog: Node, registry: Node, inv_balance: Resource, item_instances: Node = null) -> void:
	_catalog = catalog
	_registry = registry
	_inv_cfg = inv_balance
	_item_instances = item_instances
	if _inv_cfg == null:
		_inv_cfg = load("res://data/default_inventory_balance.tres") as Resource


func attach_equipment(equipment: Node) -> void:
	_equipment = equipment


func attach_item_instances(item_instances: Node) -> void:
	_item_instances = item_instances


func get_registry() -> Node:
	return _registry


func get_bag_slot_count() -> int:
	return int(_inv_cfg.bag_slot_count)


func get_bag_copy(character_id: StringName) -> Array:
	return _ensure_bag(character_id).duplicate()


func get_cell(character_id: StringName, index: int) -> Variant:
	var bag: Array = _ensure_bag(character_id)
	if index < 0 or index >= bag.size():
		return null
	return bag[index]


func try_add_item(character_id: StringName, item_id: StringName, amount: int) -> int:
	if _catalog == null or amount <= 0:
		return amount
	var def: Resource = _catalog.get_definition(item_id)
	if def == null:
		return amount
	var left: int = amount
	var bag: Array = _ensure_bag(character_id)
	var max_stack: int = maxi(1, int(def.max_stack))
	for i in range(bag.size()):
		var cell: Variant = bag[i]
		if cell == null:
			continue
		var c: Dictionary = cell as Dictionary
		if _cell_item_id(c) != item_id:
			continue
		var q: int = int(c.get("quantity", 0))
		var room: int = max_stack - q
		if room <= 0:
			continue
		var add: int = mini(room, left)
		c["quantity"] = q + add
		bag[i] = c
		left -= add
		if left <= 0:
			_recalc_burden(character_id)
			inventory_changed.emit(character_id)
			return 0
	while left > 0:
		var idx: int = _first_free_index(bag)
		if idx < 0:
			break
		var chunk: int = mini(max_stack, left)
		bag[idx] = _make_cell(item_id, chunk)
		left -= chunk
	_recalc_burden(character_id)
	inventory_changed.emit(character_id)
	return left


func try_take_single(character_id: StringName, bag_index: int) -> Dictionary:
	var bag: Array = _ensure_bag(character_id)
	if bag_index < 0 or bag_index >= bag.size():
		return {}
	var cell: Variant = bag[bag_index]
	if cell == null:
		return {}
	var c: Dictionary = cell as Dictionary
	var id: StringName = _cell_item_id(c)
	var q: int = int(c.get("quantity", 0))
	var taken: Dictionary = c.duplicate(true)
	taken["quantity"] = 1
	if q <= 1:
		bag[bag_index] = null
	else:
		c["quantity"] = q - 1
		bag[bag_index] = c
	_recalc_burden(character_id)
	inventory_changed.emit(character_id)
	return taken


func refund_single(character_id: StringName, item_id: StringName) -> void:
	try_add_item(character_id, item_id, 1)


func try_add_cell(character_id: StringName, cell: Dictionary) -> int:
	var item_id: StringName = _cell_item_id(cell)
	var qty: int = int(cell.get("quantity", 1))
	if item_id == &"" or qty <= 0:
		return qty
	var bag: Array = _ensure_bag(character_id)
	var idx: int = _first_free_index(bag)
	if idx < 0:
		return qty
	bag[idx] = cell.duplicate(true)
	_recalc_burden(character_id)
	inventory_changed.emit(character_id)
	return 0


func try_add_equipped_key(character_id: StringName, item_key: StringName, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	if _item_instances != null and _item_instances.has_method("has_instance") and bool(_item_instances.call("has_instance", item_key)):
		var inst: Resource = _item_instances.call("get_instance", item_key) as Resource
		if inst == null:
			return quantity
		return try_add_cell(character_id, {"item_id": inst.item_id, "instance_id": item_key, "quantity": quantity})
	return try_add_item(character_id, item_key, quantity)


func take_entire_slot(character_id: StringName, bag_index: int) -> Variant:
	var bag: Array = _ensure_bag(character_id)
	if bag_index < 0 or bag_index >= bag.size():
		return null
	var cell: Variant = bag[bag_index]
	bag[bag_index] = null
	_recalc_burden(character_id)
	inventory_changed.emit(character_id)
	return cell


func place_cell_at(character_id: StringName, bag_index: int, cell: Variant) -> Error:
	if cell == null:
		return OK
	var bag: Array = _ensure_bag(character_id)
	if bag_index < 0 or bag_index >= bag.size():
		return FAILED
	if bag[bag_index] != null:
		return FAILED
	bag[bag_index] = cell
	_recalc_burden(character_id)
	inventory_changed.emit(character_id)
	return OK


func swap_bag_slots(character_id: StringName, index_a: int, index_b: int) -> void:
	var bag: Array = _ensure_bag(character_id)
	if index_a < 0 or index_b < 0 or index_a >= bag.size() or index_b >= bag.size():
		return
	var tmp: Variant = bag[index_a]
	bag[index_a] = bag[index_b]
	bag[index_b] = tmp
	_recalc_burden(character_id)
	inventory_changed.emit(character_id)


func trade_swap_slots(
	char_a: StringName,
	idx_a: int,
	char_b: StringName,
	idx_b: int,
) -> Error:
	var bag_a: Array = _ensure_bag(char_a)
	var bag_b: Array = _ensure_bag(char_b)
	if idx_a < 0 or idx_b < 0 or idx_a >= bag_a.size() or idx_b >= bag_b.size():
		return FAILED
	var tmp: Variant = bag_a[idx_a]
	bag_a[idx_a] = bag_b[idx_b]
	bag_b[idx_b] = tmp
	_recalc_burden(char_a)
	_recalc_burden(char_b)
	inventory_changed.emit(char_a)
	inventory_changed.emit(char_b)
	return OK


func export_state() -> Dictionary:
	var out: Dictionary = {}
	for k in _bags.keys():
		out[String(k)] = (_bags[k] as Array).duplicate(true)
	return out


func import_state(state: Dictionary) -> void:
	_bags.clear()
	for k in state.keys():
		var cid: StringName = StringName(k)
		var arr: Array = (state[k] as Array).duplicate(true)
		_bags[cid] = arr
	for cid in _bags.keys():
		_recalc_burden(cid)


func recalculate_burden(character_id: StringName) -> void:
	_recalc_burden(character_id)


func remove_quantity_from_slot(character_id: StringName, bag_index: int, quantity: int) -> Error:
	if quantity <= 0:
		return OK
	var bag: Array = _ensure_bag(character_id)
	if bag_index < 0 or bag_index >= bag.size():
		return FAILED
	var cell: Variant = bag[bag_index]
	if cell == null:
		return ERR_DOES_NOT_EXIST
	var c: Dictionary = cell as Dictionary
	var q: int = int(c.get("quantity", 0))
	if q < quantity:
		return ERR_INVALID_DATA
	if q == quantity:
		bag[bag_index] = null
	else:
		c["quantity"] = q - quantity
		bag[bag_index] = c
	_recalc_burden(character_id)
	inventory_changed.emit(character_id)
	return OK


func _ensure_bag(character_id: StringName) -> Array:
	var n: int = int(_inv_cfg.bag_slot_count)
	if not _bags.has(character_id):
		var a: Array = []
		a.resize(n)
		for i in range(n):
			a[i] = null
		_bags[character_id] = a
		return a
	var bag: Array = _bags[character_id] as Array
	if bag.size() < n:
		var old_n: int = bag.size()
		bag.resize(n)
		for i in range(old_n, n):
			bag[i] = null
	return bag


func _first_free_index(bag: Array) -> int:
	for i in range(bag.size()):
		if bag[i] == null:
			return i
	return -1


func _recalc_burden(character_id: StringName) -> void:
	if _registry == null or _catalog == null:
		return
	var data: Resource = _registry.get_character(character_id)
	if data == null:
		return
	var total: float = 0.0
	var bag: Array = _ensure_bag(character_id)
	for cell in bag:
		if cell == null:
			continue
		var c: Dictionary = cell as Dictionary
		var iid: StringName = _cell_item_id(c)
		var q: int = int(c.get("quantity", 0))
		var unit_w: float = _catalog.get_weight(iid)
		if _item_instances != null and _item_instances.has_method("get_weight_for_cell"):
			unit_w = float(_item_instances.call("get_weight_for_cell", c))
		total += unit_w * float(q)
	if _equipment != null:
		for slot in _EqScr.ALL_SLOTS:
			var ekey: StringName = _equipment.get_equipped_key(character_id, StringName(slot)) if _equipment.has_method("get_equipped_key") else _equipment.get_equipped_item(character_id, StringName(slot))
			if String(ekey) != "":
				if _item_instances != null and _item_instances.has_method("has_instance") and bool(_item_instances.call("has_instance", ekey)):
					var inst: Resource = _item_instances.call("get_instance", ekey) as Resource
					if inst != null:
						total += float(inst.weight)
				else:
					total += _catalog.get_weight(ekey)
	data.laden_burden = total


func _make_cell(item_id: StringName, quantity: int) -> Dictionary:
	if _item_instances != null and _item_instances.has_method("create_cell"):
		return _item_instances.call("create_cell", item_id, quantity, 1, "inventory") as Dictionary
	return {"item_id": item_id, "quantity": quantity}


func _cell_item_id(cell: Dictionary) -> StringName:
	if _item_instances != null and _item_instances.has_method("get_cell_item_id"):
		return _item_instances.call("get_cell_item_id", cell) as StringName
	var raw: Variant = cell.get("item_id", &"")
	return raw as StringName if raw is StringName else StringName(str(raw))
