extends RefCounted
class_name MagicRules
## Magic Combat vs Magic Support, bolt naming, tier scaffolding, and fizzle curve.
## Spells are data-driven later; this file encodes design constants and helpers.

const _Sch := preload("res://scripts/character_schema.gd")

enum School {
	MAGIC_COMBAT,
	MAGIC_SUPPORT,
}

## Combat bolt spell ids (each maps to a `DamageTypes.Id` on cast).
const BOLT_FORCE := &"force_bolt"  ## bludgeoning
const BOLT_BLADE := &"blade_bolt"  ## slashing
const BOLT_PIERCE := &"piercing_bolt"
const BOLT_LIGHTNING := &"lightning_bolt"
const BOLT_FROST := &"frost_bolt"
const BOLT_ACID := &"acid_bolt"
const BOLT_FIRE := &"fire_bolt"

const ALL_BOLTS: Array[StringName] = [
	BOLT_FORCE,
	BOLT_BLADE,
	BOLT_PIERCE,
	BOLT_LIGHTNING,
	BOLT_FROST,
	BOLT_ACID,
	BOLT_FIRE,
]


static func bolt_damage_type(bolt_id: StringName) -> DamageTypes.Id:
	match bolt_id:
		BOLT_FORCE:
			return DamageTypes.Id.BLUDGEONING
		BOLT_BLADE:
			return DamageTypes.Id.SLASHING
		BOLT_PIERCE:
			return DamageTypes.Id.PIERCING
		BOLT_LIGHTNING:
			return DamageTypes.Id.LIGHTNING
		BOLT_FROST:
			return DamageTypes.Id.COLD
		BOLT_ACID:
			return DamageTypes.Id.ACID
		BOLT_FIRE:
			return DamageTypes.Id.FIRE
		_:
			return DamageTypes.Id.BLUDGEONING


## Support examples (buffs / heals). Tier 1–10 scales power & cost elsewhere.
const SPELL_HEAL := &"heal"
const SPELL_REJUVENATE := &"rejuvenate"
const SPELL_REPLENISH := &"replenish"
const SPELL_REFLEXES_BUFF := &"reflexes_buff"
const SPELL_MELEE_COMBAT_BUFF := &"melee_combat_buff"
const SCROLL_TEACHES_ALL_SPELLS := &"__all_spells__"

const BUFF_KIND_ATTRIBUTE := "attribute"
const BUFF_KIND_SKILL := "skill"
const BUFF_AMOUNT: int = 2
const PROTECTION_KIND_ARMOR := "armor"
const PROTECTION_KIND_DAMAGE_TYPE := "damage_type"
const ARMOR_PROTECTION_AMOUNT: float = 4.0
const DAMAGE_TYPE_PROTECTION_PERCENT: float = 0.01

const MAX_SPELL_TIER: int = 10
const BOLT_TIER1_MANA_COST: int = 6
## Tier 1 cast time (ms); each tier above adds this much.
const SPELL_TIER1_CAST_MS: int = 125
const SPELL_CAST_MS_PER_TIER_ABOVE_1: int = 175
const ARCANE_CONNECTION_MANA_REDUCTION_PER_SKILL: float = 0.005
const ARCANE_CONNECTION_MAX_MANA_REDUCTION: float = 0.50


static func all_scroll_teach_spell_ids() -> Array[StringName]:
	return [
		BOLT_FORCE,
		BOLT_BLADE,
		BOLT_PIERCE,
		BOLT_LIGHTNING,
		BOLT_FROST,
		BOLT_ACID,
		BOLT_FIRE,
		SPELL_HEAL,
		SPELL_REJUVENATE,
		SPELL_REPLENISH,
		SPELL_REFLEXES_BUFF,
		SPELL_MELEE_COMBAT_BUFF,
	]


static func all_spell_ids() -> Array[StringName]:
	var seen: Dictionary = {}
	var ids: Array[StringName] = []
	for sid in all_scroll_teach_spell_ids():
		seen[sid] = true
		ids.append(sid)
	for buff_id in all_buff_spell_ids():
		if seen.has(buff_id):
			continue
		seen[buff_id] = true
		ids.append(buff_id)
	for protection_id in all_protection_spell_ids():
		if seen.has(protection_id):
			continue
		seen[protection_id] = true
		ids.append(protection_id)
	return ids


