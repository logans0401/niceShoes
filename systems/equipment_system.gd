class_name EquipmentSystem
extends Node

const _EqScr := preload("res://scripts/equipment_schema.gd")

signal equipment_changed(character_id: StringName)

var _inventory: Node
var _catalog: Node

## character_id -> slot_name String -> item_id StringName
var _loadouts: Dictionary = {}


func configure(inventory: Node, catalog: Node) -> void:
	_inventory = inventory
	_catalog = catalog


func get_loadout(character_id: StringName) -> Dictionary:
	return _resolve_loadout_dict(character_id).duplicate(true)


func get_equipped_item(character_id: StringName, slot: StringName) -> StringName:
	var loadout: Dictionary = _resolve_loadout_dict(character_id)
	var item: Variant = loadout.get(slot, null)
	if item == null:
		item = loadout.get(String(slot), null)
	if item == null:
		return &""
	return item as StringName


func _resolve_loadout_dict(character_id: StringName) -> Dictionary:
	var ld: Variant = _loadouts.get(character_id, null)
	if ld == null:
		ld = _loadouts.get(String(character_id), null)
	if ld == null:
		return {}
	return ld as Dictionary


func equip_from_bag(character_id: StringName, equip_slot: StringName, bag_index: int) -> Error:
	if _inventory == null or _catalog == null:
		return FAILED
	var took: Dictionary = _inventory.try_take_single(character_id, bag_index)
	if took.is_empty():
		return ERR_DOES_NOT_EXIST
	var item_id: StringName = took.get("item_id", &"") as StringName
	var def: Resource = _catalog.get_definition(item_id)
	if def == null or String(def.equip_slot) != String(equip_slot):
		_inventory.refund_single(character_id, item_id)
		return ERR_INVALID_DATA
	var loadout: Dictionary = _resolve_loadout_dict(character_id)
	var previous: StringName = get_equipped_item(character_id, equip_slot)
	if String(previous) != "":
		var overflow: int = _inventory.try_add_item(character_id, previous, 1)
		if overflow > 0:
			_inventory.refund_single(character_id, item_id)
			return ERR_OUT_OF_MEMORY
	loadout[equip_slot] = item_id
	_loadouts[character_id] = loadout
	_refresh_burden(character_id)
	equipment_changed.emit(character_id)
	return OK


func unequip_to_bag(character_id: StringName, equip_slot: StringName) -> Error:
	if _inventory == null:
		return FAILED
	var item_id: StringName = get_equipped_item(character_id, equip_slot)
	if String(item_id) == "":
		return ERR_DOES_NOT_EXIST
	var overflow: int = _inventory.try_add_item(character_id, item_id, 1)
	if overflow > 0:
		return ERR_OUT_OF_MEMORY
	var loadout: Dictionary = _resolve_loadout_dict(character_id)
	loadout.erase(equip_slot)
	loadout.erase(String(equip_slot))
	_loadouts[character_id] = loadout
	_refresh_burden(character_id)
	equipment_changed.emit(character_id)
	return OK


func clear_for_serialization(character_id: StringName) -> void:
	_loadouts.erase(character_id)
	_loadouts.erase(String(character_id))


func export_state() -> Dictionary:
	var out: Dictionary = {}
	for k in _loadouts.keys():
		var inner: Dictionary = (_loadouts[k] as Dictionary).duplicate(true)
		var serial: Dictionary = {}
		for slot in inner.keys():
			serial[String(slot)] = String(inner[slot])
		out[String(k)] = serial
	return out


func import_state(state: Dictionary) -> void:
	_loadouts.clear()
	for ck in state.keys():
		var loadout: Dictionary = {}
		var raw: Dictionary = state[ck] as Dictionary
		for slot in raw.keys():
			var sk: String = String(slot)
			if not _EqScr.ALL_SLOTS.has(sk):
				continue
			loadout[StringName(slot)] = StringName(raw[slot])
		_loadouts[StringName(ck)] = loadout
	for ck2 in _loadouts.keys():
		_refresh_burden(StringName(ck2))


func _refresh_burden(character_id: StringName) -> void:
	if _inventory != null and _inventory.has_method("recalculate_burden"):
		_inventory.recalculate_burden(character_id)


## Legacy name used by StatsSystem
func equip(character_id: StringName, slot: StringName, item_id: StringName) -> void:
	var loadout: Dictionary = _loadouts.get(character_id, {}) as Dictionary
	loadout[slot] = item_id
	_loadouts[character_id] = loadout
	_refresh_burden(character_id)
	equipment_changed.emit(character_id)


func unequip(character_id: StringName, slot: StringName) -> void:
	var loadout: Dictionary = _loadouts.get(character_id, {}) as Dictionary
	loadout.erase(slot)
	_loadouts[character_id] = loadout
	_refresh_burden(character_id)
	equipment_changed.emit(character_id)
