class_name CharacterProgressionSystem
extends Node

const _Schema := preload("res://scripts/character_schema.gd")

signal level_changed(character_id: StringName, new_level: int)
signal skill_rank_changed(character_id: StringName, skill_id: StringName, new_rank: int)
signal attribute_changed(character_id: StringName, attribute_id: StringName, new_value: int)
signal experience_awarded(character_id: StringName, amount: int)
signal unspent_changed(character_id: StringName, new_unspent: int)

var _registry: Node
var _balance: Resource


func configure(registry: Node, balance: Resource) -> void:
	_registry = registry
	_balance = balance


## All XP gains: increases lifetime total (level) and unspent pool by the same amount.
func add_total_experience(character_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var data: Resource = _registry.get_character(character_id)
	if data == null or _balance == null:
		return
	data.total_experience += amount
	data.unspent_experience += amount
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
	var cost: int = _balance.get_unspent_cost_raise_attribute(value)
	if data.unspent_experience < cost:
		return FAILED
	data.unspent_experience -= cost
	value += 1
	data.attributes[attribute_id] = value
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
	var cost: int = _balance.get_unspent_cost_raise_skill(rank)
	if data.unspent_experience < cost:
		return FAILED
	data.unspent_experience -= cost
	rank += 1
	data.skill_levels[skill_id] = rank
	unspent_changed.emit(character_id, data.unspent_experience)
	skill_rank_changed.emit(character_id, skill_id, rank)
	return OK


## Practice / activity hooks: award normal XP (counts toward level and unspent).
func add_skill_experience(character_id: StringName, _skill_id: StringName, amount: int) -> void:
	add_total_experience(character_id, amount)


func add_attribute_experience(character_id: StringName, _attribute_id: StringName, amount: int) -> void:
	add_total_experience(character_id, amount)


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
