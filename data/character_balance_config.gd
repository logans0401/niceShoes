class_name CharacterBalanceConfig
extends Resource

const _Sch := preload("res://scripts/character_schema.gd")

## Single tuning surface for character progression and derived formulas.
## Pair with `res://data/default_character_balance.tres` for editor tweaks.

@export_group("Level curve (1–100)")
@export var max_level: int = 100
## Minimum total XP required to reach level L (L>=2). Level 1 implies 0 XP.
@export var level_xp_flat_per_tier: float = 80.0
@export var level_xp_linear_scale: float = 120.0
@export var level_xp_power: float = 1.65
## Target: first map content should reach at least character level 3 (see `get_total_xp_for_level(3)`).
@export var first_map_total_xp_budget: int = 560

@export_group("Burden")
## Capacity when Strength and Heartiness are at `attribute_formula_pivot` (no excess).
@export var burden_base_capacity: float = 78.0
@export var burden_per_strength: float = 0.52
@export var burden_per_heartiness: float = 0.38

@export_group("Character creation (static for every new character)")
## Design: N = floor, Z = creation cap = 10×N, M = free points = 2.7×Z (e.g. N=10 → Z=100, M=270).
## Exactly three stats can reach Z while the other three stay at N.
## N — minimum for each attribute; cannot go lower in the creation UI.
@export var creation_attribute_floor: int = 10
## M — discretionary points distributed above the floor (must spend all to create).
@export var creation_attribute_pool: int = 270
## Z — maximum any single attribute during creation. Post-creation XP can raise up to `max_attribute_value`.
@export var creation_attribute_cap: int = 100

@export_group("Derived stats pivot")
## Attributes at this floor are the baseline for burden excess and some combat helpers; matches creation floor N.
@export var attribute_formula_pivot: int = 10

@export_group("Skill formula (base from attributes + training ranks)")
## Each skill rank bought with XP adds this much on top of the fixed attribute formula (see `get_skill_base_modifier`).
@export var skill_rank_modifier_scale: float = 1.0

@export_group("Skill training")
@export var skill_xp_base: float = 48.0
## Extra cost as the skill rank rises (character level does not affect buy cost).
@export var skill_xp_rank_scalar: float = 0.12

@export_group("Attribute training (unspent XP buys)")
@export var attribute_xp_base: float = 64.0
## Pivot attribute value where scaling starts (creation baseline).
@export var attribute_spend_pivot: int = 10
## Exponential growth per point above pivot (small = gentle curve).
@export var attribute_spend_growth: float = 1.042
@export var max_attribute_value: int = 120

@export_group("Vital XP (bonus max pools — not set at character creation)")
## Flat bonus to max HP per XP purchase (`vital_xp_purchases.health`).
@export var vital_bonus_health_per_xp_purchase: float = 12.0
@export var vital_bonus_stamina_per_xp_purchase: float = 10.0
@export var vital_bonus_mana_per_xp_purchase: float = 8.0
@export var attack_skill_scale: float = 1.65
@export var defense_skill_scale: float = 1.5


func get_total_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var tier: float = float(level - 1)
	var raw: float = (
		level_xp_flat_per_tier * tier + level_xp_linear_scale * pow(tier, level_xp_power)
	)
	return maxi(0, int(round(raw)))


func get_level_from_total_xp(total_xp: int) -> int:
	var level: int = 1
	while level < max_level and total_xp >= get_total_xp_for_level(level + 1):
		level += 1
	return level


func get_xp_into_level(total_xp: int, level: int) -> int:
	var floor_xp: int = get_total_xp_for_level(level)
	return maxi(0, total_xp - floor_xp)


func get_xp_to_next_level(total_xp: int, level: int) -> int:
	if level >= max_level:
		return 0
	var next_floor: int = get_total_xp_for_level(level + 1)
	return maxi(0, next_floor - total_xp)


func get_burden_capacity(attributes: Dictionary) -> float:
	var pivot: float = float(attribute_formula_pivot)
	var strn: float = maxf(0.0, float(attributes.get(_Sch.ATTRIBUTE_STRENGTH, pivot)) - pivot)
	var heart: float = maxf(0.0, float(attributes.get(_Sch.ATTRIBUTE_HEARTINESS, pivot)) - pivot)
	return burden_base_capacity + strn * burden_per_strength + heart * burden_per_heartiness


func get_skill_xp_to_advance(skill_rank: int) -> int:
	var rank: int = maxi(0, skill_rank)
	var mult: float = 1.0 + float(rank) * skill_xp_rank_scalar
	return maxi(1, int(round(skill_xp_base * mult)))


