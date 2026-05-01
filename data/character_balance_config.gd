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

@export_group("Pools (max)")
## Baseline at `attribute_formula_pivot` with zero excess Heartiness/Strength (see StatsSystem).
@export var health_base: float = 90.0
## Added per point of Heartiness above `attribute_formula_pivot`.
@export var health_per_heartiness: float = 2.45
## Added per point of Strength above pivot.
@export var health_per_strength: float = 0.42
@export var health_per_level: float = 2.0

@export var stamina_base: float = 78.0
@export var stamina_per_heartiness: float = 1.12
@export var stamina_per_reflexes: float = 1.12
@export var stamina_per_level: float = 1.6

@export var mana_base: float = 44.0
@export var mana_per_mind: float = 1.08
@export var mana_per_wisdom: float = 1.32
@export var mana_per_level: float = 1.4

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
## Attributes at this value contribute only the vitals base (no per-stat slope). Matches creation floor N.
@export var attribute_formula_pivot: int = 10

@export_group("Skill formula (base from attributes + training ranks)")
## Conceptual match to examples like (weighted attrs) / 3 — applied to the attribute-derived term only.
@export var skill_base_divisor: float = 3.0
## Each stored attribute point above the pivot is multiplied by this before skill weights (keeps modifiers sane when Z is large).
@export var skill_attribute_stretch: float = 0.185
## Each skill rank bought with XP adds this much to the combat skill modifier (after base scaling).
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


func attributes_for_skill_formulas(attributes: Dictionary) -> Dictionary:
	var pivot: float = float(attribute_formula_pivot)
	var out: Dictionary = {}
	for attr in _Sch.ALL_ATTRIBUTES:
		var v: float = float(attributes.get(attr, pivot))
		out[attr] = pivot + maxf(0.0, v - pivot) * skill_attribute_stretch
	return out


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
	# Design: each skill pulls primarily from thematically aligned attributes.
	return {
		_Sch.SKILL_COOKING:
		{
			_Sch.ATTRIBUTE_HEARTINESS: 0.35,
			_Sch.ATTRIBUTE_MIND: 0.35,
			_Sch.ATTRIBUTE_ABILITY: 0.30,
		},
		_Sch.SKILL_ALCHEMY:
		{
			_Sch.ATTRIBUTE_MIND: 0.45,
			_Sch.ATTRIBUTE_WISDOM: 0.35,
			_Sch.ATTRIBUTE_ABILITY: 0.20,
		},
		_Sch.SKILL_FLETCHING:
		{
			_Sch.ATTRIBUTE_ABILITY: 0.40,
			_Sch.ATTRIBUTE_REFLEXES: 0.35,
			_Sch.ATTRIBUTE_STRENGTH: 0.25,
		},
		_Sch.SKILL_MELEE_COMBAT:
		{
			_Sch.ATTRIBUTE_STRENGTH: 0.45,
			_Sch.ATTRIBUTE_REFLEXES: 0.30,
			_Sch.ATTRIBUTE_ABILITY: 0.25,
		},
		_Sch.SKILL_MISSILE_COMBAT:
		{
			_Sch.ATTRIBUTE_REFLEXES: 0.45,
			_Sch.ATTRIBUTE_ABILITY: 0.35,
			_Sch.ATTRIBUTE_STRENGTH: 0.20,
		},
		_Sch.SKILL_MAGIC_COMBAT:
		{
			_Sch.ATTRIBUTE_MIND: 0.40,
			_Sch.ATTRIBUTE_WISDOM: 0.35,
			_Sch.ATTRIBUTE_ABILITY: 0.25,
		},
		_Sch.SKILL_MAGIC_SUPPORT:
		{
			_Sch.ATTRIBUTE_WISDOM: 0.45,
			_Sch.ATTRIBUTE_MIND: 0.35,
			_Sch.ATTRIBUTE_HEARTINESS: 0.20,
		},
		_Sch.SKILL_MELEE_DEFENSE:
		{
			_Sch.ATTRIBUTE_HEARTINESS: 0.40,
			_Sch.ATTRIBUTE_STRENGTH: 0.30,
			_Sch.ATTRIBUTE_REFLEXES: 0.30,
		},
		_Sch.SKILL_MAGIC_DEFENSE:
		{
			_Sch.ATTRIBUTE_WISDOM: 0.40,
			_Sch.ATTRIBUTE_MIND: 0.35,
			_Sch.ATTRIBUTE_HEARTINESS: 0.25,
		},
		_Sch.SKILL_MISSILE_DEFENSE:
		{
			_Sch.ATTRIBUTE_REFLEXES: 0.40,
			_Sch.ATTRIBUTE_HEARTINESS: 0.30,
			_Sch.ATTRIBUTE_ABILITY: 0.30,
		},
		_Sch.SKILL_ARCANE_CONNECTION:
		{
			_Sch.ATTRIBUTE_MIND: 0.40,
			_Sch.ATTRIBUTE_WISDOM: 0.40,
			_Sch.ATTRIBUTE_ABILITY: 0.20,
		},
	}


func get_skill_modifier_from_attributes(skill_id: StringName, attributes: Dictionary) -> float:
	var table: Variant = get_skill_attribute_weights().get(skill_id, {})
	if typeof(table) != TYPE_DICTIONARY:
		return 0.0
	var weights: Dictionary = table as Dictionary
	var total: float = 0.0
	for attr_key in weights.keys():
		var w: float = float(weights.get(attr_key, 0.0))
		var value: float = float(attributes.get(attr_key, 0.0))
		total += value * w
	return total


func get_all_skill_modifiers(attributes: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for skill_id in _Sch.ALL_SKILLS:
		out[skill_id] = get_skill_modifier_from_attributes(StringName(skill_id), attributes)
	return out


## Attribute-only term (before / skill_base_divisor). Same as weighted sum Σ (weight_a × attribute_a).
func get_skill_base_from_attributes(skill_id: StringName, attributes: Dictionary) -> float:
	return get_skill_modifier_from_attributes(skill_id, attributes)


## Combat/display base modifier: (weighted attribute sum) / skill_base_divisor — same shape as "(Str + Ability) / 3" but using full weight tables.
func get_skill_base_modifier(skill_id: StringName, attributes: Dictionary) -> float:
	return (
		get_skill_modifier_from_attributes(skill_id, attributes) / maxf(0.001, skill_base_divisor)
	)


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
