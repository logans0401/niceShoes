class_name StatsSystem
extends Node

const _Sch := preload("res://scripts/character_schema.gd")
const _BalanceScr := preload("res://data/character_balance_config.gd")
const _InvBalScr := preload("res://data/inventory_balance_config.gd")

signal stats_recomputed(character_id: StringName)

@export var balance: Resource
@export var inventory_balance: Resource

## character_id -> Dictionary of computed stats
var _cache: Dictionary = {}


func configure(config: Resource) -> void:
	balance = config


func configure_inventory_penalties(inv_balance: Resource) -> void:
	inventory_balance = inv_balance


func _ready() -> void:
	if balance == null:
		balance = load("res://data/default_character_balance.tres") as Resource
	if inventory_balance == null:
		inventory_balance = load("res://data/default_inventory_balance.tres") as Resource


func get_effective_stats(character_id: StringName, data: Resource, equipment: Node) -> Dictionary:
	var key: StringName = character_id
	if _cache.has(key):
		return _cache[key] as Dictionary
	var computed: Dictionary = _compute(data, equipment.get_loadout(character_id))
	_cache[key] = computed
	return computed


func invalidate(character_id: StringName) -> void:
	_cache.erase(character_id)
	stats_recomputed.emit(character_id)


func _compute(data: Resource, _loadout: Dictionary) -> Dictionary:
	var cfg: Resource = balance
	if cfg == null:
		cfg = _BalanceScr.new()
	var inv_cfg: Resource = inventory_balance
	if inv_cfg == null:
		inv_cfg = _InvBalScr.new()

	var attrs: Dictionary = data.attributes
	var lvl: int = clampi(data.level, 1, cfg.max_level)

	var pivot_f: float = 10.0
	if cfg is CharacterBalanceConfig:
		pivot_f = float((cfg as CharacterBalanceConfig).attribute_formula_pivot)

	var strn: float = float(attrs.get(_Sch.ATTRIBUTE_STRENGTH, pivot_f))
	var heart: float = float(attrs.get(_Sch.ATTRIBUTE_HEARTINESS, pivot_f))
	var ability: float = float(attrs.get(_Sch.ATTRIBUTE_ABILITY, pivot_f))
	var reflex: float = float(attrs.get(_Sch.ATTRIBUTE_REFLEXES, pivot_f))
	var mind: float = float(attrs.get(_Sch.ATTRIBUTE_MIND, pivot_f))
	var wisdom: float = float(attrs.get(_Sch.ATTRIBUTE_WISDOM, pivot_f))

	var strn_e: float = maxf(0.0, strn - pivot_f)
	var heart_e: float = maxf(0.0, heart - pivot_f)
	var ability_e: float = maxf(0.0, ability - pivot_f)
	var reflex_e: float = maxf(0.0, reflex - pivot_f)
	var mind_e: float = maxf(0.0, mind - pivot_f)
	var wisdom_e: float = maxf(0.0, wisdom - pivot_f)

	## Skill modifiers use stretched attributes so Z=100 creation does not explode combat math.
	var attrs_for_skills: Dictionary = attrs
	if cfg is CharacterBalanceConfig:
		attrs_for_skills = (cfg as CharacterBalanceConfig).attributes_for_skill_formulas(attrs)

	## Skill modifiers = (weighted attributes / skill_base_divisor) + (rank × skill_rank_modifier_scale); see CharacterBalanceConfig.
	## Ranks include bought XP ranks plus transient_skill_bonus (buffs), matching combat/display intent.
	var mods: Dictionary
	if cfg is CharacterBalanceConfig:
		mods = (cfg as CharacterBalanceConfig).get_all_skill_total_modifiers(
			attrs_for_skills,
			_merged_skill_ranks_for_modifiers(data),
		)
	else:
		mods = cfg.get_all_skill_modifiers(attrs_for_skills)
	var melee_mod: float = float(mods.get(_Sch.SKILL_MELEE_COMBAT, 0.0))
	var missile_mod: float = float(mods.get(_Sch.SKILL_MISSILE_COMBAT, 0.0))
	var magic_mod: float = float(mods.get(_Sch.SKILL_MAGIC_COMBAT, 0.0))
	var melee_def_mod: float = float(mods.get(_Sch.SKILL_MELEE_DEFENSE, 0.0))
	var magic_def_mod: float = float(mods.get(_Sch.SKILL_MAGIC_DEFENSE, 0.0))
	var missile_def_mod: float = float(mods.get(_Sch.SKILL_MISSILE_DEFENSE, 0.0))

	var burden_capacity: float = cfg.get_burden_capacity(attrs)
	var burden_ratio: float = inv_cfg.get_burden_ratio(float(data.laden_burden), burden_capacity)
	var pen: Dictionary = inv_cfg.get_penalty_multipliers(burden_ratio)

	melee_def_mod *= float(pen.get("defense_skill_multiplier", 1.0))
	magic_def_mod *= float(pen.get("defense_skill_multiplier", 1.0))
	missile_def_mod *= float(pen.get("defense_skill_multiplier", 1.0))

	var max_health: float = (
		cfg.health_base
		+ heart_e * cfg.health_per_heartiness
		+ strn_e * cfg.health_per_strength
		+ float(lvl) * cfg.health_per_level
	)
	var max_stamina: float = (
		cfg.stamina_base
		+ heart_e * cfg.stamina_per_heartiness
		+ reflex_e * cfg.stamina_per_reflexes
		+ float(lvl) * cfg.stamina_per_level
	)
	var max_mana: float = (
		cfg.mana_base
		+ mind_e * cfg.mana_per_mind
		+ wisdom_e * cfg.mana_per_wisdom
		+ float(lvl) * cfg.mana_per_level
	)

	var attack_rating: float = (
		cfg.attack_skill_scale * (melee_mod + 0.35 * missile_mod + 0.25 * magic_mod)
		+ strn_e * 0.35
		+ ability_e * 0.25
		+ reflex_e * 0.2
	)
	var defense_rating: float = (
		cfg.defense_skill_scale * (melee_def_mod + 0.35 * magic_def_mod + 0.25 * missile_def_mod)
		+ heart_e * 0.35
		+ wisdom_e * 0.2
		+ reflex_e * 0.15
	)

	var out: Dictionary = {
		"max_health": max_health,
		"max_stamina": max_stamina,
		"max_mana": max_mana,
		"burden_capacity": burden_capacity,
		"burden_ratio": burden_ratio,
		"attack_rating": attack_rating,
		"defense_rating": defense_rating,
		"level": lvl,
		"skill_modifiers": mods,
		"xp_into_level": cfg.get_xp_into_level(data.total_experience, lvl),
		"xp_to_next_level": cfg.get_xp_to_next_level(data.total_experience, lvl),
		"movement_speed_multiplier": float(pen.get("movement_speed_multiplier", 1.0)),
		"attack_speed_multiplier": float(pen.get("attack_speed_multiplier", 1.0)),
		"stamina_use_multiplier": float(pen.get("stamina_use_multiplier", 1.0)),
		"defense_skill_multiplier": float(pen.get("defense_skill_multiplier", 1.0)),
		"health_regen_multiplier": float(pen.get("health_regen_multiplier", 1.0)),
		"stamina_regen_multiplier": float(pen.get("stamina_regen_multiplier", 1.0)),
	}
	return out


func _merged_skill_ranks_for_modifiers(data: Resource) -> Dictionary:
	var merged: Dictionary = {}
	for skill_id in _Sch.ALL_SKILLS:
		var bought: int = int(data.skill_levels.get(skill_id, 0))
		var buff: int = int(data.transient_skill_bonus.get(skill_id, 0))
		merged[skill_id] = bought + buff
	return merged
