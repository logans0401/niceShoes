class_name CombatSystem
extends Node

signal combat_event_logged(message: String)


func resolve_melee_hit(
	attacker_stats: Dictionary,
	defender_stats: Dictionary,
	damage_type: int = DamageTypes.Id.SLASHING,
	weapon_damage_min: int = 0,
	weapon_damage_max: int = 0,
) -> Dictionary:
	var atk: float = float(attacker_stats.get("attack_rating", 5.0))
	var def: float = float(defender_stats.get("defense_rating", 3.0))
	var raw: float
	var lo: int = mini(weapon_damage_min, weapon_damage_max)
	var hi: int = maxi(weapon_damage_min, weapon_damage_max)
	if hi <= 0:
		raw = maxf(1.0, atk - def * 0.35)
	else:
		var rolled: float = float(randi_range(lo, hi))
		raw = maxf(1.0, rolled + atk - def * 0.35)
	var damage: float = snappedf(raw, 0.5)
	var dt: StringName = DamageTypes.id_to_string(damage_type)
	combat_event_logged.emit("Hit (%s) for %.1f" % [String(dt), damage])
	return {"damage": damage, "hit": true, "damage_type": damage_type}


func apply_damage(_target_id: StringName, amount: float) -> void:
	## Legacy no-op hook; use apply_vitals_damage for real HP changes.
	combat_event_logged.emit("Applied %.1f damage (no vitals target)" % amount)


func apply_vitals_damage(registry: Node, stats: Node, character_id: StringName, amount: float) -> void:
	if registry == null or amount <= 0.0:
		return
	if not registry.has_method("get_character"):
		return
	var data: Resource = registry.get_character(character_id)
	if data == null:
		return
	var cur: float = float(data.current_health)
	data.current_health = maxf(0.0, cur - amount)
	combat_event_logged.emit("%s took %.1f damage (%.1f HP left)" % [String(character_id), amount, data.current_health])
	if stats != null and stats.has_method("invalidate"):
		stats.invalidate(character_id)
