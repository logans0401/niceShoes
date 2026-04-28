extends Label
## Queue row index for drag payload; set before the row is shown.
var row_index: int = 0


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	set_drag_preview(preview)
	return {"automation_queue_drag": true, "from_index": row_index}
