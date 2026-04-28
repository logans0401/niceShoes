extends RefCounted
class_name DamageTypes
## Physical + elemental damage kinds. Source is usually a weapon (`WeaponProfile`) or spell (`SpellId`).

enum Id {
	SLASHING,
	PIERCING,
	BLUDGEONING,
	FIRE,
	LIGHTNING,
	COLD,
	ACID,
}

const _NAMES: Dictionary = {
	Id.SLASHING: &"slashing",
	Id.PIERCING: &"piercing",
	Id.BLUDGEONING: &"bludgeoning",
	Id.FIRE: &"fire",
	Id.LIGHTNING: &"lightning",
	Id.COLD: &"cold",
	Id.ACID: &"acid",
}


static func id_to_string(id: int) -> StringName:
	return _NAMES.get(id, &"unknown")


## Typical melee profile defaults (items/spells override).
static func default_melee_for_weapon_style(style: StringName) -> Id:
	match String(style).to_lower():
		"sword", "axe", "claw":
			return Id.SLASHING
		"spear", "arrow", "bolt":
			return Id.PIERCING
		"mace", "hammer", "staff_melee":
			return Id.BLUDGEONING
		_:
			return Id.SLASHING
