class_name EquipmentSystem
extends Node

const _EqScr := preload("res://scripts/equipment_schema.gd")

signal equipment_changed(character_id: StringName)

var _inventory: Node
var _catalog: Node
var _item_instances: Node = null

## character_id -> slot_name String -> item key (instance_id preferred, legacy item_id accepted)
var _loadouts: Dictionary = {}


func configure(inventory: Node, catalog: Node, item_instances: Node = null) -> void:
	_inventory = inventory
	_catalog = catalog
	_item_instances = item_instances


func attach_item_instances(item_instances: Node) -> void:
	_item_instances = item_instances


func get_loadout(character_id: StringName) -> Dictionary:
	return _resolve_loadout_dict(character_id).duplicate(true)


func get_equipped_item(character_id: StringName, slot: StringName) -> StringName:
	var key: StringName = get_equipped_key(character_id, slot)
	if key == &"":
		return &""
	if _item_instances != null and _item_instances.has_method("has_instance") and bool(_item_instances.call("has_instance", key)):
		var inst: Resource = _item_instances.call("get_instance", key) as Resource
		if inst != null:
			return inst.item_id as StringName
	return key


func get_equipped_key(character_id: StringName, slot: StringName) -> StringName:
	var loadout: Dictionary = _resolve_loadout_dict(character_id)
	var item: Variant = loadout.get(slot, null)
	if item == null:
		item = loadout.get(String(slot), null)
	if item == null:
		return &""
	return item as StringName


func get_equipped_details(character_id: StringName, slot: StringName) -> Dictionary:
	var key: StringName = get_equipped_key(character_id, slot)
	if key == &"":
		return {}
	if _item_instances != null and _item_instances.has_method("has_instance") and bool(_item_instances.call("has_instance", key)):
		var inst: Resource = _item_instances.call("get_instance", key) as Resource
		if inst != null and inst.has_method("to_dictionary"):
			return inst.call("to_dictionary") as Dictionary
	var item_id: StringName = get_equipped_item(character_id, slot)
	if _catalog == null or item_id == &"":
		return {}
	var def: Resource = _catalog.get_definition(item_id)
	if def == null:
		return {}
	return {
		"item_id": String(item_id),
		"display_name": str(def.display_name),
		"equip_slot": str(def.equip_slot),
		"weapon_kind": str(def.weapon_kind),
		"damage_min": int(def.damage_min),
		"damage_max": int(def.damage_max),
		"damage_type": int(def.damage_type),
		"armor_level": float(def.armor_level),
		"armor_ratings": (def.armor_ratings as Dictionary).duplicate(true),
		"requirements": (def.requirements as Dictionary).duplicate(true),
		"modifiers": (def.modifiers as Dictionary).duplicate(true),
	}


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
	var item_id: StringName = _cell_item_id(took)
	var def: Resource = _catalog.get_definition(item_id)
	if def == null or String(def.equip_slot) != String(equip_slot):
		_inventory.try_add_cell(character_id, took)
		return ERR_INVALID_DATA
	if not _meets_requirements(character_id, took):
		_inventory.try_add_cell(character_id, took)
		return ERR_INVALID_DATA
	var loadout: Dictionary = _resolve_loadout_dict(character_id)
	var previous: StringName = get_equipped_key(character_id, equip_slot)
	if String(previous) != "":
		var overflow: int = _inventory.try_add_equipped_key(character_id, previous, 1)
		if overflow > 0:
			_inventory.try_add_cell(character_id, took)
			return ERR_OUT_OF_MEMORY
	loadout[equip_slot] = _cell_key(took)
	_loadouts[character_id] = loadout
	_refresh_burden(character_id)
	equipment_changed.emit(character_id)
	return OK


func unequip_to_bag(character_id: StringName, equip_slot: StringName) -> Error:
	if _inventory == null:
		return FAILED
	var item_key: StringName = get_equipped_key(character_id, equip_slot)
	if String(item_key) == "":
		return ERR_DOES_NOT_EXIST
	var overflow: int = _inventory.try_add_equipped_key(character_id, item_key, 1)
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


func _cell_key(cell: Dictionary) -> StringName:
	var raw_inst: Variant = cell.get("instance_id", &"")
	var inst_id: StringName = raw_inst as StringName if raw_inst is StringName else StringName(str(raw_inst))
	if inst_id != &"":
		return inst_id
	return _cell_item_id(cell)


func _cell_item_id(cell: Dictionary) -> StringName:
	if _item_instances != null and _item_instances.has_method("get_cell_item_id"):
		return _item_instances.call("get_cell_item_id", cell) as StringName
	var raw: Variant = cell.get("item_id", &"")
	return raw as StringName if raw is StringName else StringName(str(raw))


func _meets_requirements(character_id: StringName, cell: Dictionary) -> bool:
	var details: Dictionary = {}
	if _item_instances != null and _item_instances.has_method("describe_cell"):
		details = _item_instances.call("describe_cell", cell) as Dictionary
	var req: Dictionary = details.get("requirements", {}) as Dictionary
	if req.is_empty():
		return true
	if _inventory == null:
		return true
	var registry: Node = _inventory.get_registry() if _inventory.has_method("get_registry") else null
	if registry == null:
		return true
	var data: Resource = registry.get_character(character_id)
	if data == null:
		return true
	var skill_id := StringName(str(req.get("skill", "")))
	var need: int = int(req.get("rank", 0))
	if skill_id == &"":
		return true
	if data.has_method("get_effective_skill_rank"):
		return int(data.get_effective_skill_rank(skill_id)) >= need
	return true


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
