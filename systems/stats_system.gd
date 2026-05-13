class_name StatsSystem
extends Node

const _Sch := preload("res://scripts/character_schema.gd")
const _BalanceScr := preload("res://data/character_balance_config.gd")
const _InvBalScr := preload("res://data/inventory_balance_config.gd")
const _CombatBalanceScr := preload("res://data/combat_balance_config.gd")

signal stats_recomputed(character_id: StringName)

@export var balance: Resource
@export var inventory_balance: Resource

## character_id -> Dictionary of computed stats
var _cache: Dictionary = {}
var _combat_balance: Resource = null


func configure(config: Resource) -> void:
	balance = config


func configure_inventory_penalties(inv_balance: Resource) -> void:
	inventory_balance = inv_balance


func configure_combat_balance(combat_balance: Resource) -> void:
	_combat_balance = combat_balance
	invalidate_all()


func invalidate_all() -> void:
	_cache.clear()


func _ready() -> void:
	if balance == null:
		balance = load("res://data/default_character_balance.tres") as Resource
	if inventory_balance == null:
		inventory_balance = load("res://data/default_inventory_balance.tres") as Resource


func get_effective_stats(character_id: StringName, data: Resource, equipment: Node) -> Dictionary:
	var key: StringName = character_id
	if _cache.has(key):
		return _cache[key] as Dictionary
	var computed: Dictionary = _compute(data, equipment, character_id)
	_cache[key] = computed
	return computed


func invalidate(character_id: StringName) -> void:
	_cache.erase(character_id)
	stats_recomputed.emit(character_id)


func _compute(data: Resource, equipment: Node, character_id: StringName) -> Dictionary:
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
	var death_penalty: float = clampf(float(data.meta.get("death_penalty_percent", 0.0)), 0.0, 0.35)
	var penalty_mult: float = maxf(0.0, 1.0 - death_penalty)

	strn *= penalty_mult
	heart *= penalty_mult
	ability *= penalty_mult
	reflex *= penalty_mult
	mind *= penalty_mult
	wisdom *= penalty_mult
	var penalized_attrs: Dictionary = attrs.duplicate(true)
	penalized_attrs[_Sch.ATTRIBUTE_STRENGTH] = strn
	penalized_attrs[_Sch.ATTRIBUTE_HEARTINESS] = heart
	penalized_attrs[_Sch.ATTRIBUTE_ABILITY] = ability
	penalized_attrs[_Sch.ATTRIBUTE_REFLEXES] = reflex
	penalized_attrs[_Sch.ATTRIBUTE_MIND] = mind
	penalized_attrs[_Sch.ATTRIBUTE_WISDOM] = wisdom

	var strn_e: float = maxf(0.0, strn - pivot_f)
	var heart_e: float = maxf(0.0, heart - pivot_f)
	var ability_e: float = maxf(0.0, ability - pivot_f)
	var reflex_e: float = maxf(0.0, reflex - pivot_f)
	var mind_e: float = maxf(0.0, mind - pivot_f)
	var wisdom_e: float = maxf(0.0, wisdom - pivot_f)

	## Skill modifiers: fixed attribute formulas plus XP ranks (see CharacterBalanceConfig).
	var attrs_for_skills: Dictionary = penalized_attrs
	## Ranks include bought XP ranks plus transient_skill_bonus (buffs), matching combat/display intent.
	var mods: Dictionary
	if cfg is CharacterBalanceConfig:
		mods = (
			(cfg as CharacterBalanceConfig)
			. get_all_skill_total_modifiers(
				attrs_for_skills,
				_merged_skill_ranks_for_modifiers(data),
			)
		)
	else:
		mods = cfg.get_all_skill_modifiers(attrs_for_skills)
	var melee_mod: float = float(mods.get(_Sch.SKILL_MELEE_COMBAT, 0.0))
	var missile_mod: float = float(mods.get(_Sch.SKILL_MISSILE_COMBAT, 0.0))
	var magic_mod: float = float(mods.get(_Sch.SKILL_MAGIC_COMBAT, 0.0))
	var melee_def_mod: float = float(mods.get(_Sch.SKILL_MELEE_DEFENSE, 0.0))
	var magic_def_mod: float = float(mods.get(_Sch.SKILL_MAGIC_DEFENSE, 0.0))
	var missile_def_mod: float = float(mods.get(_Sch.SKILL_MISSILE_DEFENSE, 0.0))
	var arcane_mod: float = float(mods.get(_Sch.SKILL_ARCANE_CONNECTION, 0.0))
	var equip_effects: Dictionary = _equipment_effects(equipment, character_id)
	melee_mod *= float(equip_effects.get("melee_combat_multiplier", 1.0))
	missile_mod *= float(equip_effects.get("missile_combat_multiplier", 1.0))
	melee_def_mod *= float(equip_effects.get("melee_defense_multiplier", 1.0))
	magic_def_mod *= float(equip_effects.get("magic_defense_multiplier", 1.0))
	missile_def_mod *= float(equip_effects.get("missile_defense_multiplier", 1.0))
	arcane_mod *= float(equip_effects.get("arcane_connection_multiplier", 1.0))
	mods[_Sch.SKILL_ARCANE_CONNECTION] = arcane_mod

	var burden_capacity: float = cfg.get_burden_capacity(attrs)
	var burden_ratio: float = inv_cfg.get_burden_ratio(float(data.laden_burden), burden_capacity)
	var pen: Dictionary = inv_cfg.get_penalty_multipliers(burden_ratio)

	melee_def_mod *= float(pen.get("defense_skill_multiplier", 1.0))
	magic_def_mod *= float(pen.get("defense_skill_multiplier", 1.0))
	missile_def_mod *= float(pen.get("defense_skill_multiplier", 1.0))

	## Vitals: Health = Heartiness/2, Stamina = Heartiness, Mana = Mind (attributes after penalties), plus level.
	var max_health: float = heart / 2.0 + float(lvl) * cfg.health_per_level
	var max_stamina: float = heart + float(lvl) * cfg.stamina_per_level
	var max_mana: float = mind + float(lvl) * cfg.mana_per_level

	if cfg is CharacterBalanceConfig:
		var ccfg: CharacterBalanceConfig = cfg as CharacterBalanceConfig
		var vhp: int = int(data.vital_xp_purchases.get("health", 0))
		var vsp: int = int(data.vital_xp_purchases.get("stamina", 0))
		var vma: int = int(data.vital_xp_purchases.get("mana", 0))
		max_health += float(vhp) * ccfg.vital_bonus_health_per_xp_purchase
		max_stamina += float(vsp) * ccfg.vital_bonus_stamina_per_xp_purchase
		max_mana += float(vma) * ccfg.vital_bonus_mana_per_xp_purchase

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
		"death_penalty_percent": death_penalty,
		"melee_attack_interval_sec": _melee_attack_interval(reflex, ability, equip_effects, pen),
		"armor_by_area":
		_armor_by_area_with_transient_bonus(
			equip_effects.get("armor_by_area", {}) as Dictionary, data
		),
		"damage_type_protection_percent":
		(data.transient_damage_protection_percent as Dictionary).duplicate(true),
		"arcane_connection_multiplier":
		float(equip_effects.get("arcane_connection_multiplier", 1.0)),
		"spell_extra_damage_percent": float(equip_effects.get("spell_extra_damage_percent", 0.0)),
		"spell_extra_damage_type": int(equip_effects.get("spell_extra_damage_type", -1)),
		"effective_attributes": penalized_attrs,
	}
	return out


