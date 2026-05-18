class_name EnemyStatBuilder
extends RefCounted

const _Schema := preload("res://scripts/character_schema.gd")
const _CharacterDataScr := preload("res://systems/character_data.gd")
const _BalanceScr := preload("res://data/character_balance_config.gd")
const _StatsSystemScr := preload("res://systems/stats_system.gd")
const _InvBalScr := preload("res://data/inventory_balance_config.gd")
const PRELOAD_CHARACTER_BALANCE := preload("res://data/default_character_balance.tres")
const PRELOAD_INVENTORY_BALANCE := preload("res://data/default_inventory_balance.tres")
const PRELOAD_COMBAT_BALANCE := preload("res://data/default_combat_balance.tres")

const ATTR_FLOOR: int = 10
const ATTR_CAP: int = 75
const ATTR_POINT_POOL: int = 270
const MIN_ENEMY_LEVEL: int = 1
const MAX_ENEMY_LEVEL: int = 3


## Builds a CharacterData sheet and derived combat vitals for first-map enemies.
static func build(
	rng: RandomNumberGenerator = null, balance: CharacterBalanceConfig = null
) -> Dictionary:
	var roll: RandomNumberGenerator = rng if rng != null else _default_rng()
	var cfg: CharacterBalanceConfig = balance if balance != null else _default_balance()
	var data: Resource = _CharacterDataScr.new()
	data.character_id = "enemy_%d" % roll.randi()
	data.level = roll.randi_range(MIN_ENEMY_LEVEL, MAX_ENEMY_LEVEL)
	data.attributes = _roll_attributes(roll)
	data.ensure_defaults()
	_spend_skill_xp_randomly(data, cfg, int(data.level), roll)
	var derived: Dictionary = _compute_derived(data, cfg)
	return {"data": data, "derived": derived}


static func apply_to_combat_test_enemy(enemy: Node, rng: RandomNumberGenerator = null) -> void:
	if enemy == null:
		return
	var built: Dictionary = build(rng)
	var data: Resource = built["data"] as Resource
	var derived: Dictionary = built["derived"] as Dictionary
	if not enemy.has_method("_apply_generated_sheet"):
		return
	enemy.call("_apply_generated_sheet", data, derived)


static func _default_rng() -> RandomNumberGenerator:
	var roll := RandomNumberGenerator.new()
	roll.randomize()
	return roll


static func _default_balance() -> CharacterBalanceConfig:
	return PRELOAD_CHARACTER_BALANCE as CharacterBalanceConfig


static func _roll_attributes(rng: RandomNumberGenerator) -> Dictionary:
	var attrs: Dictionary = {}
	for attr in _Schema.ALL_ATTRIBUTES:
		attrs[attr] = ATTR_FLOOR
	var budget: int = ATTR_POINT_POOL
	while budget > 0:
		var attr_id: String = _Schema.ALL_ATTRIBUTES[rng.randi() % _Schema.ALL_ATTRIBUTES.size()]
		if int(attrs[attr_id]) >= ATTR_CAP:
			continue
		attrs[attr_id] = int(attrs[attr_id]) + 1
		budget -= 1
	return attrs


static func attribute_points_spent_above_floor(attributes: Dictionary) -> int:
	var spent: int = 0
	for attr in _Schema.ALL_ATTRIBUTES:
		spent += maxi(0, int(attributes.get(attr, ATTR_FLOOR)) - ATTR_FLOOR)
	return spent


static func _spend_skill_xp_randomly(
	data: Resource, balance: CharacterBalanceConfig, level: int, rng: RandomNumberGenerator
) -> void:
	var pool: int = balance.get_total_xp_for_level(level)
	data.total_experience = pool
	data.unspent_experience = 0
	while pool > 0:
		var affordable: Array = []
		for skill_id in _Schema.ALL_SKILLS:
			var purchases: int = int(data.skill_xp_purchases.get(skill_id, 0))
			var cost: int = balance.get_unspent_cost_raise_skill(purchases)
			if cost <= pool:
				affordable.append({"skill": skill_id, "cost": cost})
		if affordable.is_empty():
			break
		var pick: Dictionary = affordable[rng.randi() % affordable.size()]
		var skill: String = String(pick["skill"])
		var spend: int = int(pick["cost"])
		var rank: int = int(data.skill_levels.get(skill, 0))
		var bought: int = int(data.skill_xp_purchases.get(skill, 0))
		pool -= spend
		data.skill_levels[skill] = rank + 1
		data.skill_xp_purchases[skill] = bought + 1


static func _compute_derived(data: Resource, balance: CharacterBalanceConfig) -> Dictionary:
	var stats: Node = _StatsSystemScr.new()
	stats.configure(balance)
	stats.configure_inventory_penalties(PRELOAD_INVENTORY_BALANCE as Resource)
	stats.configure_combat_balance(PRELOAD_COMBAT_BALANCE as Resource)
	var cid: StringName = StringName(String(data.character_id))
	var eff: Dictionary = stats.get_effective_stats(cid, data, null)
	stats.free()
	return eff
