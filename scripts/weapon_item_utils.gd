extends RefCounted
class_name WeaponItemUtils

const _EqScr := preload("res://scripts/equipment_schema.gd")


static func main_hand_definition(
	character_id: StringName, equipment: Node, catalog: Node
) -> Resource:
	if equipment == null or catalog == null:
		return null
	var iid: StringName = equipment.get_equipped_item(
		character_id, StringName(_EqScr.SLOT_MAIN_HAND)
	)
	if iid == &"":
		return null
	return catalog.get_definition(iid)


static func weapon_kind(item_def: Resource) -> String:
	if item_def == null:
		return ""
	return String(item_def.weapon_kind).strip_edges()


static func is_melee_weapon(item_def: Resource) -> bool:
	return weapon_kind(item_def) == "melee"


static func is_missile_weapon(item_def: Resource) -> bool:
	return weapon_kind(item_def) == "missile"


static func is_casting_weapon(item_def: Resource) -> bool:
	return weapon_kind(item_def) == "casting"


static func has_any_attack_weapon(item_def: Resource) -> bool:
	var k: String = weapon_kind(item_def)
	return k == "melee" or k == "missile" or k == "casting"
