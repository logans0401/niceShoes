extends HBoxContainer
## Drop target for queue reordering (drag starts from the task label child).
var row_index: int = 0


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).get("automation_queue_drag", false) == true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data as Dictionary
	var from_i: int = int(d.get("from_index", -1))
	if from_i < 0:
		return
	var host: Node = get_parent()
	if host != null and host.has_signal("reorder_requested"):
		host.emit_signal("reorder_requested", from_i, row_index)
