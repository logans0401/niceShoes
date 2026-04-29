class_name ItemInstance
extends Resource

@export var instance_id: StringName = &""
@export var item_id: StringName = &""
@export var display_name: String = ""
@export var loot_tier: int = 1
@export var category: String = ""
@export var item_type: String = ""
@export var magic: bool = false
@export var value: int = 0
@export var weight: float = 0.0
@export var equip_slot: StringName = &""
@export var weapon_kind: String = ""
@export var damage_min: int = 0
@export var damage_max: int = 0
@export var damage_type: int = 0
@export var armor_level: float = 0.0
@export var armor_ratings: Dictionary = {}
@export var requirements: Dictionary = {}
@export var modifiers: Dictionary = {}
@export var value_modifiers: Array = []


func to_dictionary() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"item_id": String(item_id),
		"display_name": display_name,
		"loot_tier": loot_tier,
		"category": category,
		"item_type": item_type,
		"magic": magic,
		"value": value,
		"weight": weight,
		"equip_slot": String(equip_slot),
		"weapon_kind": weapon_kind,
		"damage_min": damage_min,
		"damage_max": damage_max,
		"damage_type": damage_type,
		"armor_level": armor_level,
		"armor_ratings": armor_ratings.duplicate(true),
		"requirements": requirements.duplicate(true),
		"modifiers": modifiers.duplicate(true),
		"value_modifiers": value_modifiers.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> Resource:
	var inst: Resource = load("res://data/item_instance.gd").new() as Resource
	inst.instance_id = StringName(str(data.get("instance_id", "")))
	inst.item_id = StringName(str(data.get("item_id", "")))
	inst.display_name = str(data.get("display_name", ""))
	inst.loot_tier = int(data.get("loot_tier", 1))
	inst.category = str(data.get("category", ""))
	inst.item_type = str(data.get("item_type", ""))
	inst.magic = bool(data.get("magic", false))
	inst.value = int(data.get("value", 0))
	inst.weight = float(data.get("weight", 0.0))
	inst.equip_slot = StringName(str(data.get("equip_slot", "")))
	inst.weapon_kind = str(data.get("weapon_kind", ""))
	inst.damage_min = int(data.get("damage_min", 0))
	inst.damage_max = int(data.get("damage_max", 0))
	inst.damage_type = int(data.get("damage_type", 0))
	inst.armor_level = float(data.get("armor_level", 0.0))
	inst.armor_ratings = (data.get("armor_ratings", {}) as Dictionary).duplicate(true)
	inst.requirements = (data.get("requirements", {}) as Dictionary).duplicate(true)
	inst.modifiers = (data.get("modifiers", {}) as Dictionary).duplicate(true)
	inst.value_modifiers = (data.get("value_modifiers", []) as Array).duplicate(true)
	return inst
