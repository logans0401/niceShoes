class_name MapTransitionSystem
extends Node

signal transition_requested(from_map: StringName, to_map: StringName, portal_id: StringName)
signal transition_finished(map_id: StringName)


func request_transition(from_map: StringName, to_map: StringName, portal_id: StringName = &"") -> void:
	transition_requested.emit(from_map, to_map, portal_id)


func notify_loaded(map_id: StringName) -> void:
	transition_finished.emit(map_id)