static func all_item_magic_spell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.append_array(all_buff_spell_ids())
	ids.append_array(all_protection_spell_ids())
	return ids


static func buff_spell_catalog() -> Dictionary:
	var out: Dictionary = {}
	for attr in _Sch.ALL_ATTRIBUTES:
		var attr_id: String = str(attr)
		var spell_id := StringName("%s_buff" % attr_id)
		out[spell_id] = {
			"kind": BUFF_KIND_ATTRIBUTE,
			"target_id": attr_id,
			"display_name": "%s Buff" % _title_from_id(attr_id),
			"amount": BUFF_AMOUNT,
		}
	for skill in _Sch.ALL_SKILLS:
		var skill_id: String = str(skill)
		var spell_id2 := StringName("%s_buff" % skill_id)
		out[spell_id2] = {
			"kind": BUFF_KIND_SKILL,
			"target_id": skill_id,
			"display_name": "%s Buff" % _title_from_id(skill_id),
			"amount": BUFF_AMOUNT,
		}
	return out


static func all_buff_spell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in buff_spell_catalog().keys():
		ids.append(key as StringName)
	return ids


static func is_buff_spell(spell_id: StringName) -> bool:
	return buff_spell_catalog().has(spell_id)


static func buff_spell_definition(spell_id: StringName) -> Dictionary:
	return (buff_spell_catalog().get(spell_id, {}) as Dictionary).duplicate(true)


static func protection_spell_catalog() -> Dictionary:
	var out: Dictionary = {
		&"armor_protection":
		{
			"kind": PROTECTION_KIND_ARMOR,
			"display_name": "Armor Protection",
			"armor_bonus": ARMOR_PROTECTION_AMOUNT,
		},
	}
	for damage_type in _all_damage_type_ids():
		var type_name: String = String(DamageTypes.id_to_string(damage_type))
		var spell_id := StringName("%s_protection" % type_name)
		out[spell_id] = {
			"kind": PROTECTION_KIND_DAMAGE_TYPE,
			"display_name": "%s Protection" % _title_from_id(type_name),
			"damage_type": damage_type,
			"percent": DAMAGE_TYPE_PROTECTION_PERCENT,
		}
	return out


static func all_protection_spell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in protection_spell_catalog().keys():
		ids.append(key as StringName)
	return ids


static func is_protection_spell(spell_id: StringName) -> bool:
	return protection_spell_catalog().has(spell_id)


static func protection_spell_definition(spell_id: StringName) -> Dictionary:
	return (protection_spell_catalog().get(spell_id, {}) as Dictionary).duplicate(true)


static func is_offensive_bolt(spell_id: StringName) -> bool:
	for bolt in ALL_BOLTS:
		if bolt == spell_id:
			return true
	return false


static func spell_display_name(spell_id: StringName) -> String:
	match spell_id:
		BOLT_FORCE:
			return "Force Bolt"
		BOLT_BLADE:
			return "Blade Bolt"
		BOLT_PIERCE:
			return "Piercing Bolt"
		BOLT_LIGHTNING:
			return "Lightning Bolt"
		BOLT_FROST:
			return "Frost Bolt"
		BOLT_ACID:
			return "Acid Bolt"
		BOLT_FIRE:
			return "Fire Bolt"
		SPELL_HEAL:
			return "Heal"
		SPELL_REJUVENATE:
			return "Rejuvenate"
		SPELL_REPLENISH:
			return "Replenish"
		SPELL_REFLEXES_BUFF:
			return "Reflexes Buff"
		SPELL_MELEE_COMBAT_BUFF:
			return "Melee Combat Buff"
		_:
			var buff: Dictionary = buff_spell_definition(spell_id)
			if not buff.is_empty():
				return str(buff.get("display_name", String(spell_id)))
			var protection: Dictionary = protection_spell_definition(spell_id)
			if not protection.is_empty():
				return str(protection.get("display_name", String(spell_id)))
			return String(spell_id).replace("_", " ").capitalize()


## Tier-1 combat bolt baseline; support / unknown → no direct damage.
static func spell_damage_range(spell_id: StringName) -> Vector2i:
	if is_offensive_bolt(spell_id):
		return Vector2i(2, 5)
	return Vector2i(0, 0)