func _armor_by_area_with_transient_bonus(base_armor: Dictionary, data: Resource) -> Dictionary:
	var out: Dictionary = base_armor.duplicate(true)
	var bonus: float = float(data.transient_armor_bonus)
	if bonus <= 0.0:
		return out
	for area in _CombatBalanceScr.BODY_AREAS:
		var area_stats: Dictionary = out.get(area, out.get(String(area), {})) as Dictionary
		area_stats = area_stats.duplicate(true)
		area_stats["armor_level"] = float(area_stats.get("armor_level", 0.0)) + bonus
		if not area_stats.has("damage_ratings"):
			area_stats["damage_ratings"] = {}
		out[area] = area_stats
	return out


func _melee_attack_interval(
	reflex: float, ability: float, equip_effects: Dictionary, burden_penalty: Dictionary
) -> float:
	if _combat_balance == null:
		_combat_balance = load("res://data/default_combat_balance.tres") as Resource
	var base: float = _combat_balance.unarmed_attack_interval_sec
	var stat_factor: float = maxf(
		0.35, 1.0 - maxf(0.0, reflex - 10.0) * 0.012 - maxf(0.0, ability - 10.0) * 0.006
	)
	var equip_bonus: float = float(equip_effects.get("attack_speed_bonus", 0.0))
	var burden_mult: float = float(burden_penalty.get("attack_speed_multiplier", 1.0))
	return maxf(0.5, base * stat_factor * burden_mult / maxf(0.2, 1.0 + equip_bonus))


func _equipment_effects(equipment: Node, character_id: StringName) -> Dictionary:
	var effects: Dictionary = {"armor_by_area": {}}
	if equipment == null:
		return effects
	if not equipment.has_method("get_equipped_details"):
		return effects
	for slot in equipment.get_loadout(character_id).keys():
		var details: Dictionary = (
			equipment.call("get_equipped_details", character_id, StringName(slot)) as Dictionary
		)
		if details.is_empty():
			continue
		var mods: Dictionary = details.get("modifiers", {}) as Dictionary
		for mk in mods.keys():
			var key: String = str(mk)
			var val: float = float(mods[mk])
			if key == "arcane_conversion_multiplier":
				key = "arcane_connection_multiplier"
			if key.ends_with("_multiplier"):
				effects[key] = float(effects.get(key, 1.0)) * val
			else:
				effects[key] = float(effects.get(key, 0.0)) + val
		var area: StringName = _slot_to_body_area(StringName(slot))
		if area != &"":
			(effects["armor_by_area"] as Dictionary)[area] = {
				"armor_level": float(details.get("armor_level", 0.0)),
				"damage_ratings": (details.get("armor_ratings", {}) as Dictionary).duplicate(true),
			}
	return effects


func _slot_to_body_area(slot: StringName) -> StringName:
	match String(slot):
		"head":
			return _CombatBalanceScr.AREA_HEAD
		"shoulders":
			return _CombatBalanceScr.AREA_SHOULDERS
		"chest":
			return _CombatBalanceScr.AREA_CHEST
		"waist":
			return _CombatBalanceScr.AREA_WAIST
		"legs":
			return _CombatBalanceScr.AREA_LEGS
		"feet":
			return _CombatBalanceScr.AREA_FEET
		"hands":
			return _CombatBalanceScr.AREA_HANDS
		_:
			return &""


func _merged_skill_ranks_for_modifiers(data: Resource) -> Dictionary:
	var merged: Dictionary = {}
	for skill_id in _Sch.ALL_SKILLS:
		var bought: int = int(data.skill_levels.get(skill_id, 0))
		var buff: int = int(data.transient_skill_bonus.get(skill_id, 0))
		merged[skill_id] = bought + buff
	return merged
