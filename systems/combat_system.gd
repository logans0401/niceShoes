class_name CombatSystem
extends Node

const _Sch := preload("res://scripts/character_schema.gd")

signal combat_event_logged(message: String)
signal character_died(character_id: StringName)

var _combat_balance: Resource = null


func configure(combat_balance: Resource = null) -> void:
	_combat_balance = combat_balance
	if _combat_balance == null:
		_combat_balance = load("res://data/default_combat_balance.tres") as Resource


func _ready() -> void:
	if _combat_balance == null:
		configure()


func melee_evade_chance(attacker_stats: Dictionary, defender_stats: Dictionary) -> float:
	if _combat_balance == null:
		configure()
	var melee_atk: float = _melee_skill_from_stats(
		attacker_stats, &"attack_rating", _Sch.SKILL_MELEE_COMBAT
	)
	var melee_def: float = _melee_skill_from_stats(
		defender_stats, &"defense_rating", _Sch.SKILL_MELEE_DEFENSE
	)
	var contest_sum: float = melee_def + melee_atk
	var contest: float = melee_def / contest_sum if contest_sum > 0.0 else 0.0
	return clampf(
		(
			contest * float(_combat_balance.melee_evade_scale)
			+ float(_combat_balance.melee_evade_base)
		),
		float(_combat_balance.melee_evade_min),
		float(_combat_balance.melee_evade_max),
	)


func resolve_melee_hit(
	attacker_stats: Dictionary,
	defender_stats: Dictionary,
	damage_type: int = DamageTypes.Id.SLASHING,
	weapon_damage_min: int = 0,
	weapon_damage_max: int = 0,
	evade_roll: float = -1.0,
) -> Dictionary:
	if _combat_balance == null:
		configure()
	var evade_chance: float = melee_evade_chance(attacker_stats, defender_stats)
	var roll: float = evade_roll if evade_roll >= 0.0 else randf()
	if roll < evade_chance:
		combat_event_logged.emit("Attack evaded (%.0f%% chance)" % (evade_chance * 100.0))
		return {
			"damage": 0.0,
			"raw_damage": 0.0,
			"mitigation": 0.0,
			"hit": false,
			"evaded": true,
			"evade_chance": evade_chance,
			"damage_type": damage_type,
			"target_area": &"",
		}
	var melee_atk: float = _melee_skill_from_stats(
		attacker_stats, &"attack_rating", _Sch.SKILL_MELEE_COMBAT
	)
	var melee_def: float = _melee_skill_from_stats(
		defender_stats, &"defense_rating", _Sch.SKILL_MELEE_DEFENSE
	)
	var skill_dmg: float = melee_atk * float(_combat_balance.melee_skill_damage_scale)
	var skill_mit: float = melee_def * float(_combat_balance.melee_defense_damage_scale)
	var raw: float
	var lo: int = mini(weapon_damage_min, weapon_damage_max)
	var hi: int = maxi(weapon_damage_min, weapon_damage_max)
	if hi <= 0:
		raw = maxf(1.0, skill_dmg - skill_mit)
	else:
		var rolled: float = float(randi_range(lo, hi))
		raw = maxf(1.0, rolled + skill_dmg - skill_mit)
	var target_area: StringName = _combat_balance.pick_body_area()
	var mitigated: Dictionary = _apply_area_mitigation(
		raw, defender_stats, target_area, damage_type
	)
	var damage: float = snappedf(float(mitigated.get("damage", raw)), 0.5)
	var dt: StringName = DamageTypes.id_to_string(damage_type)
	combat_event_logged.emit("Hit %s (%s) for %.1f" % [String(target_area), String(dt), damage])
	return {
		"damage": damage,
		"raw_damage": raw,
		"mitigation": float(mitigated.get("mitigation", 0.0)),
		"hit": true,
		"evaded": false,
		"evade_chance": evade_chance,
		"damage_type": damage_type,
		"target_area": target_area,
	}


func _melee_skill_from_stats(
	stats: Dictionary, rating_key: StringName, skill_id: StringName
) -> float:
	var sm: Dictionary = stats.get("skill_modifiers", {}) as Dictionary
	var sid: String = String(skill_id)
	if sm.has(skill_id) or sm.has(sid):
		return float(sm.get(skill_id, sm.get(sid, 0.0)))
	var legacy_scale: float = (
		float(_combat_balance.legacy_defense_rating_skill_scale)
		if skill_id == _Sch.SKILL_MELEE_DEFENSE
		else float(_combat_balance.legacy_attack_rating_skill_scale)
	)
	return float(stats.get(rating_key, 0.0)) / maxf(0.01, legacy_scale)


func apply_damage(_target_id: StringName, amount: float) -> void:
	## Legacy no-op hook; use apply_vitals_damage for real HP changes.
	combat_event_logged.emit("Applied %.1f damage (no vitals target)" % amount)


func apply_vitals_damage(
	registry: Node, stats: Node, character_id: StringName, amount: float
) -> Dictionary:
	if registry == null or amount <= 0.0:
		return {"died": false}
	if not registry.has_method("get_character"):
		return {"died": false}
	var data: Resource = registry.get_character(character_id)
	if data == null:
		return {"died": false}
	var cur: float = float(data.current_health)
	data.current_health = maxf(0.0, cur - amount)
	combat_event_logged.emit(
		"%s took %.1f damage (%.1f HP left)" % [String(character_id), amount, data.current_health]
	)
	if stats != null and stats.has_method("invalidate"):
		stats.invalidate(character_id)
	var died: bool = cur > 0.0 and data.current_health <= 0.0
	if died:
		character_died.emit(character_id)
	return {"died": died, "health": data.current_health}


func _apply_area_mitigation(
	raw_damage: float,
	defender_stats: Dictionary,
	target_area: StringName,
	damage_type: int,
) -> Dictionary:
	var by_area: Dictionary = defender_stats.get("armor_by_area", {}) as Dictionary
	var area_stats: Dictionary = (
		by_area.get(target_area, by_area.get(String(target_area), {})) as Dictionary
	)
	var armor_level: float = float(area_stats.get("armor_level", 0.0))
	var ratings: Dictionary = area_stats.get("damage_ratings", {}) as Dictionary
	var rating: float = float(ratings.get(damage_type, ratings.get(str(damage_type), 0.0)))
	var protections: Dictionary = (
		defender_stats.get("damage_type_protection_percent", {}) as Dictionary
	)
	var protection_percent: float = clampf(
		float(protections.get(damage_type, protections.get(str(damage_type), 0.0))),
		0.0,
		0.95,
	)
	var mitigation: float = (
		armor_level * _combat_balance.armor_level_mitigation_scale
		+ rating * _combat_balance.armor_rating_mitigation_scale
	)
	var dmg: float = raw_damage - mitigation
	dmg *= 1.0 - protection_percent
	if raw_damage > 0.0:
		dmg = maxf(_combat_balance.minimum_damage_after_mitigation, dmg)
	return {"damage": dmg, "mitigation": mitigation, "protection_percent": protection_percent}
