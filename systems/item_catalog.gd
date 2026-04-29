class_name ItemCatalog
extends Node

const _ItemDef := preload("res://data/item_definition.gd")
const _Eq := preload("res://scripts/equipment_schema.gd")
var _defs: Dictionary = {}


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
	wand.modifiers = {"melee_defense_multiplier": 1.01, "arcane_conversion_multiplier": 1.02}
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
	orb.modifiers = {"melee_defense_multiplier": 1.01, "arcane_conversion_multiplier": 1.03}
	orb.damage_min = 0
	orb.damage_max = 0
	orb.buy_price = 60
	orb.sell_price = 20
	register_item(orb)

	_register_spell_scrolls()


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