## XP cost for the next attribute point at this **attribute value** (character level is ignored).
func get_attribute_xp_to_advance(current_attribute_value: int) -> int:
	return get_unspent_cost_raise_attribute(current_attribute_value)


## Unspent XP cost to raise an attribute from `current_value` -> current_value+1.
func get_unspent_cost_raise_attribute(current_value: int) -> int:
	var v: int = clampi(current_value, 1, 200)
	var pivot: int = clampi(attribute_spend_pivot, 1, 100)
	var over: int = maxi(0, v - pivot)
	var mult: float = pow(attribute_spend_growth, float(over))
	return maxi(1, int(round(attribute_xp_base * mult)))


## Unspent XP cost to raise a skill from rank -> rank+1 (rank is current rank 0..).
func get_unspent_cost_raise_skill(skill_rank: int) -> int:
	return get_skill_xp_to_advance(skill_rank)


## Cost for raising an attribute/vital specifically **via unspent XP purchase count** (excluding creation boosts).
func get_unspent_cost_for_xp_purchase_count(purchases_already: int) -> int:
	var v_eff: int = clampi(attribute_spend_pivot + maxi(0, purchases_already), 1, 200)
	return get_unspent_cost_raise_attribute(v_eff)


func get_skill_attribute_weights() -> Dictionary:
	return {}


func get_skill_modifier_from_attributes(skill_id: StringName, attributes: Dictionary) -> float:
	return get_skill_base_modifier(skill_id, attributes)


func get_all_skill_modifiers(attributes: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for skill_id in _Sch.ALL_SKILLS:
		out[skill_id] = get_skill_modifier_from_attributes(StringName(skill_id), attributes)
	return out


## Attribute-only term from fixed formulas (same as combat skill base modifier).
func get_skill_base_from_attributes(skill_id: StringName, attributes: Dictionary) -> float:
	return get_skill_base_modifier(skill_id, attributes)


## Skill base from attributes: explicit simple formulas (death-penalized attributes from `StatsSystem`).
func get_skill_base_modifier(skill_id: StringName, attributes: Dictionary) -> float:
	var s: float = float(attributes.get(_Sch.ATTRIBUTE_STRENGTH, 0.0))
	var a: float = float(attributes.get(_Sch.ATTRIBUTE_ABILITY, 0.0))
	var r: float = float(attributes.get(_Sch.ATTRIBUTE_REFLEXES, 0.0))
	var m: float = float(attributes.get(_Sch.ATTRIBUTE_MIND, 0.0))
	var w: float = float(attributes.get(_Sch.ATTRIBUTE_WISDOM, 0.0))
	match skill_id:
		_Sch.SKILL_MELEE_COMBAT:
			return (s + a) / 3.0
		_Sch.SKILL_MELEE_DEFENSE:
			return (a + r) / 3.0
		_Sch.SKILL_MISSILE_COMBAT:
			return a / 2.0
		_Sch.SKILL_MISSILE_DEFENSE:
			return (a + r) / 5.0
		_Sch.SKILL_MAGIC_COMBAT, _Sch.SKILL_MAGIC_SUPPORT, _Sch.SKILL_MAGIC_DEFENSE:
			return (m + w) / 4.0
		_Sch.SKILL_ALCHEMY:
			return (a + w) / 3.0
		_Sch.SKILL_ARCANE_CONNECTION:
			return w / 3.0
		_Sch.SKILL_COOKING:
			return (a + w) / 3.0
		_Sch.SKILL_FLETCHING:
			return (a + w) / 3.0
		_:
			return 0.0


func get_skill_training_modifier(_skill_id: StringName, skill_rank: int) -> float:
	return float(skill_rank) * skill_rank_modifier_scale


## Total skill modifier used in combat ratings: base (from attributes) + training (from XP ranks).
func get_skill_total_modifier(
	skill_id: StringName, attributes: Dictionary, skill_rank: int
) -> float:
	return (
		get_skill_base_modifier(skill_id, attributes)
		+ get_skill_training_modifier(skill_id, skill_rank)
	)


func get_all_skill_total_modifiers(attributes: Dictionary, skill_levels: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for skill_id in _Sch.ALL_SKILLS:
		var rank: int = int(skill_levels.get(skill_id, 0))
		out[skill_id] = get_skill_total_modifier(StringName(skill_id), attributes, rank)
	return out
