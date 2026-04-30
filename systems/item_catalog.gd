class_name ItemCatalog
extends Node

const _ItemDef := preload("res://data/item_definition.gd")
const _Eq := preload("res://scripts/equipment_schema.gd")
var _defs: Dictionary = {}
const ARMOR_TYPES: Array[String] = [
	"padded_cloth",
	"leather",
	"studded_leather",
	"chainmail",
	"scalemail",
	"platemail",
]
const ARMOR_SLOTS: Array[String] = [
	"head",
	"shoulders",
	"chest",
	"hands",
	"waist",
	"legs",
	"feet",
]


func register_item(definition: Resource) -> void:
	if definition == null:
		return
	var id: String = String(definition.item_id)
	if id.is_empty():
		return
	_defs[id] = definition


func get_definition(item_id: StringName) -> Resource:
	return _defs.get(String(item_id), null) as Resource


func get_weight(item_id: StringName) -> float:
	var def: Resource = get_definition(item_id)
	if def == null:
		return 0.0
	return float(def.weight)


func has_item(item_id: StringName) -> bool:
	return _defs.has(String(item_id))


func _ready() -> void:
	ensure_items()


func ensure_items() -> void:
	if not _defs.is_empty():
		return
	_register_bootstrap_items()


func _register_bootstrap_items() -> void:
	var scrap: Resource = _ItemDef.new()
	scrap.item_id = "scrap"
	scrap.display_name = "Scrap"
	scrap.category = "junk"
	scrap.item_type = "junk"
	scrap.weight = 0.5
	scrap.max_stack = 20
	scrap.equip_slot = ""
	scrap.buy_price = 2
	scrap.sell_price = 1
	register_item(scrap)

	var sword: Resource = _ItemDef.new()
	sword.item_id = "iron_sword"
	sword.display_name = "Iron Sword"
	sword.category = "wearable"
	sword.item_type = "weapon"
	sword.weight = 6.0
	sword.max_stack = 1
	sword.equip_slot = _Eq.SLOT_MAIN_HAND
	sword.weapon_kind = "melee"
	sword.damage_min = 1
	sword.damage_max = 3
	sword.damage_type = 0
	sword.requirements = {"skill": "melee_combat", "rank": 0}
	sword.modifiers = {"melee_defense_multiplier": 1.02, "melee_combat_multiplier": 1.03, "attack_speed_bonus": 0.0}
	sword.buy_price = 80
	sword.sell_price = 25
	register_item(sword)

	var shield: Resource = _ItemDef.new()
	shield.item_id = "wood_shield"
	shield.display_name = "Wood Shield"
	shield.category = "wearable"
	shield.item_type = "armor"
	shield.weight = 5.0
	shield.max_stack = 1
	shield.equip_slot = _Eq.SLOT_OFF_HAND
	shield.armor_level = 1.0
	shield.armor_ratings = {0: 2, 1: 1, 2: 1}
	shield.buy_price = 40
	shield.sell_price = 12
	register_item(shield)

	var helm: Resource = _ItemDef.new()
	helm.item_id = "leather_cap"
	helm.display_name = "Leather Cap"
	helm.category = "wearable"
	helm.item_type = "armor"
	helm.weight = 1.5
	helm.max_stack = 1
	helm.equip_slot = _Eq.SLOT_HEAD
	helm.armor_level = 1.0
	helm.armor_ratings = {0: 2, 1: 1, 2: 1}
	helm.buy_price = 25
	helm.sell_price = 8
	register_item(helm)

	var bow: Resource = _ItemDef.new()
	bow.item_id = "short_bow"
	bow.display_name = "Short Bow"
	bow.category = "wearable"
	bow.item_type = "weapon"
	bow.weight = 2.2
	bow.max_stack = 1
	bow.equip_slot = _Eq.SLOT_MAIN_HAND
	bow.weapon_kind = "missile"
	bow.damage_min = 1
	bow.damage_max = 4
	bow.damage_type = 1
	bow.requirements = {"skill": "missile_combat", "rank": 0}
	bow.modifiers = {"melee_defense_multiplier": 1.01, "missile_combat_multiplier": 1.03, "attack_range_tiles": 2.0}
	bow.buy_price = 70
	bow.sell_price = 22
	register_item(bow)

	var xbow: Resource = _ItemDef.new()
	xbow.item_id = "crossbow"
	xbow.display_name = "Crossbow"
	xbow.category = "wearable"
	xbow.item_type = "weapon"
	xbow.weight = 5.5
	xbow.max_stack = 1
	xbow.equip_slot = _Eq.SLOT_MAIN_HAND
	xbow.weapon_kind = "missile"
	xbow.damage_min = 2
	xbow.damage_max = 5
	xbow.damage_type = 1
	xbow.requirements = {"skill": "missile_combat", "rank": 1}
	xbow.modifiers = {"melee_defense_multiplier": 1.01, "missile_combat_multiplier": 1.04, "attack_range_tiles": 3.0}
	xbow.buy_price = 95
	xbow.sell_price = 30
	register_item(xbow)

	var wand: Resource = _ItemDef.new()
	wand.item_id = "oak_wand"
	wand.display_name = "Oak Wand"
	wand.category = "wearable"
	wand.item_type = "weapon"
	wand.weight = 1.0
	wand.max_stack = 1
	wand.equip_slot = _Eq.SLOT_MAIN_HAND
	wand.weapon_kind = "casting"
	wand.requirements = {"skill": "magic_combat", "rank": 0}
	wand.modifiers = {"melee_defense_multiplier": 1.01, "arcane_connection_multiplier": 1.02}
	wand.damage_min = 0
	wand.damage_max = 0
	wand.buy_price = 55
	wand.sell_price = 18
	register_item(wand)

	var orb: Resource = _ItemDef.new()
	orb.item_id = "focus_orb"
	orb.display_name = "Focus Orb"
	orb.category = "wearable"
	orb.item_type = "weapon"
	orb.weight = 0.8
	orb.max_stack = 1
	orb.equip_slot = _Eq.SLOT_MAIN_HAND
	orb.weapon_kind = "casting"
	orb.requirements = {"skill": "magic_support", "rank": 0}
	orb.modifiers = {"melee_defense_multiplier": 1.01, "arcane_connection_multiplier": 1.03}
	orb.damage_min = 0
	orb.damage_max = 0
	orb.buy_price = 60
	orb.sell_price = 20
	register_item(orb)

	_register_armor_sets()
	_register_accessories()

	_register_spell_scrolls()


