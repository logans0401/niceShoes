extends MarginContainer

const _EqScr := preload("res://scripts/equipment_schema.gd")

signal slot_selection_changed(selection: Dictionary)
## Emitted after grids are built and `refresh()` runs (safe moment for shell follow-up wiring).
signal setup_completed
signal bag_slot_double_clicked(index: int)
## Right-click on a bag slot or equipment slot (global position for context menu).
signal slot_context_menu_requested(kind: String, payload: Dictionary, at_global: Vector2)

@onready var _burden_label: Label = %BurdenLabel
@onready var _equip_grid: GridContainer = %EquipGrid
@onready var _bag_grid: GridContainer = %BagGrid

var _registry: Node
var _inventory: Node
var _equipment: Node
var _catalog: Node
var _stats: Node
var _balance: Resource
var _inv_balance: Resource

var _char_id: StringName = &""
var _equip_buttons: Array = []
var _bag_buttons: Array = []
var _selected_slot: Dictionary = {"source": "none"}


func setup(
	registry: Node,
	inventory: Node,
	equipment: Node,
	catalog: Node,
	stats: Node,
	char_balance: Resource,
	inv_balance: Resource,
	character_id: StringName,
) -> void:
	_registry = registry
	_inventory = inventory
	_equipment = equipment
	_catalog = catalog
	_stats = stats
	_balance = char_balance
	_inv_balance = inv_balance
	_char_id = character_id
	if _inventory != null and not _inventory.inventory_changed.is_connected(_on_inv_changed):
		_inventory.inventory_changed.connect(_on_inv_changed)
	if _equipment != null and not _equipment.equipment_changed.is_connected(_on_eq_changed):
		_equipment.equipment_changed.connect(_on_eq_changed)
	_build_equipment_slots()
	_build_bag_slots()
	refresh()
	setup_completed.emit()


func switch_character(character_id: StringName) -> void:
	if _char_id == character_id:
		return
	_char_id = character_id
	_selected_slot = {"source": "none"}
	_apply_slot_highlight()
	slot_selection_changed.emit({"source": "none"})
	refresh()


## Sync highlight + shell selection (e.g. right-click context menu) without a synthetic click.
func set_programmatic_selection(sel: Dictionary) -> void:
	_emit_inv_selection(sel.duplicate())


func _on_inv_changed(cid: StringName) -> void:
	if cid == _char_id:
		refresh()


func _on_eq_changed(cid: StringName) -> void:
	if cid == _char_id:
		refresh()


func _emit_inv_selection(sel: Dictionary) -> void:
	_selected_slot = sel.duplicate()
	_apply_slot_highlight()
	slot_selection_changed.emit(sel.duplicate())


func _apply_slot_highlight() -> void:
	var sel_col := Color(1.14, 1.1, 0.96)
	for b in _bag_buttons:
		if b is Control:
			(b as Control).modulate = Color.WHITE
	for b in _equip_buttons:
		if b is Control:
			(b as Control).modulate = Color.WHITE
	var src: String = String(_selected_slot.get("source", "none"))
	if src == "bag":
		var ix: int = int(_selected_slot.get("index", -1))
		if ix >= 0 and ix < _bag_buttons.size():
			(_bag_buttons[ix] as Control).modulate = sel_col
	elif src == "equip":
		var want: String = String(_selected_slot.get("equip_slot", ""))
		var idx: int = 0
		for sl in _EqScr.ALL_SLOTS:
			if String(sl) == want:
				if idx < _equip_buttons.size():
					(_equip_buttons[idx] as Control).modulate = sel_col
				break
			idx += 1


func _build_equipment_slots() -> void:
	if _equip_grid == null:
		push_error("InventoryEquipmentPanel: EquipGrid not ready — setup() must run after the panel's _ready().")
		return
	for c in _equip_grid.get_children():
		c.queue_free()
	_equip_buttons.clear()
	for slot in _EqScr.ALL_SLOTS:
		var row := HBoxContainer.new()
		var cap := Label.new()
		cap.text = String(slot).substr(0, 10)
		cap.custom_minimum_size = Vector2(72, 0)
		var btn := Button.new()
		btn.text = "—"
		btn.gui_input.connect(_on_equip_gui_input.bind(slot, btn))
		row.add_child(cap)
		row.add_child(btn)
		_equip_grid.add_child(row)
		_equip_buttons.append(btn)


func _build_bag_slots() -> void:
	if _bag_grid == null:
		push_error("InventoryEquipmentPanel: BagGrid not ready — setup() must run after the panel's _ready().")
		return
	for c in _bag_grid.get_children():
		c.queue_free()
	_bag_buttons.clear()
	var n: int = 24
	if _inventory != null:
		n = _inventory.get_bag_slot_count()
	_bag_grid.columns = 4
	for i in range(n):
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 28)
		b.text = str(i)
		b.gui_input.connect(_on_bag_gui_input.bind(i, b))
		_bag_grid.add_child(b)
		_bag_buttons.append(b)


