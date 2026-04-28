class_name GroupSystem
extends Node

const _Schema := preload("res://scripts/character_schema.gd")

signal active_group_changed(group_id: StringName)
signal group_roster_changed(group_id: StringName)

var _registry: Node

## group_id -> Array of character_ids (StringName)
var _groups: Dictionary = {}
var _active_group_id: StringName = &"default"


func configure(registry: Node) -> void:
	_registry = registry
	if not _groups.has(_active_group_id):
		_groups[_active_group_id] = [] as Array


func _ready() -> void:
	if not _groups.has(_active_group_id):
		_groups[_active_group_id] = [] as Array


func get_active_group_id() -> StringName:
	return _active_group_id


func set_active_group(group_id: StringName) -> void:
	_active_group_id = group_id
	if not _groups.has(_active_group_id):
		_groups[_active_group_id] = [] as Array
	active_group_changed.emit(_active_group_id)


func list_group_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _groups.keys():
		out.append(StringName(k))
	return out


func get_roster(group_id: StringName = &"") -> PackedStringArray:
	var gid: StringName = _active_group_id if group_id == &"" else group_id
	var roster: Array = _groups.get(gid, []) as Array
	var out: PackedStringArray = PackedStringArray()
	for id in roster:
		out.append(StringName(id))
	return out


func add_member(character_id: StringName, group_id: StringName = &"") -> Error:
	if _registry == null:
		return FAILED
	var data: Resource = _registry.get_character(character_id)
	if data == null:
		return ERR_DOES_NOT_EXIST
	var gid: StringName = _active_group_id if group_id == &"" else group_id
	var roster: Array = _groups.get(gid, []) as Array
	if character_id in roster:
		return OK
	if roster.size() >= _Schema.MAX_PARTY_SIZE:
		return ERR_OUT_OF_MEMORY
	roster.append(character_id)
	_groups[gid] = roster
	group_roster_changed.emit(gid)
	return OK


func remove_member(character_id: StringName, group_id: StringName = &"") -> Error:
	var gid: StringName = _active_group_id if group_id == &"" else group_id
	var roster: Array = _groups.get(gid, []) as Array
	var idx: int = roster.find(character_id)
	if idx < 0:
		return ERR_DOES_NOT_EXIST
	if roster.size() <= _Schema.MIN_PARTY_SIZE:
		return ERR_LOCKED
	roster.remove_at(idx)
	_groups[gid] = roster
	group_roster_changed.emit(gid)
	return OK


func create_new_group() -> StringName:
	var gid: StringName = StringName("group_%d" % Time.get_ticks_msec())
	while _groups.has(gid):
		gid = StringName("group_%d_%d" % [Time.get_ticks_msec(), randi() % 100000])
	_groups[gid] = [] as Array
	group_roster_changed.emit(gid)
	return gid


func try_set_character_logged_in(character_id: StringName, logged_in: bool) -> Error:
	if _registry == null:
		return FAILED
	var data: Resource = _registry.get_character(character_id)
	if data == null:
		return ERR_DOES_NOT_EXIST
	data.is_logged_in = logged_in
	return OK