static func armor_item_id(armor_type: String, slot: String) -> StringName:
	return StringName("%s_%s" % [armor_type, slot])


func _register_armor_sets() -> void:
	for type_index in range(ARMOR_TYPES.size()):
		var armor_type: String = ARMOR_TYPES[type_index]
		for slot in ARMOR_SLOTS:
			_register_armor_piece(armor_type, slot, type_index)


func _register_armor_piece(armor_type: String, slot: String, type_index: int) -> void:
	var armor: Resource = _ItemDef.new()
	armor.item_id = String(armor_item_id(armor_type, slot))
	armor.display_name = "%s %s" % [_armor_type_display(armor_type), _armor_slot_piece_name(slot)]
	armor.category = "wearable"
	armor.item_type = "armor"
	armor.max_stack = 1
	armor.equip_slot = slot
	armor.loot_tier_min = _armor_type_min_tier(type_index)
	armor.loot_tier_max = 20
	var slot_weight: float = _armor_slot_weight(slot)
	var type_weight: float = 1.0 + float(type_index) * 0.45
	armor.weight = snappedf(slot_weight * type_weight, 0.1)
	armor.armor_level = 1.0 + float(type_index) * 1.15
	armor.armor_ratings = _armor_ratings_for_type(type_index)
	armor.buy_price = int(round(20.0 + float(type_index) * 28.0 + slot_weight * 7.0))
	armor.sell_price = maxi(1, int(round(float(armor.buy_price) * 0.32)))
	register_item(armor)


