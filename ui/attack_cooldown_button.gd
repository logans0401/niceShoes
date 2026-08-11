extends Button
class_name AttackCooldownButton
## Button with a left-to-right cooldown fill (1.0 = ready / strike moment).

const FILL_ATTACK := Color(0.62, 0.22, 0.24, 0.78)
const FILL_CAST := Color(0.22, 0.42, 0.78, 0.78)
## Reserved for future crafting actions on this control.
const FILL_CRAFT := Color(0.78, 0.62, 0.18, 0.72)

var _fill_ratio: float = 0.0
var _fill: ColorRect = null


func _ready() -> void:
	clip_contents = true
	_fill = ColorRect.new()
	_fill.name = "CooldownFill"
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = FILL_ATTACK
	add_child(_fill)
	move_child(_fill, 0)
	resized.connect(_sync_fill_geometry)
	_sync_fill_geometry()


func set_fill_color(col: Color) -> void:
	if _fill != null:
		_fill.color = col


func set_cooldown_ratio(ratio: float) -> void:
	_fill_ratio = clampf(ratio, 0.0, 1.0)
	_sync_fill_geometry()


func _sync_fill_geometry() -> void:
	if _fill == null:
		return
	var w: float = maxf(0.0, size.x * _fill_ratio)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(w, size.y)
