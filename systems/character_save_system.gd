class_name CharacterSaveSystem
extends Node

const CharacterDataScr := preload("res://systems/character_data.gd")

const SAVE_VERSION: int = 4

signal save_completed(path: String)
signal load_completed(path: String)


func save_registry(
	path: String,
	registry: Node,
	inventory: Node = null,
	equipment: Node = null,
	item_instances: Node = null,
) -> Error:
	var list: Array = []
	for id in registry.list_character_ids():
		var cd: Resource = registry.get_character(id)
		if cd != null:
			list.append(cd.to_dictionary())
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"characters": list,
	}
	if inventory != null and inventory.has_method("export_state"):
		payload["inventory"] = inventory.export_state()
	if equipment != null and equipment.has_method("export_state"):
		payload["equipment"] = equipment.export_state()
	if item_instances != null and item_instances.has_method("export_state"):
		payload["item_instances"] = item_instances.export_state()
	var json_text: String = JSON.stringify(payload, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.close()
	save_completed.emit(path)
	return OK


func load_registry(
	path: String,
	registry: Node,
	inventory: Node = null,
	equipment: Node = null,
	item_instances: Node = null,
) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var root: Dictionary = parsed as Dictionary
	if int(root.get("version", 0)) > SAVE_VERSION:
		return ERR_UNAVAILABLE
	registry.clear()
	var arr: Array = root.get("characters", []) as Array
	for entry in arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var cd: Resource = CharacterDataScr.from_dictionary(entry as Dictionary)
		var err: Error = registry.register_character(cd)
		if err != OK:
			return err
	var ver: int = int(root.get("version", 1))
	if ver >= 2:
		if item_instances != null and root.has("item_instances") and item_instances.has_method("import_state"):
			item_instances.import_state(root["item_instances"] as Dictionary)
		if inventory != null and root.has("inventory") and inventory.has_method("import_state"):
			inventory.import_state(root["inventory"] as Dictionary)
		if equipment != null and root.has("equipment") and equipment.has_method("import_state"):
			equipment.import_state(root["equipment"] as Dictionary)
	load_completed.emit(path)
	return OK