func _armor_type_display(armor_type: String) -> String:
	return armor_type.replace("_", " ").capitalize()


func _armor_slot_piece_name(slot: String) -> String:
	match slot:
		"head":
			return "Cap"
		"shoulders":
			return "Pauldrons"
		"chest":
			return "Armor"
		"hands":
			return "Gloves"
		"waist":
			return "Belt"
		"legs":
			return "Leggings"
		"feet":
			return "Boots"
		_:
			return slot.capitalize()


func _armor_slot_weight(slot: String) -> float:
	match slot:
		"head":
			return 1.2
		"shoulders":
			return 2.0
		"chest":
			return 4.0
		"hands":
			return 1.0
		"waist":
			return 1.1
		"legs":
			return 3.0
		"feet":
			return 1.6
		_:
			return 1.0


func _armor_type_min_tier(type_index: int) -> int:
	return [1, 1, 4, 7, 10, 14][clampi(type_index, 0, 5)]


func _armor_ratings_for_type(type_index: int) -> Dictionary:
	var base: int = clampi(1 + type_index, 1, 10)
	return {
		0: clampi(base + 1, 0, 10),
		1: clampi(base, 0, 10),
		2: clampi(base, 0, 10),
	}


func _register_accessories() -> void:
	_register_accessory(&"bronze_bracelet", "Bronze Bracelet", _Eq.SLOT_HANDS, 0.4, 18, 6)
	_register_accessory(&"copper_ring", "Copper Ring", _Eq.SLOT_RING_1, 0.1, 16, 5)
	_register_accessory(&"silver_necklace", "Silver Necklace", _Eq.SLOT_NECK, 0.2, 45, 15)
	_register_accessory(&"gold_ring", "Gold Ring", _Eq.SLOT_RING_1, 0.1, 80, 28)
	_register_accessory(&"onyx_ring", "Onyx Ring", _Eq.SLOT_RING_1, 0.1, 110, 36)


func _register_accessory(
	item_id: StringName,
	display_name: String,
	equip_slot: String,
	weight: float,
	buy_price: int,
	sell_price: int,
) -> void:
	var accessory: Resource = _ItemDef.new()
	accessory.item_id = String(item_id)
	accessory.display_name = display_name
	accessory.category = "wearable"
	accessory.item_type = "accessory"
	accessory.weight = weight
	accessory.max_stack = 1
	accessory.equip_slot = equip_slot
	accessory.buy_price = buy_price
	accessory.sell_price = sell_price
	register_item(accessory)


func _register_spell_scrolls() -> void:
	for sid: StringName in MagicRules.all_scroll_teach_spell_ids():
		var scr: Resource = _ItemDef.new()
		var key: String = String(sid).replace("/", "_")
		scr.item_id = "scroll_%s" % key
		scr.display_name = "%s (scroll)" % MagicRules.spell_display_name(sid)
		scr.category = "readable"
		scr.item_type = "scroll"
		scr.weight = 0.0
		scr.max_stack = 99
		scr.equip_slot = ""
		scr.scroll_teaches_spell = String(sid)
		scr.buy_price = 1
		scr.sell_price = 0
		register_item(scr)
	var all_scr: Resource = _ItemDef.new()
	all_scr.item_id = "scroll_all_spells"
	all_scr.display_name = "All Spells (testing scroll)"
	all_scr.category = "readable"
	all_scr.item_type = "scroll"
	all_scr.weight = 0.0
	all_scr.max_stack = 99
	all_scr.equip_slot = ""
	all_scr.scroll_teaches_spell = String(MagicRules.SCROLL_TEACHES_ALL_SPELLS)
	all_scr.buy_price = 0
	all_scr.sell_price = 0
	register_item(all_scr)
