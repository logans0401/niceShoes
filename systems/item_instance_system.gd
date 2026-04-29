class_name ItemInstanceSystem
extends Node

const ItemInstanceScr := preload("res://data/item_instance.gd")
const _Eq := preload("res://scripts/equipment_schema.gd")
const _Sch := preload("res://scripts/character_schema.gd")

var _catalog: Node = null
var _next_id: int = 1
var _instances: Dictionary = {}


func configure(catalog: Node) -> void:
	_catalog = catalog


func create_cell(item_id: StringName, quantity: int = 1, loot_tier: int = 1, source: String = "") -> Dictionary:
	var inst_id: StringName = create_instance(item_id, loot_tier, source)
	return {"item_id": item_id, "instance_id": inst_id, "quantity": quantity}


func create_instance(item_id: StringName, loot_tier: int = 1, source: String = "") -> StringName:
	if _catalog == null:
		return &""
	var def: Resource = _catalog.get_definition(item_id)
	if def == null:
		return &""
	var inst: Resource = _roll_instance(def, loot_tier, source)
	_instances[inst.instance_id] = inst
	return inst.instance_id


func has_instance(instance_id: StringName) -> bool:
	return _instances.has(instance_id) or _instances.has(String(instance_id))


func get_instance(instance_id: StringName) -> Resource:
	var v: Variant = _instances.get(instance_id, null)
	if v == null:
		v = _instances.get(String(instance_id), null)
	return v as Resource


func get_cell_instance_id(cell: Variant) -> StringName:
	if cell == null or not (cell is Dictionary):
		return &""
	var d: Dictionary = cell as Dictionary
	var raw: Variant = d.get("instance_id", &"")
	return raw as StringName if raw is StringName else StringName(str(raw))


func get_cell_item_id(cell: Variant) -> StringName:
	if cell == null or not (cell is Dictionary):
		return &""
	var d: Dictionary = cell as Dictionary
	var iid: StringName = get_cell_instance_id(cell)
	if iid != &"":
		var inst: Resource = get_instance(iid)
		if inst != null and inst.item_id != &"":
			return inst.item_id
	var raw: Variant = d.get("item_id", &"")
	return raw as StringName if raw is StringName else StringName(str(raw))


func get_weight_for_cell(cell: Variant) -> float:
	var iid: StringName = get_cell_instance_id(cell)
	var inst: Resource = get_instance(iid)
	if inst != null:
		return inst.weight
	var item_id: StringName = get_cell_item_id(cell)
	if _catalog != null and item_id != &"":
		return _catalog.get_weight(item_id)
	return 0.0


func get_sell_price_for_cell(cell: Variant) -> int:
	var iid: StringName = get_cell_instance_id(cell)
	var inst: Resource = get_instance(iid)
	if inst != null:
		return inst.value
	var item_id: StringName = get_cell_item_id(cell)
	if _catalog != null and item_id != &"":
		var def: Resource = _catalog.get_definition(item_id)
		if def != null:
			return int(def.sell_price)
	return 0


func describe_cell(cell: Variant) -> Dictionary:
	var iid: StringName = get_cell_instance_id(cell)
	var inst: Resource = get_instance(iid)
	if inst != null:
		return inst.to_dictionary()
	var item_id: StringName = get_cell_item_id(cell)
	if _catalog == null or item_id == &"":
		return {}
	var def: Resource = _catalog.get_definition(item_id)
	if def == null:
		return {}
	return {
		"item_id": String(item_id),
		"display_name": str(def.display_name),
		"value": int(def.sell_price),
		"weight": float(def.weight),
		"equip_slot": str(def.equip_slot),
		"weapon_kind": str(def.weapon_kind),
		"damage_min": int(def.damage_min),
		"damage_max": int(def.damage_max),
		"damage_type": int(def.damage_type),
	}


func export_state() -> Dictionary:
	var out: Dictionary = {"next_id": _next_id, "instances": {}}
	var inst_out: Dictionary = {}
	for key in _instances.keys():
		var inst: Resource = _instances[key] as Resource
		if inst != null:
			inst_out[String(key)] = inst.to_dictionary()
	out["instances"] = inst_out
	return out


func import_state(state: Dictionary) -> void:
	_instances.clear()
	_next_id = int(state.get("next_id", 1))
	var raw: Dictionary = state.get("instances", {}) as Dictionary
	for key in raw.keys():
		var inst: Resource = ItemInstanceScr.from_dictionary(raw[key] as Dictionary)
		if inst.instance_id != &"":
			_instances[inst.instance_id] = inst


