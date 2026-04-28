extends PanelContainer
## Panel B: square portrait, + button for empty slots only, mini H/S/M bars (stacked column).

signal pressed_card(slot_index: int)
signal pressed_add(slot_index: int)
signal context_menu_requested(slot_index: int, at_global_position: Vector2)

@export var slot_index: int = 0

@onready var _margin: MarginContainer = $Margin
@onready var _vbox: VBoxContainer = $Margin/VBox
@onready var _portrait_frame: Control = $Margin/VBox/PortraitFrame
@onready var _portrait: ColorRect = %Portrait
@onready var _btn_add: Button = %BtnAdd
@onready var _name_label: Label = %NameLabel
@onready var _bars_column: VBoxContainer = $Margin/VBox/BarsColumn
@onready var _bar_health: ProgressBar = %BarHealth
@onready var _bar_stamina: ProgressBar = %BarStamina
@onready var _bar_mana: ProgressBar = %BarMana

var _filled: bool = false
var _character_id: StringName = &""
var _base_panel_style: StyleBoxFlat


func _ready() -> void:
	var p: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if p != null:
		_base_panel_style = p.duplicate() as StyleBoxFlat
	gui_input.connect(_on_gui_input)
	_btn_add.pressed.connect(_on_add_pressed)


func _on_add_pressed() -> void:
	if _filled:
		return
	pressed_add.emit(slot_index)


func _on_gui_input(event: InputEvent) -> void:
	if not _filled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed_card.emit(slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			context_menu_requested.emit(slot_index, event.global_position)


func _apply_empty_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_add.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [_bar_health, _bar_stamina, _bar_mana]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_filled_mouse_filters() -> void:
	## Let the card root receive all clicks so selection always works (children do not steal input).
	mouse_filter = Control.MOUSE_FILTER_STOP
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_add.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [_bar_health, _bar_stamina, _bar_mana]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear_slot() -> void:
	_filled = false
	_character_id = &""
	_btn_add.visible = true
	_name_label.text = ""
	_portrait.modulate = Color(1, 1, 1, 1)
	_portrait.color = Color(0.18, 0.2, 0.24, 1.0)
	for b in [_bar_health, _bar_stamina, _bar_mana]:
		b.max_value = 1.0
		b.value = 0.0
	_apply_empty_mouse_filters()


func bind_character(
	character_id: StringName,
	display_name: String,
	hp: float,
	hp_max: float,
	st: float,
	st_max: float,
	mn: float,
	mn_max: float,
	portrait_color: Color,
	logged_in: bool = true,
) -> void:
	_filled = true
	_character_id = character_id
	_btn_add.visible = false
	_name_label.text = display_name
	_portrait.color = portrait_color
	if logged_in:
		_portrait.modulate = Color(1, 1, 1, 1)
	else:
		_portrait.modulate = Color(0.55, 0.58, 0.64, 1)
	_bar_health.max_value = maxf(hp_max, 1.0)
	_bar_health.value = clampf(hp, 0.0, _bar_health.max_value)
	_bar_stamina.max_value = maxf(st_max, 1.0)
	_bar_stamina.value = clampf(st, 0.0, _bar_stamina.max_value)
	_bar_mana.max_value = maxf(mn_max, 1.0)
	_bar_mana.value = clampf(mn, 0.0, _bar_mana.max_value)
	_apply_filled_mouse_filters()


func get_character_id() -> StringName:
	return _character_id


func is_filled() -> bool:
	return _filled


## Final tint shown on the card (portrait base × modulate); matches in-world glyph for testing.
func get_display_portrait_color() -> Color:
	return _portrait.color * _portrait.modulate


func set_selected(selected: bool) -> void:
	if _base_panel_style == null:
		return
	var sb: StyleBoxFlat = _base_panel_style.duplicate() as StyleBoxFlat
	if selected:
		sb.border_color = Color(0.85, 0.72, 0.35, 1.0)
		sb.set_border_width_all(2)
	else:
		sb.border_color = Color(0.35, 0.38, 0.45, 1.0)
		sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)
