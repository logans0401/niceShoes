class_name CharacterProgressionSystem
extends Node

const _Schema := preload("res://scripts/character_schema.gd")
const CharacterBalanceConfig := preload("res://data/character_balance_config.gd")

signal level_changed(character_id: StringName, new_level: int)
signal skill_rank_changed(character_id: StringName, skill_id: StringName, new_rank: int)
signal attribute_changed(character_id: StringName, attribute_id: StringName, new_value: int)
signal experience_awarded(character_id: StringName, amount: int)
signal unspent_changed(character_id: StringName, new_unspent: int)

var _registry: Node
var _balance: Resource
var _combat_balance: Resource = null


func configure(registry: Node, balance: Resource, combat_balance: Resource = null) -> void:
	_registry = registry
	_balance = balance
	_combat_balance = combat_balance
	_ensure_combat_balance()


## All XP gains: increases lifetime total (level) and unspent pool by the same amount.
func add_total_experience(character_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var data: Resource = _registry.get_character(character_id)
	if data == null or _balance == null:
		return
	data.total_experience += amount
	data.unspent_experience += amount
	_reduce_death_penalty(data, amount)
	_recompute_level(data, character_id)
	experience_awarded.emit(character_id, amount)
	unspent_changed.emit(character_id, data.unspent_experience)


## Split a base award among characters. If `apply_same_map_bonus`, total pool is +15% before split.
func distribute_experience_among(
	character_ids: PackedStringArray,
	base_amount: int,
	apply_same_map_bonus: bool,
) -> void:
	if base_amount <= 0 or character_ids.is_empty():
		return
	var pool: float = float(base_amount)
	if apply_same_map_bonus:
		pool *= 1.15
	var total: int = maxi(1, int(floor(pool)))
	var n: int = character_ids.size()
	var each: int = int(total / float(n))
	var rem: int = total % n
	for i in range(n):
		var share: int = each + (1 if i < rem else 0)
		if share > 0:
			add_total_experience(character_ids[i], share)


func try_raise_attribute(character_id: StringName, attribute_id: StringName) -> Error:
	var data: Resource = _registry.get_character(character_id)
	if data == null or _balance == null:
		return ERR_DOES_NOT_EXIST
	if not String(attribute_id) in _Schema.ALL_ATTRIBUTES:
		return ERR_INVALID_PARAMETER
	var cap: int = int(_balance.max_attribute_value)
	var value: int = int(data.attributes.get(attribute_id, 10))
	if value >= cap:
		return ERR_OUT_OF_MEMORY
	var purchases: int = int(data.attribute_xp_purchases.get(String(attribute_id), 0))
	var cost: int = _balance.get_unspent_cost_for_xp_purchase_count(purchases)
	if data.unspent_experience < cost:
		return FAILED
	data.unspent_experience -= cost
	value += 1
	data.attributes[attribute_id] = value
	data.attribute_xp_purchases[String(attribute_id)] = purchases + 1
	unspent_changed.emit(character_id, data.unspent_experience)
	attribute_changed.emit(character_id, attribute_id, value)
	return OK


func try_raise_skill(character_id: StringName, skill_id: StringName) -> Error:
	var data: Resource = _registry.get_character(character_id)
	if data == null or _balance == null:
		return ERR_DOES_NOT_EXIST
	if not String(skill_id) in _Schema.ALL_SKILLS:
		return ERR_INVALID_PARAMETER
	var rank: int = int(data.skill_levels.get(skill_id, 0))
	var purchases: int = int(data.skill_xp_purchases.get(String(skill_id), 0))
	var cost: int = _balance.get_unspent_cost_raise_skill(purchases)
	if data.unspent_experience < cost:
		return FAILED
	data.unspent_experience -= cost
	rank += 1
	data.skill_levels[skill_id] = rank
	data.skill_xp_purchases[String(skill_id)] = purchases + 1
	unspent_changed.emit(character_id, data.unspent_experience)
	skill_rank_changed.emit(character_id, skill_id, rank)
	return OK


## Raise max Health, Stamina, or Mana via XP (keys: "health", "stamina", "mana").
func try_raise_vital_pool(character_id: StringName, vital_key: StringName) -> Error:
	var data: Resource = _registry.get_character(character_id)
	if data == null or _balance == null:
		return ERR_DOES_NOT_EXIST
	var k: String = String(vital_key)
	if k != "health" and k != "stamina" and k != "mana":
		return ERR_INVALID_PARAMETER
	if not (_balance is CharacterBalanceConfig):
		return FAILED
	var cfg: CharacterBalanceConfig = _balance as CharacterBalanceConfig
	var purchases: int = int(data.vital_xp_purchases.get(k, 0))
	var cost: int = cfg.get_unspent_cost_for_xp_purchase_count(purchases)
	if data.unspent_experience < cost:
		return FAILED
	data.unspent_experience -= cost
	data.vital_xp_purchases[k] = purchases + 1
	match k:
		"health":
			data.current_health += cfg.vital_bonus_health_per_xp_purchase
		"stamina":
			data.current_stamina += cfg.vital_bonus_stamina_per_xp_purchase
		"mana":
			data.current_mana += cfg.vital_bonus_mana_per_xp_purchase
	unspent_changed.emit(character_id, data.unspent_experience)
	return OK


## Practice / activity hooks: award normal XP (counts toward level and unspent).
func add_skill_experience(character_id: StringName, _skill_id: StringName, amount: int) -> void:
	add_total_experience(character_id, amount)


func add_attribute_experience(
	character_id: StringName, _attribute_id: StringName, amount: int
) -> void:
	add_total_experience(character_id, amount)


func apply_death_penalty(character_id: StringName) -> void:
	var data: Resource = _registry.get_character(character_id)
	if data == null:
		return
	_ensure_combat_balance()
	var cur: float = float(data.meta.get("death_penalty_percent", 0.0))
	var next: float = minf(
		_combat_balance.death_penalty_max, cur + _combat_balance.death_penalty_per_death
	)
	data.meta["death_penalty_percent"] = next


func _ensure_combat_balance() -> void:
	if _combat_balance != null:
		return
	_combat_balance = load("res://data/default_combat_balance.tres") as Resource


func _reduce_death_penalty(data: Resource, amount: int) -> void:
	if _combat_balance == null:
		return
	var cur: float = float(data.meta.get("death_penalty_percent", 0.0))
	if cur <= 0.0:
		return
	var next: float = maxf(0.0, cur - float(amount) * _combat_balance.death_penalty_recovery_per_xp)
	data.meta["death_penalty_percent"] = next


func sync_level_from_xp(character_id: StringName) -> void:
	var data: Resource = _registry.get_character(character_id)
	if data == null or _balance == null:
		return
	_recompute_level(data, character_id)


func sync_all_levels() -> void:
	if _registry == null:
		return
	for id in _registry.list_character_ids():
		sync_level_from_xp(id)


func _recompute_level(data: Resource, character_id: StringName) -> void:
	var new_level: int = _balance.get_level_from_total_xp(data.total_experience)
	new_level = clampi(new_level, 1, _balance.max_level)
	if new_level != data.level:
		data.level = new_level
		level_changed.emit(character_id, new_level)