func _roll_instance(def: Resource, loot_tier: int, source: String) -> Resource:
	var inst: Resource = ItemInstanceScr.new() as Resource
	inst.instance_id = StringName("inst_%d" % _next_id)
	_next_id += 1
	inst.item_id = StringName(str(def.item_id))
	inst.display_name = str(def.display_name)
	inst.loot_tier = clampi(loot_tier, 1, 20)
	inst.category = str(def.category)
	inst.item_type = str(def.item_type)
	inst.weight = float(def.weight)
	inst.equip_slot = StringName(str(def.equip_slot))
	inst.weapon_kind = str(def.weapon_kind)
	inst.damage_min = int(def.damage_min)
	inst.damage_max = int(def.damage_max)
	inst.damage_type = int(def.damage_type)
	inst.armor_level = float(def.armor_level)
	inst.armor_ratings = (def.armor_ratings as Dictionary).duplicate(true)
	inst.requirements = (def.requirements as Dictionary).duplicate(true)
	inst.modifiers = (def.modifiers as Dictionary).duplicate(true)
	inst.value = maxi(0, int(def.sell_price))
	_apply_tier_scaling(inst)
	_roll_value_modifiers(inst)
	_roll_magic(inst, source)
	return inst


func _apply_tier_scaling(inst: Resource) -> void:
	var tier_bonus: float = 1.0 + maxf(0.0, float(inst.loot_tier - 1)) * 0.08
	inst.value = maxi(1, int(round(float(inst.value) * tier_bonus)))
	if inst.damage_max > 0:
		inst.damage_min = maxi(1, int(round(float(inst.damage_min) * tier_bonus)))
		inst.damage_max = maxi(inst.damage_min, int(round(float(inst.damage_max) * tier_bonus)))
	if inst.armor_level > 0.0:
		inst.armor_level *= tier_bonus
		for k in inst.armor_ratings.keys():
			inst.armor_ratings[k] = clampi(int(round(float(inst.armor_ratings[k]) * tier_bonus)), 0, 10)


func _roll_value_modifiers(inst: Resource) -> void:
	var wearable: bool = inst.category == "wearable"
	if not wearable:
		return
	if inst.item_type == "clothing":
		if randf() < 0.15:
			_add_value_modifier(inst, "fabric", randf_range(0.08, 0.21))
		return
	if inst.item_type == "armor" or inst.weapon_kind == "melee":
		if randf() < 0.15:
			var metal_v: float = randf_range(0.07, 0.11)
			if inst.weapon_kind == "melee":
				metal_v = randf_range(0.04, 0.07)
				var dmg_mult: float = randf_range(1.03, 1.08)
				inst.damage_min = maxi(1, int(round(float(inst.damage_min) * dmg_mult)))
				inst.damage_max = maxi(inst.damage_min, int(round(float(inst.damage_max) * dmg_mult)))
			else:
				inst.armor_level *= randf_range(1.04, 1.08)
			_add_value_modifier(inst, "metal", metal_v)
	if inst.weapon_kind == "casting" and randf() < 0.15:
		_add_value_modifier(inst, "metal", randf_range(0.05, 0.09))
	if inst.item_type == "accessory" and randf() < 0.15:
		_add_value_modifier(inst, "metal", randf_range(0.11, 0.35))
	var jewel_chance: float = 0.05 if inst.item_type == "armor" or inst.weapon_kind == "melee" else 0.15
	if randf() < jewel_chance:
		var jewels: int = 2 if randf() < 0.35 else 1
		var pct: float = randf_range(0.13, 0.18) if jewels >= 2 else randf_range(0.07, 0.11)
		_add_value_modifier(inst, "%d jewel" % jewels, pct)


func _add_value_modifier(inst: Resource, label: String, pct: float) -> void:
	inst.value_modifiers.append({"label": label, "percent": pct})
	inst.value = maxi(1, int(round(float(inst.value) * (1.0 + pct))))


func _roll_magic(inst: Resource, _source: String) -> void:
	if inst.category != "wearable" or randf() >= 0.04:
		return
	inst.magic = true
	var roll: float = randf()
	if inst.weapon_kind == "casting":
		if roll < 0.2:
			inst.modifiers["missile_defense_multiplier"] = randf_range(1.02, 1.08)
		elif roll < 0.97:
			inst.modifiers["arcane_conversion_multiplier"] = randf_range(1.04, 1.14)
		else:
			inst.modifiers["spell_extra_damage_percent"] = randf_range(0.10, 0.20)
	else:
		inst.modifiers["melee_defense_multiplier"] = randf_range(1.02, 1.08)