func refresh() -> void:
	if _registry == null or _inventory == null or _equipment == null:
		return
	var data: Resource = _registry.get_character(_char_id)
	if data == null:
		if _burden_label != null:
			_burden_label.text = "Create a character (Party +) to manage inventory."
		return
	var eq: Node = _equipment
	var st: Dictionary = _stats.get_effective_stats(_char_id, data, eq)
	_burden_label.text = "Currency: %d  |  Burden: %.1f / %.1f  (ratio %.2f)" % [
		int(data.gold),
		float(data.laden_burden),
		float(st.get("burden_capacity", 1.0)),
		float(st.get("burden_ratio", 0.0)),
	]
	var bag: Array = _inventory.get_bag_copy(_char_id)
	for i in range(_bag_buttons.size()):
		var btn: Button = _bag_buttons[i] as Button
		if i >= bag.size():
			btn.text = "."
			continue
		var cell: Variant = bag[i]
		if cell == null:
			btn.text = "·"
		else:
			var d: Dictionary = cell as Dictionary
			var nid: String = String(_cell_item_id(d))
			btn.text = nid.substr(0, 3) + str(int(d.get("quantity", 1)))
	var idx: int = 0
	for slot in _EqScr.ALL_SLOTS:
		if idx >= _equip_buttons.size():
			break
		var ebtn: Button = _equip_buttons[idx] as Button
		var iid: StringName = _equipment.get_equipped_item(_char_id, StringName(slot))
		ebtn.text = String(iid).substr(0, 8) if String(iid) != "" else "—"
		idx += 1
	_apply_slot_highlight()


func _on_equip_gui_input(event: InputEvent, slot: String, btn: Button) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			slot_context_menu_requested.emit("equip", {"equip_slot": slot}, mb.global_position)
			btn.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if Input.is_key_pressed(KEY_SHIFT):
				_unequip_slot(slot)
			else:
				_select_equip_slot(slot)
			btn.accept_event()


func _on_bag_gui_input(event: InputEvent, index: int, btn: Button) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			slot_context_menu_requested.emit("bag", {"index": index}, mb.global_position)
			btn.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if mb.double_click:
				bag_slot_double_clicked.emit(index)
				btn.accept_event()
				return
			if Input.is_key_pressed(KEY_SHIFT):
				_try_equip_from_bag(index)
			else:
				_select_bag_slot(index)
			btn.accept_event()


func _select_equip_slot(slot: String) -> void:
	if _equipment == null:
		return
	var sid: StringName = StringName(slot)
	var iid: String = String(_equipment.get_equipped_item(_char_id, sid))
	var key: String = String(_equipment.call("get_equipped_key", _char_id, sid)) if _equipment.has_method("get_equipped_key") else iid
	_emit_inv_selection({"source": "equip", "equip_slot": slot, "item_id": iid, "instance_id": key, "quantity": 1})


func _select_bag_slot(index: int) -> void:
	var iid: String = ""
	var qty: int = 0
	if _inventory != null:
		var cell: Variant = _inventory.get_cell(_char_id, index)
		if cell is Dictionary:
			var d: Dictionary = cell as Dictionary
			iid = String(_cell_item_id(d))
			qty = int(d.get("quantity", 1))
			var inst_id: String = String(d.get("instance_id", ""))
			_emit_inv_selection({"source": "bag", "index": index, "item_id": iid, "instance_id": inst_id, "quantity": qty})
			return
	_emit_inv_selection({"source": "bag", "index": index, "item_id": iid, "instance_id": "", "quantity": qty})


func _unequip_slot(slot: String) -> void:
	if _equipment == null:
		return
	var sid: StringName = StringName(slot)
	if String(_equipment.get_equipped_item(_char_id, sid)) != "":
		_equipment.unequip_to_bag(_char_id, sid)
	refresh()


func _try_equip_from_bag(index: int) -> void:
	if _equipment == null or _inventory == null:
		return
	var cell: Variant = _inventory.get_cell(_char_id, index)
	if cell == null:
		return
	var d: Dictionary = cell as Dictionary
	var iid: StringName = _cell_item_id(d)
	var def: Resource = _catalog.get_definition(iid)
	if def == null:
		return
	var es: String = String(def.equip_slot)
	if es.is_empty():
		return
	_equipment.equip_from_bag(_char_id, StringName(es), index)
	refresh()


func _cell_item_id(cell: Dictionary) -> StringName:
	if _inventory != null and _inventory.has_method("_cell_item_id"):
		return _inventory.call("_cell_item_id", cell) as StringName
	var raw: Variant = cell.get("item_id", &"")
	return raw as StringName if raw is StringName else StringName(str(raw))
