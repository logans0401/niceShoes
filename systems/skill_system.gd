class_name SkillSystem
extends Node

signal skill_learned(character_id: StringName, skill_id: StringName)
signal skill_used(character_id: StringName, skill_id: StringName)

var _registry: Node


func configure(registry: Node) -> void:
	_registry = registry


func get_skill_level(character_id: StringName, skill_id: StringName) -> int:
	if _registry == null:
		return 0
	var data: Resource = _registry.get_character(character_id)
	if data == null:
		return 0
	return int(data.skill_levels.get(skill_id, 0))


func learn(character_id: StringName, skill_id: StringName) -> void:
	if _registry == null:
		return
	var data: Resource = _registry.get_character(character_id)
	if data == null:
		return
	if int(data.skill_levels.get(skill_id, 0)) > 0:
		return
	data.skill_levels[skill_id] = 1
	skill_learned.emit(character_id, skill_id)


func use_skill(character_id: StringName, skill_id: StringName) -> void:
	skill_used.emit(character_id, skill_id)
