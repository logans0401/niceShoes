extends RefCounted
class_name MagicRules
## Magic Combat vs Magic Support, bolt naming, tier scaffolding, and fizzle curve.
## Spells are data-driven later; this file encodes design constants and helpers.

enum School {
	MAGIC_COMBAT,
	MAGIC_SUPPORT,
}

## Combat bolt spell ids (each maps to a `DamageTypes.Id` on cast).
const BOLT_FORCE := &"force_bolt" ## bludgeoning
const BOLT_BLADE := &"blade_bolt" ## slashing
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

const MAX_SPELL_TIER: int = 10
const BOLT_TIER1_MANA_COST: int = 6
## Tier 1 cast time (ms); each tier above adds this much.
const SPELL_TIER1_CAST_MS: int = 125
const SPELL_CAST_MS_PER_TIER_ABOVE_1: int = 175


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
