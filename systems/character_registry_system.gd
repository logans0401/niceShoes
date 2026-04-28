class_name CharacterRegistrySystem
extends Node

const _Schema := preload("res://scripts/character_schema.gd")

signal character_registered(character_id: StringName)
signal character_unregistered(character_id: StringName)

var _balance: Resource
var _characters: Dictionary = {}


func configure(balance: Resource) -> void:
	_balance = balance


func get_balance() -> Resource:
	return _balance


func get_character(character_id: StringName) -> Resource:
	return _characters.get(character_id, null) as Resource


func list_character_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in _characters.keys():
		out.append(StringName(id))
	return out


func get_count() -> int:
	return _characters.size()


func can_register() -> bool:
	return _characters.size() < _Schema.MAX_CHARACTERS


func register_character(data: Resource) -> Error:
	if data == null:
		return ERR_INVALID_PARAMETER
	data.ensure_defaults()
	if String(data.character_id).is_empty():
		return ERR_INVALID_DATA
	if _characters.size() >= _Schema.MAX_CHARACTERS and not _characters.has(data.character_id):
		return ERR_OUT_OF_MEMORY
	_characters[data.character_id] = data
	character_registered.emit(StringName(data.character_id))
	return OK


func unregister_character(character_id: StringName) -> void:
	if _characters.has(character_id):
		_characters.erase(character_id)
		character_unregistered.emit(character_id)


func clear() -> void:
	_characters.clear()
