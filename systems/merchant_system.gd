class_name MerchantSystem
extends Node

var _catalog: Node
var _inventory: Node
var _registry: Node
var _item_instances: Node = null

## merchant_id -> Array of { "item_id": String, "quantity": int }
var _stock: Dictionary = {}


func configure(catalog: Node, inventory: Node, registry: Node, item_instances: Node = null) -> void:
	_catalog = catalog
	_inventory = inventory
	_registry = registry
	_item_instances = item_instances


func set_merchant_stock(merchant_id: StringName, offers: Array) -> void:
	_stock[merchant_id] = offers


func get_merchant_stock(merchant_id: StringName) -> Array:
	return _stock.get(merchant_id, []) as Array


func buy_item(buyer_id: StringName, merchant_id: StringName, item_id: StringName, quantity: int = 1) -> Error:
	if quantity <= 0 or _catalog == null or _inventory == null or _registry == null:
		return FAILED
	var def: Resource = _catalog.get_definition(item_id)
	if def == null:
		return ERR_DOES_NOT_EXIST
	var data: Resource = _registry.get_character(buyer_id)
	if data == null:
		return ERR_DOES_NOT_EXIST
	var unit_price: int = int(def.buy_price)
	var price: int = unit_price * quantity
	if int(data.gold) < price:
		return FAILED
	if not _consume_stock(merchant_id, item_id, quantity):
		return ERR_UNAVAILABLE
	data.gold = int(data.gold) - price
	var leftover: int = _inventory.try_add_item(buyer_id, item_id, quantity)
	if leftover > 0:
		data.gold += leftover * unit_price
		_restore_stock(merchant_id, item_id, leftover)
	if leftover == quantity:
		return FAILED
	return OK


func sell_from_bag(seller_id: StringName, merchant_id: StringName, bag_index: int, quantity: int = 1) -> Error:
	if quantity <= 0 or _catalog == null or _inventory == null or _registry == null:
		return FAILED
	var cell: Variant = _inventory.get_cell(seller_id, bag_index)
	if cell == null:
		return ERR_DOES_NOT_EXIST
	var c: Dictionary = cell as Dictionary
	var item_id: StringName = _cell_item_id(c)
	var q: int = int(c.get("quantity", 0))
	if q < quantity:
		return ERR_INVALID_DATA
	var def: Resource = _catalog.get_definition(item_id)
	if def == null:
		return ERR_DOES_NOT_EXIST
	var data: Resource = _registry.get_character(seller_id)
	if data == null:
		return ERR_DOES_NOT_EXIST
	var unit_sell: int = int(def.sell_price)
	if _item_instances != null and _item_instances.has_method("get_sell_price_for_cell"):
		unit_sell = int(_item_instances.call("get_sell_price_for_cell", c))
	var payout: int = unit_sell * quantity
	if _inventory.remove_quantity_from_slot(seller_id, bag_index, quantity) != OK:
		return FAILED
	data.gold = int(data.gold) + payout
	_restore_stock(merchant_id, item_id, quantity)
	return OK


func _consume_stock(merchant_id: StringName, item_id: StringName, quantity: int) -> bool:
	var list: Array = _stock.get(merchant_id, []) as Array
	for entry in list:
		var d: Dictionary = entry as Dictionary
		if String(d.get("item_id", "")) != String(item_id):
			continue
		var q: int = int(d.get("quantity", 0))
		if q < quantity:
			return false
		d["quantity"] = q - quantity
		return true
	return false


func _restore_stock(merchant_id: StringName, item_id: StringName, quantity: int) -> void:
	var list: Array = _stock.get(merchant_id, []) as Array
	for entry in list:
		var d: Dictionary = entry as Dictionary
		if String(d.get("item_id", "")) == String(item_id):
			d["quantity"] = int(d.get("quantity", 0)) + quantity
			return
	list.append({"item_id": String(item_id), "quantity": quantity})
	_stock[merchant_id] = list


func _cell_item_id(cell: Dictionary) -> StringName:
	if _item_instances != null and _item_instances.has_method("get_cell_item_id"):
		return _item_instances.call("get_cell_item_id", cell) as StringName
	var raw: Variant = cell.get("item_id", &"")
	return raw as StringName if raw is StringName else StringName(str(raw))