static func spell_cast_time_ms(tier: int) -> int:
	var t: int = clampi(tier, 1, MAX_SPELL_TIER)
	return SPELL_TIER1_CAST_MS + (t - 1) * SPELL_CAST_MS_PER_TIER_ABOVE_1


static func spell_mana_cost(spell_id: StringName, tier: int) -> int:
	var t: int = clampi(tier, 1, MAX_SPELL_TIER)
	var step: int = t - 1
	if is_offensive_bolt(spell_id):
		return BOLT_TIER1_MANA_COST + step * 3
	return BOLT_TIER1_MANA_COST + step * 2


static func spell_mana_cost_after_arcane_connection(
	spell_id: StringName,
	tier: int,
	arcane_connection_skill: float,
) -> int:
	var base: int = spell_mana_cost(spell_id, tier)
	var reduction: float = clampf(
		arcane_connection_skill * ARCANE_CONNECTION_MANA_REDUCTION_PER_SKILL,
		0.0,
		ARCANE_CONNECTION_MAX_MANA_REDUCTION,
	)
	return maxi(1, int(ceil(float(base) * (1.0 - reduction))))


static func spell_damage_range_for_tier(spell_id: StringName, tier: int) -> Vector2i:
	var base: Vector2i = spell_damage_range(spell_id)
	if base.x == 0 and base.y == 0:
		return base
	var t: int = clampi(tier, 1, MAX_SPELL_TIER)
	var bonus: int = t - 1
	return Vector2i(base.x + bonus, base.y + bonus)


## Resolved at end of cast bar; tier 1 keeps at least ~10% fizzle while testing.
static func spell_resolve_fizzle_probability(
	caster_magic_combat_skill: float,
	caster_magic_support_skill: float,
	spell_id: StringName,
	tier: int,
) -> float:
	var t: int = clampi(tier, 1, MAX_SPELL_TIER)
	var p: float
	if is_offensive_bolt(spell_id):
		var req: float = required_magic_combat_skill(t)
		p = spell_fizzle_chance(caster_magic_combat_skill, req)
	else:
		var req2: float = required_magic_support_skill(t)
		p = spell_fizzle_chance(caster_magic_support_skill, req2)
	if t == 1:
		p = maxf(p, 0.10)
	return clampf(p, 0.0, 0.95)


static func offensive_spell_damage_type(spell_id: StringName) -> int:
	return int(bolt_damage_type(spell_id))


## Required Magic Support skill to cast support spells at tier (stub ladder; tune in data later).
static func required_magic_support_skill(tier: int) -> float:
	var t: int = clampi(tier, 1, MAX_SPELL_TIER)
	return 10.0 + float(t - 1) * 10.0


## Required Magic Combat skill to cast combat bolts at tier.
static func required_magic_combat_skill(tier: int) -> float:
	var t: int = clampi(tier, 1, MAX_SPELL_TIER)
	return 10.0 + float(t - 1) * 10.0


## Fizzle chance 0..1 from caster skill vs requirement.
static func spell_fizzle_chance(caster_skill_value: float, required_skill: float) -> float:
	var gap: float = caster_skill_value - required_skill
	if gap >= 20.0:
		return 0.0
	if gap <= -10.0:
		return 0.95
	if gap <= 0.0:
		return lerpf(0.95, 0.45, (gap + 10.0) / 10.0)
	if gap <= 2.0:
		return lerpf(0.45, 0.20, gap / 2.0)
	if gap <= 15.0:
		return lerpf(0.20, 0.08, (gap - 2.0) / 13.0)
	return lerpf(0.08, 0.0, (gap - 15.0) / 5.0)


static func _title_from_id(id: String) -> String:
	return id.replace("_", " ").capitalize()


static func _all_damage_type_ids() -> Array[int]:
	return [
		DamageTypes.Id.SLASHING,
		DamageTypes.Id.PIERCING,
		DamageTypes.Id.BLUDGEONING,
		DamageTypes.Id.FIRE,
		DamageTypes.Id.LIGHTNING,
		DamageTypes.Id.COLD,
		DamageTypes.Id.ACID,
	]
