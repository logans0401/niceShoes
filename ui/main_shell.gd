extends Control

const CharacterCardScene := preload("res://ui/character_card.tscn")
const WorldActorScene := preload("res://maps/world_actor.tscn")
const CharacterDataScr := preload("res://systems/character_data.gd")
const _CombatTestEnemyScr: Script = preload("res://scripts/combat_test_enemy.gd")
const _Sch := preload("res://scripts/character_schema.gd")
const _MAX_PARTY_CARDS := 4
const _COMMAND_FEED_MAX_LINES := 80
const _MELEE_RANGE_PX := 56.0
const _AUTO_GROUP_PREFIX := "group:"
const _OPTION_POPUP_MIN_HEIGHT_PX := 100
const _AutomationQueueRowScr: Script = preload("res://ui/automation_queue_row.gd")
const _AutomationQueueTaskLabelScr: Script = preload("res://ui/automation_queue_task_label.gd")
const _MISSILE_RANGE_PX := 190.0
const _SPELL_CAST_RANGE_PX := 200.0
const _NO_TARGET_RETRY_MS := 1000
const _SEL_CTX_INSPECT := 1
const _SEL_CTX_EQUIP := 2
const _SEL_CTX_UNEQUIP := 3
const _SEL_CTX_READ_SCROLL := 4
const _SEL_CTX_ATTACK_CAST := 5
const _SEL_CTX_MEDITATE := 6

@onready var _world_viewport: SubViewport = %WorldViewport
@onready var _world_viewport_container: SubViewportContainer = %WorldViewportContainer
@onready var _hud_health: ProgressBar = %HudHealth
@onready var _hud_health_value: Label = %HudHealthValue
@onready var _hud_stamina: ProgressBar = %HudStamina
@onready var _hud_stamina_value: Label = %HudStaminaValue
@onready var _hud_mana: ProgressBar = %HudMana
@onready var _hud_mana_value: Label = %HudManaValue
@onready var _hud_zone: Label = %HudZoneLabel
@onready var _group_selector: OptionButton = %GroupSelector
@onready var _btn_group_manage: Button = %BtnGroupManage
@onready var _btn_tab_inventory: Button = %BtnTabInventory
@onready var _btn_tab_attributes: Button = %BtnTabAttributes
@onready var _btn_tab_skills: Button = %BtnTabSkills
@onready var _btn_tab_quests: Button = %BtnTabQuests
@onready var _btn_tab_automation: Button = %BtnTabAutomation
@onready var _panel_d_context_title: Label = %PanelDContextTitle
@onready var _d_inventory_host: Control = %PanelDInventoryHost
@onready var _d_attributes_host: Control = %PanelDAttributesHost
@onready var _d_skills_host: Control = %PanelDSkillsHost
@onready var _d_quest_host: Control = %PanelDQuestHost
@onready var _d_automation_host: Control = %PanelDAutomationHost
@onready var _automation_status: Label = %AutomationStatus
@onready var _automation_runner_select: OptionButton = %AutomationRunnerSelect
@onready var _automation_active: RichTextLabel = %AutomationActive
@onready var _automation_queue_host: VBoxContainer = %AutomationQueueHost
@onready var _automation_previous: ItemList = %AutomationPrevious
@onready var _automation_status_log: ItemList = %AutomationStatusLog
@onready var _btn_interrupt: Button = %BtnInterrupt
@onready var _btn_resume: Button = %BtnResume
@onready var _command_feed: RichTextLabel = %CommandFeed
@onready var _combat_feed: RichTextLabel = %CombatFeed
@onready var _cards_hbox: HBoxContainer = %CharacterCardsHBox
@onready var _quest_list: ItemList = %QuestPlaceholderList
@onready var _quest_description: RichTextLabel = %QuestDescription
@onready var _btn_quest_abandon: Button = %BtnQuestAbandon
@onready var _btn_log_in: Button = %BtnLogIn
@onready var _btn_log_out: Button = %BtnLogOut
@onready var _btn_new_group: Button = %BtnNewGroup
@onready var _btn_cycle_group_up: Button = %BtnCycleGroupUp
@onready var _btn_cycle_group_down: Button = %BtnCycleGroupDown
@onready var _bb_portrait: TextureRect = %PanelBBPortrait
@onready var _bb_fallback: ColorRect = %PanelBBFallback
@onready var _bb_title: Label = %PanelBBTitle
@onready var _bb_subtitle: Label = %PanelBBSubtitle
@onready var _bb_btn_equip: Button = %BtnBBEquip
@onready var _bb_btn_read_scroll: Button = %BtnBBReadScroll
@onready var _bb_vitals: VBoxContainer = %PanelBBVitals
@onready var _bb_bar_hp: ProgressBar = %PanelBBBarHealth
@onready var _bb_bar_st: ProgressBar = %PanelBBBarStamina
@onready var _bb_bar_mn: ProgressBar = %PanelBBBarMana
@onready var _btn_bc_meditate: Button = %BtnBCMeditate
@onready var _bc_btn_attack: Button = %BtnBCAttack
@onready var _bc_btn_inspect: Button = %BtnBCInspect
@onready var _lbl_bd_selected: Label = %LblBDSelectedSpell
@onready var _spells_list_host: VBoxContainer = %SpellsListHost

var _automation: AutomationSystem
var _progression: Node
var _balance: Resource
var _registry: Node
var _group_system: Node
var _stats: Node
var _equipment: Node
var _inventory: Node
var _catalog: Node = null
var _current_runner_id: StringName = &"default"
var _inventory_panel: Node
var _party_cards: Array = []
var _selected_card_slot: int = 0
var _focus_character_id: StringName = &""
## character_id -> feed buffer (lines + repeat dedupe). Command vs combat are separate tabs per character.
var _feed_command_by_character: Dictionary = {}
var _feed_combat_by_character: Dictionary = {}
var _boot_combat_hint_logged: bool = false
## Logged-in characters: seconds accumulated toward next passive mana point.
var _passive_mana_elapsed: Dictionary = {}
## Must fit shell Button styleboxes (content margins + font); same for enabled and disabled so row height never jumps.
const _PROGRESSION_ROW_MIN_HEIGHT_PX := 42
const _PROGRESSION_RAISE_BTN_MIN_HEIGHT_PX := 32
var _tab_button_group: ButtonGroup = ButtonGroup.new()
var _tab_index: int = 0
const _AUTOMATION_PANEL_REVISION: int = 3
var _automation_tab_built_revision: int = 0
var _opt_follow_target: OptionButton = null
var _opt_automation_task: OptionButton = null
var _chk_automation_queue_hold: CheckBox = null
var _lbl_automation_context: Label = null
var _automation_follow_block: Control = null

## Duplicated from the shell theme so OptionButton popups can override internal ScrollContainer without affecting layout height.
var _option_popup_theme: Theme
var _quest: QuestSystem
var _combat: CombatSystem = null
var _actors_root: Node2D = null
## character_id -> CharacterBody2D (world presence)
var _world_actor_by_id: Dictionary = {}
var _creation_dialog: AcceptDialog = null
var _creation_name_edit: LineEdit = null
var _creation_points_label: Label = null
var _creation_sliders_by_attr: Dictionary = {}
var _creation_value_labels_by_attr: Dictionary = {}
var _creation_minus_buttons_by_attr: Dictionary = {}
var _creation_plus_buttons_by_attr: Dictionary = {}
var _creation_alloc: Dictionary = {}
var _creation_weapon_select: OptionButton = null
var _group_signals_connected: bool = false
var _card_context_menu: PopupMenu = null
var _context_menu_slot: int = -1
var _selection_actions_popup: PopupMenu = null
var _rename_dialog: AcceptDialog = null
var _rename_edit: LineEdit = null
var _rename_target_id: StringName = &""
## Latest world pick (Panel A): "none" | "actor" | "enemy"
var _selection_world_kind: String = "none"
var _selection_world_id: StringName = &""
var _selection_world_node: Node = null
## Panel A vs Panel D: last explicit pick wins for Panel B.b portrait.
var _selection_portrait_source: String = "none"
var _selection_inventory_snapshot: Dictionary = {}
## Panel B.c: directed attack/cast on selected enemy (focus character approaches).
var _ui_attack_active: bool = false
var _ui_attack_enemy_iid: int = 0
var _ui_attack_last_strike_ms: int = 0
var _spell_cast_busy: bool = false
var _spell_cast_elapsed_ms: float = 0.0
var _spell_cast_duration_ms: float = 0.0
var _spell_cast_target_iid: int = 0
var _spell_cast_attacker_id: StringName = &""
var _spell_cast_ctx: Dictionary = {}
## character_id -> Time.get_ticks_msec() when next "no target" search may run (any attack mode).
var _attack_no_target_not_before_ms: Dictionary = {}
## character_id -> spell id string (casting selection).
var _bd_spell_selection_by_character: Dictionary = {}
var _inspect_dialog: AcceptDialog = null
var _inspect_body: RichTextLabel = null


func _ready() -> void:
	_apply_shell_theme()
	_mount_world()
	_setup_hud_placeholders()
	_setup_tab_buttons()
	_spawn_party_cards()
	_connect_quest_panel_widgets()
	_connect_group_controls()
	_connect_automation_panel_widgets()
	_connect_character_bar_widgets()
	_apply_tab_index(0, false)
	_refresh_automation_status()
	_hud_zone.text = "Zone: placeholder"
	if _world_viewport_container != null:
		_world_viewport_container.gui_input.connect(_on_world_viewport_container_gui_input)
	if _bb_btn_equip != null:
		_bb_btn_equip.pressed.connect(_on_bb_equip_pressed)
	if _bb_btn_read_scroll != null:
		_bb_btn_read_scroll.pressed.connect(_on_bb_read_scroll_pressed)
	if _bc_btn_attack != null:
		_bc_btn_attack.pressed.connect(_on_bc_attack_pressed)
	if _bc_btn_inspect != null:
		_bc_btn_inspect.pressed.connect(_on_bc_inspect_pressed)
	if _btn_bc_meditate != null:
		_btn_bc_meditate.pressed.connect(_on_bc_meditate_pressed)
	_refresh_selection_portrait()


func _physics_process(delta: float) -> void:
	if _automation != null:
		_automation.tick(delta)
	_apply_follow_movement(delta)
	_tick_player_spell_cast(delta)
	_tick_ui_directed_attack(delta)
	_tick_hostile_enemies(delta)
	_tick_passive_mana_regen(delta)
	_refresh_bc_meditate_button_label()
	_refresh_hud_vitals()


func _option_button_clear_all(ob: OptionButton) -> void:
	while ob.item_count > 0:
		ob.remove_item(ob.item_count - 1)


func _variant_group_id_matches(meta: Variant, gid: StringName) -> bool:
	if meta == null:
		return false
	return StringName(str(meta)) == StringName(str(gid))


func _sorted_group_ids_for_ui() -> Array[StringName]:
	if _group_system == null or not _group_system.has_method("list_group_ids"):
		return []
	var raw: PackedStringArray = _group_system.list_group_ids()
	var ids: Array[StringName] = []
	for g in raw:
		ids.append(StringName(g))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).nocasecmp_to(String(b)) < 0)
	return ids


func _wire_option_button_popup(btn: OptionButton) -> void:
	if btn == null:
		return
	var popup: PopupMenu = btn.get_popup()
	if popup.get_signal_connection_list(&"about_to_popup").size() > 0:
		return
	popup.about_to_popup.connect(_on_option_button_popup_about_to_popup.bind(btn))


func _on_option_button_popup_about_to_popup(btn: OptionButton) -> void:
	## Layout + item metrics are not always final in about_to_popup; size on the next frame.
	call_deferred(&"_deferred_size_option_popup", btn)


func _deferred_size_option_popup(btn: OptionButton) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var popup: PopupMenu = btn.get_popup()
	if popup == null or not is_instance_valid(popup):
		return
	var btn_w: int = maxi(int(btn.get_rect().size.x), 160)
	var need: Vector2 = popup.get_contents_minimum_size()
	var fs: int = popup.get_theme_font_size(&"font_size", &"PopupMenu")
	var per_line: int = maxi(22, fs + 8)
	var from_count: int = per_line * maxi(1, popup.item_count) + 16
	var h: int = maxi(maxi(_OPTION_POPUP_MIN_HEIGHT_PX, int(ceilf(need.y))), from_count)
	var w: int = maxi(btn_w, int(ceilf(need.x)))
	popup.min_size = Vector2i(w, h)


func _ensure_focus_in_active_roster() -> void:
	if _group_system == null or _registry == null:
		_refresh_feed_labels()
		return
	var ids: PackedStringArray = _roster_ids()
	if ids.is_empty():
		if _focus_character_id != &"":
			_focus_character_id = &""
		_refresh_feed_labels()
		return
	var found: bool = false
	for cid in ids:
		if cid == _focus_character_id:
			found = true
			break
	if found:
		_refresh_feed_labels()
		return
	_focus_character_id = ids[0]
	if _inventory_panel != null and _inventory_panel.has_method("switch_character"):
		_inventory_panel.switch_character(_focus_character_id)
	_sync_runner_dropdown_to_id(_focus_character_id)
	_rebuild_progression_panels()
	_refresh_feed_labels()


func _build_option_popup_theme(shell_theme: Theme) -> Theme:
	## Native / detached popups (embed_subwindows=false) do not inherit the shell Control theme. A bare Theme.new()
	## leaves internal menu labels without fonts/colors, so rows render as empty. Seed from project/default, then patch.
	var theme_base: Theme = ThemeDB.get_project_theme()
	if theme_base == null:
		theme_base = ThemeDB.get_default_theme()
	var t: Theme
	if theme_base != null:
		t = theme_base.duplicate(true) as Theme
	else:
		t = Theme.new()
	var pan: StyleBox = shell_theme.get_stylebox(&"panel", &"PopupMenu")
	if pan != null:
		t.set_stylebox(&"panel", &"PopupMenu", pan.duplicate())
	var hov: StyleBox = shell_theme.get_stylebox(&"hover", &"PopupMenu")
	if hov != null:
		t.set_stylebox(&"hover", &"PopupMenu", hov.duplicate())
	for ckey: StringName in [&"font_color", &"font_hover_color", &"font_accelerator_color"]:
		if shell_theme.has_color(ckey, &"PopupMenu"):
			t.set_color(ckey, &"PopupMenu", shell_theme.get_color(ckey, &"PopupMenu"))
	if shell_theme.has_font(&"font", &"PopupMenu"):
		t.set_font(&"font", &"PopupMenu", shell_theme.get_font(&"font", &"PopupMenu"))
	elif ThemeDB.fallback_font != null:
		t.set_font(&"font", &"PopupMenu", ThemeDB.fallback_font)
	if shell_theme.has_font_size(&"font_size", &"PopupMenu"):
		t.set_font_size(&"font_size", &"PopupMenu", shell_theme.get_font_size(&"font_size", &"PopupMenu"))
	else:
		t.set_font_size(&"font_size", &"PopupMenu", 14)
	t.set_constant(&"outline_size", &"PopupMenu", 0)
	for ckey2: StringName in [&"h_separation", &"v_separation"]:
		if shell_theme.has_constant(ckey2, &"PopupMenu"):
			t.set_constant(ckey2, &"PopupMenu", shell_theme.get_constant(ckey2, &"PopupMenu"))
	var sc_clear := StyleBoxFlat.new()
	sc_clear.bg_color = Color(0, 0, 0, 0)
	sc_clear.set_border_width_all(0)
	t.set_stylebox(&"panel", &"ScrollContainer", sc_clear)
	t.set_stylebox(&"focus", &"ScrollContainer", sc_clear)
	## Menu item sub-controls still resolve "Label" in some builds — mirror shell readability.
	if shell_theme.has_color(&"font_color", &"Label"):
		t.set_color(&"font_color", &"Label", shell_theme.get_color(&"font_color", &"Label"))
	if shell_theme.has_font_size(&"font_size", &"Label"):
		t.set_font_size(&"font_size", &"Label", shell_theme.get_font_size(&"font_size", &"Label"))
	if shell_theme.has_font(&"font", &"Label"):
		t.set_font(&"font", &"Label", shell_theme.get_font(&"font", &"Label"))
	elif ThemeDB.fallback_font != null:
		t.set_font(&"font", &"Label", ThemeDB.fallback_font)
	return t


func _apply_shell_theme() -> void:
	var edge := Color(0.22, 0.24, 0.29, 1.0)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.11, 0.12, 0.15, 1.0)
	panel.set_border_width_all(1)
	panel.border_color = edge
	panel.corner_radius_top_left = 6
	panel.corner_radius_top_right = 6
	panel.corner_radius_bottom_right = 6
	panel.corner_radius_bottom_left = 6
	panel.content_margin_left = 10
	panel.content_margin_top = 10
	panel.content_margin_right = 10
	panel.content_margin_bottom = 10
	var tab_focus := panel.duplicate() as StyleBoxFlat
	tab_focus.border_color = Color(0.55, 0.5, 0.38, 1.0)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.14, 0.15, 0.18, 1.0)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_bg.corner_radius_bottom_left = 4
	var fill_hp := StyleBoxFlat.new()
	fill_hp.bg_color = Color(0.62, 0.22, 0.24, 1.0)
	fill_hp.corner_radius_top_left = 4
	fill_hp.corner_radius_top_right = 4
	fill_hp.corner_radius_bottom_right = 4
	fill_hp.corner_radius_bottom_left = 4
	var fill_st := StyleBoxFlat.new()
	fill_st.bg_color = Color(0.78, 0.62, 0.18, 1.0)
	fill_st.corner_radius_top_left = 4
	fill_st.corner_radius_top_right = 4
	fill_st.corner_radius_bottom_right = 4
	fill_st.corner_radius_bottom_left = 4
	var fill_mn := StyleBoxFlat.new()
	fill_mn.bg_color = Color(0.22, 0.42, 0.78, 1.0)
	fill_mn.corner_radius_top_left = 4
	fill_mn.corner_radius_top_right = 4
	fill_mn.corner_radius_bottom_right = 4
	fill_mn.corner_radius_bottom_left = 4
	var shell_theme := Theme.new()
	shell_theme.set_stylebox("panel", "PanelContainer", panel)
	var btn_normal: StyleBoxFlat = panel.duplicate() as StyleBoxFlat
	shell_theme.set_stylebox("normal", "Button", btn_normal)
	shell_theme.set_stylebox("hover", "Button", tab_focus)
	shell_theme.set_stylebox("pressed", "Button", panel.duplicate() as StyleBoxFlat)
	## Without these, disabled (and focus) fall back to the default theme — different margins vs `normal`, so row heights jump.
	var btn_disabled: StyleBoxFlat = btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.1, 0.11, 0.135, 1.0)
	shell_theme.set_stylebox("disabled", "Button", btn_disabled)
	var btn_focus: StyleBoxFlat = btn_normal.duplicate() as StyleBoxFlat
	btn_focus.border_color = Color(0.55, 0.5, 0.38, 0.75)
	shell_theme.set_stylebox("focus", "Button", btn_focus)
	shell_theme.set_color("font_disabled_color", "Button", Color(0.52, 0.54, 0.58, 1.0))
	shell_theme.set_stylebox("background", "ProgressBar", bar_bg)
	shell_theme.set_stylebox("fill", "ProgressBar", fill_hp)
	shell_theme.set_color("font_color", "Label", Color(0.9, 0.91, 0.93, 1.0))
	shell_theme.set_color("font_color", "Button", Color(0.92, 0.93, 0.95, 1.0))
	shell_theme.set_font_size("font_size", "Button", 12)
	## OptionButton lists use PopupMenu; without explicit styles the popup can be unreadable or clipped when embedded.
	var ob_txt := Color(0.92, 0.93, 0.95, 1.0)
	shell_theme.set_color("font_color", "OptionButton", ob_txt)
	shell_theme.set_color("font_hover_color", "OptionButton", ob_txt)
	shell_theme.set_color("font_pressed_color", "OptionButton", ob_txt)
	shell_theme.set_color("font_focus_color", "OptionButton", ob_txt)
	shell_theme.set_color("font_disabled_color", "OptionButton", Color(0.92, 0.93, 0.95, 0.45))
	shell_theme.set_font_size("font_size", "OptionButton", 12)
	shell_theme.set_constant("modulate_arrow", "OptionButton", 1)
	var pop_bg := StyleBoxFlat.new()
	pop_bg.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	pop_bg.set_border_width_all(1)
	pop_bg.border_color = edge
	pop_bg.corner_radius_top_left = 4
	pop_bg.corner_radius_top_right = 4
	pop_bg.corner_radius_bottom_right = 4
	pop_bg.corner_radius_bottom_left = 4
	var pop_hover := pop_bg.duplicate() as StyleBoxFlat
	pop_hover.bg_color = Color(0.2, 0.22, 0.28, 1.0)
	shell_theme.set_stylebox("panel", "PopupMenu", pop_bg)
	shell_theme.set_stylebox("hover", "PopupMenu", pop_hover)
	shell_theme.set_color("font_color", "PopupMenu", Color(0.92, 0.93, 0.95, 1.0))
	shell_theme.set_color("font_hover_color", "PopupMenu", Color(1.0, 1.0, 1.0, 1.0))
	shell_theme.set_color("font_accelerator_color", "PopupMenu", Color(0.65, 0.67, 0.72, 1.0))
	shell_theme.set_font_size("font_size", "PopupMenu", 12)
	shell_theme.set_constant("h_separation", "PopupMenu", 6)
	shell_theme.set_constant("v_separation", "PopupMenu", 2)
	var fallback_font: Font = ThemeDB.fallback_font
	if fallback_font != null:
		shell_theme.set_font(&"font", &"PopupMenu", fallback_font)
		shell_theme.set_font(&"font", &"OptionButton", fallback_font)
	self.theme = shell_theme
	_option_popup_theme = _build_option_popup_theme(shell_theme)
	if _group_selector != null:
		_group_selector.get_popup().theme = _option_popup_theme
		_wire_option_button_popup(_group_selector)
	if _automation_runner_select != null:
		_automation_runner_select.get_popup().theme = _option_popup_theme
		_wire_option_button_popup(_automation_runner_select)
	if _opt_follow_target != null:
		_opt_follow_target.get_popup().theme = _option_popup_theme
		_wire_option_button_popup(_opt_follow_target)
	_hud_health.add_theme_stylebox_override("fill", fill_hp)
	_hud_stamina.add_theme_stylebox_override("fill", fill_st)
	_hud_mana.add_theme_stylebox_override("fill", fill_mn)
	if _bb_bar_hp != null:
		_bb_bar_hp.add_theme_stylebox_override("fill", fill_hp.duplicate() as StyleBoxFlat)
	if _bb_bar_st != null:
		_bb_bar_st.add_theme_stylebox_override("fill", fill_st.duplicate() as StyleBoxFlat)
	if _bb_bar_mn != null:
		_bb_bar_mn.add_theme_stylebox_override("fill", fill_mn.duplicate() as StyleBoxFlat)


func _setup_tab_buttons() -> void:
	_btn_tab_inventory.button_group = _tab_button_group
	_btn_tab_attributes.button_group = _tab_button_group
	_btn_tab_skills.button_group = _tab_button_group
	_btn_tab_quests.button_group = _tab_button_group
	_btn_tab_automation.button_group = _tab_button_group
	_btn_tab_inventory.toggled.connect(func(p: bool): if p: _apply_tab_index(0, true))
	_btn_tab_attributes.toggled.connect(func(p: bool): if p: _apply_tab_index(1, true))
	_btn_tab_skills.toggled.connect(func(p: bool): if p: _apply_tab_index(2, true))
	_btn_tab_quests.toggled.connect(func(p: bool): if p: _apply_tab_index(3, true))
	_btn_tab_automation.toggled.connect(func(p: bool): if p: _apply_tab_index(4, true))


func _apply_tab_index(idx: int, _emit_feed: bool) -> void:
	_tab_index = idx
	_d_inventory_host.visible = idx == 0
	_d_attributes_host.visible = idx == 1
	_d_skills_host.visible = idx == 2
	_d_quest_host.visible = idx == 3
	_d_automation_host.visible = idx == 4
	match idx:
		0:
			_panel_d_context_title.text = "Inventory"
		1:
			_panel_d_context_title.text = "Attributes"
		2:
			_panel_d_context_title.text = "Skills"
		3:
			_panel_d_context_title.text = "Quest Log"
		4:
			_panel_d_context_title.text = "Automation"
		_:
			_panel_d_context_title.text = "—"
	if idx == 4:
		_ensure_automation_tab_controls()
		_refresh_follow_target_options()
	if idx == 3:
		_rebuild_quest_panel()


func _spawn_party_cards() -> void:
	for c in _cards_hbox.get_children():
		c.queue_free()
	_party_cards.clear()
	for i in range(_MAX_PARTY_CARDS):
		var card: Node = CharacterCardScene.instantiate()
		card.slot_index = i
		card.pressed_card.connect(_on_party_card_pressed)
		card.pressed_add.connect(_on_party_add_pressed)
		card.context_menu_requested.connect(_on_character_card_context_menu)
		_cards_hbox.add_child(card)
		_party_cards.append(card)
		if card.has_method("clear_slot"):
			card.clear_slot()
	if _party_cards.size() > 0:
		_party_cards[0].set_selected(true)


func _connect_quest_panel_widgets() -> void:
	_quest_list.item_selected.connect(_on_quest_list_item_selected)
	_btn_quest_abandon.pressed.connect(_on_quest_abandon_pressed)


func bind_quest_system(system: QuestSystem) -> void:
	if _quest != null and _quest.quest_state_changed.is_connected(_on_quest_state_changed):
		_quest.quest_state_changed.disconnect(_on_quest_state_changed)
	_quest = system
	if _quest != null:
		_quest.quest_state_changed.connect(_on_quest_state_changed)
	_rebuild_quest_panel()


func _on_quest_state_changed(_qid: StringName, _st: int) -> void:
	_rebuild_quest_panel()


func _rebuild_quest_panel() -> void:
	var prev_id: StringName = &""
	var sel: PackedInt32Array = _quest_list.get_selected_items()
	if not sel.is_empty():
		var meta: Variant = _quest_list.get_item_metadata(int(sel[0]))
		if meta is StringName:
			prev_id = meta
	_quest_list.clear()
	_quest_description.clear()
	_btn_quest_abandon.disabled = true
	if _quest == null:
		return
	var rows: Array = _quest.get_journal_rows_ordered()
	for row in rows:
		var d: Dictionary = row as Dictionary
		var qid: StringName = d["id"] as StringName
		var st: int = int(d["state"])
		var title: String = String(d["title"])
		var prefix: String = ""
		match st:
			QuestSystem.QuestState.ACTIVE:
				prefix = "[In progress] "
			QuestSystem.QuestState.COMPLETED:
				prefix = "[Completed] "
			QuestSystem.QuestState.FAILED:
				prefix = "[Failed] "
			_:
				prefix = ""
		var line: int = _quest_list.add_item(prefix + title)
		_quest_list.set_item_metadata(line, qid)
	if prev_id != &"":
		for i in range(_quest_list.item_count):
			if _quest_list.get_item_metadata(i) == prev_id:
				_quest_list.select(i)
				_on_quest_list_item_selected(i)
				break


func _on_quest_list_item_selected(index: int) -> void:
	if _quest == null:
		return
	var qid_var: Variant = _quest_list.get_item_metadata(index)
	if qid_var == null:
		return
	var qid: StringName = qid_var as StringName
	_quest_description.clear()
	_quest_description.add_text(_quest.get_quest_description(qid))
	var st: int = _quest.get_state(qid)
	_btn_quest_abandon.disabled = (st != QuestSystem.QuestState.ACTIVE)


func _on_quest_abandon_pressed() -> void:
	if _quest == null:
		return
	var sel: PackedInt32Array = _quest_list.get_selected_items()
	if sel.is_empty():
		return
	var qid_var: Variant = _quest_list.get_item_metadata(int(sel[0]))
	if qid_var == null:
		return
	_quest.abandon(qid_var as StringName)


func _connect_group_controls() -> void:
	_group_selector.item_selected.connect(_on_group_item_selected)
	_btn_group_manage.pressed.connect(_on_group_manage_pressed)
	_btn_new_group.pressed.connect(_on_new_group_pressed)
	_btn_cycle_group_up.pressed.connect(_cycle_active_group.bind(-1))
	_btn_cycle_group_down.pressed.connect(_cycle_active_group.bind(1))


func _connect_automation_panel_widgets() -> void:
	_automation_runner_select.item_selected.connect(_on_automation_runner_selected)
	if _automation_queue_host.has_signal("reorder_requested"):
		_automation_queue_host.reorder_requested.connect(_on_automation_queue_reorder)
	_btn_interrupt.pressed.connect(_on_automation_interrupt_pressed)
	_btn_resume.pressed.connect(_on_automation_resume_pressed)


func _connect_character_bar_widgets() -> void:
	_btn_log_in.pressed.connect(_on_log_in_pressed)
	_btn_log_out.pressed.connect(_on_log_out_pressed)
	_refresh_login_button_states()


func _refresh_login_button_states() -> void:
	if _focus_character_id == &"" or _registry == null:
		_btn_log_in.disabled = true
		_btn_log_out.disabled = true
		if _btn_bc_meditate != null:
			_btn_bc_meditate.disabled = true
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null:
		_btn_log_in.disabled = true
		_btn_log_out.disabled = true
		if _btn_bc_meditate != null:
			_btn_bc_meditate.disabled = true
		return
	_btn_log_in.disabled = bool(data.is_logged_in)
	_btn_log_out.disabled = not bool(data.is_logged_in)
	if _btn_bc_meditate != null:
		var wa: Node = _world_actor_by_id.get(_focus_character_id) as Node
		_btn_bc_meditate.disabled = not bool(data.is_logged_in) or wa == null
		if wa != null:
			_btn_bc_meditate.text = "Stop meditation" if bool(wa.is_meditating) else "Meditate"
		else:
			_btn_bc_meditate.text = "Meditate"


func _ensure_card_context_menu() -> void:
	if _card_context_menu != null:
		return
	_card_context_menu = PopupMenu.new()
	_card_context_menu.add_item("Name character…", 0)
	add_child(_card_context_menu)
	_card_context_menu.id_pressed.connect(_on_card_context_menu_id_pressed)


func _on_character_card_context_menu(slot_index: int, at_global_position: Vector2) -> void:
	_context_menu_slot = slot_index
	_ensure_card_context_menu()
	_card_context_menu.position = Vector2i(at_global_position)
	_card_context_menu.popup()


func _on_card_context_menu_id_pressed(menu_id: int) -> void:
	if menu_id != 0:
		return
	if _context_menu_slot < 0 or _context_menu_slot >= _party_cards.size():
		return
	var card: Node = _party_cards[_context_menu_slot]
	if card == null or not card.has_method("get_character_id"):
		return
	var cid: StringName = card.get_character_id()
	if cid == &"":
		return
	_show_rename_character_dialog(cid)


func _ensure_rename_dialog() -> void:
	if is_instance_valid(_rename_dialog):
		return
	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = "Name character"
	_rename_dialog.ok_button_text = "Save"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = "Display name"
	_rename_edit.custom_minimum_size = Vector2(320, 0)
	vb.add_child(_rename_edit)
	margin.add_child(vb)
	_rename_dialog.add_child(margin)
	add_child(_rename_dialog)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)


func _show_rename_character_dialog(character_id: StringName) -> void:
	_ensure_rename_dialog()
	if _registry == null or _rename_edit == null:
		return
	_rename_target_id = character_id
	var data: Resource = _registry.get_character(character_id)
	_rename_edit.text = str(data.user_name) if data != null else ""
	_rename_dialog.popup_centered()


func _on_rename_confirmed() -> void:
	if _registry == null or _rename_edit == null or _rename_target_id == &"":
		return
	var n: String = _rename_edit.text.strip_edges()
	if n.is_empty():
		return
	var data: Resource = _registry.get_character(_rename_target_id)
	if data == null:
		return
	var who: StringName = _rename_target_id
	data.user_name = n
	_rename_target_id = &""
	_refresh_party_cards()
	_sync_world_actor_colors_from_cards()
	_append_command_feed("[ui] Renamed to \"%s\"" % n, who)


func _on_new_group_pressed() -> void:
	if _group_system == null or not _group_system.has_method("create_new_group"):
		return
	var gid_variant: Variant = _group_system.create_new_group()
	var gid: StringName = &""
	if gid_variant is StringName:
		gid = gid_variant as StringName
	else:
		gid = StringName(str(gid_variant))
	_refresh_group_selector()
	_populate_runner_options()
	_refresh_follow_target_options()
	_refresh_party_cards()
	_append_command_feed(
		"[ui] New group: %s — still on \"%s\"; use Party, ↑↓, or the drop-down to switch."
		% [String(gid), String(_group_system.get_active_group_id())],
	)


func _on_log_in_pressed() -> void:
	if _group_system == null or _focus_character_id == &"" or _registry == null:
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null or bool(data.is_logged_in):
		return
	_group_system.try_set_character_logged_in(_focus_character_id, true)
	_refresh_party_cards()
	_sync_world_actors()
	_refresh_login_button_states()
	_refresh_panel_b_auxiliary()
	_append_command_feed("[ui] %s entered the world." % data.user_name)


func _on_log_out_pressed() -> void:
	if _group_system == null or _focus_character_id == &"" or _registry == null:
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null or not bool(data.is_logged_in):
		return
	_group_system.try_set_character_logged_in(_focus_character_id, false)
	_refresh_party_cards()
	_sync_world_actors()
	_refresh_login_button_states()
	_refresh_panel_b_auxiliary()
	_append_command_feed("[ui] %s left the world." % data.user_name)


func _roster_ids() -> PackedStringArray:
	if _group_system != null and _group_system.has_method("get_roster"):
		return _group_system.get_roster()
	return PackedStringArray()


## Active party roster IDs that exist in the registry (for kill XP split). Falls back to `fallback_id` if roster empty.
func _xp_share_recipient_ids(fallback_id: StringName) -> PackedStringArray:
	var raw: PackedStringArray = _roster_ids()
	var out: PackedStringArray = PackedStringArray()
	for i in range(raw.size()):
		var cid: StringName = raw[i]
		if _registry != null and _registry.get_character(cid) != null:
			out.append(cid)
	if out.is_empty() and fallback_id != &"":
		out.append(fallback_id)
	return out


func _award_kill_experience_split(base_xp: int, attacker_id: StringName, to_feed: bool, feed_prefix: String) -> void:
	if _progression == null or base_xp <= 0:
		return
	var recipients: PackedStringArray = _xp_share_recipient_ids(attacker_id)
	if recipients.is_empty():
		return
	if not _progression.has_method("distribute_experience_among"):
		_progression.add_total_experience(attacker_id, base_xp)
		if to_feed:
			_append_command_feed("%s %s gained %d XP" % [feed_prefix, String(attacker_id), base_xp], attacker_id)
		return
	const APPLY_SAME_MAP_BONUS: bool = true
	_progression.distribute_experience_among(recipients, base_xp, APPLY_SAME_MAP_BONUS)
	if to_feed:
		var pool_mult: float = 1.15 if APPLY_SAME_MAP_BONUS else 1.0
		var pool_total: int = maxi(1, int(floor(float(base_xp) * pool_mult)))
		var n: int = recipients.size()
		var each: int = int(pool_total / float(n))
		var msg: String = (
			"%s Kill XP %d (pool %d incl. map bonus) split %d-way (~%d each)."
			% [feed_prefix, base_xp, pool_total, n, each]
		)
		_append_command_feed_to_each(msg, recipients)


func _creation_balance_config() -> CharacterBalanceConfig:
	if _balance is CharacterBalanceConfig:
		return _balance as CharacterBalanceConfig
	return load("res://data/default_character_balance.tres") as CharacterBalanceConfig


func _reset_creation_allocation_to_default() -> void:
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	var floor_i: int = cfg.creation_attribute_floor
	_creation_alloc.clear()
	for attr in _Sch.ALL_ATTRIBUTES:
		_creation_alloc[attr] = floor_i


func _creation_points_remaining() -> int:
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	var spent: int = 0
	for attr in _Sch.ALL_ATTRIBUTES:
		spent += int(_creation_alloc.get(attr, cfg.creation_attribute_floor)) - cfg.creation_attribute_floor
	return cfg.creation_attribute_pool - spent


## Max value this stat may take given current allocations (pool + reclaimed points on this stat).
func _creation_max_allow_for_attribute(attr: String) -> int:
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	var floor_i: int = cfg.creation_attribute_floor
	var cap_i: int = cfg.creation_attribute_cap
	var rem: int = _creation_points_remaining()
	var v: int = int(_creation_alloc.get(attr, floor_i))
	var spent_on: int = v - floor_i
	return floor_i + mini(cap_i - floor_i, rem + spent_on)


func _refresh_creation_slider_ranges() -> void:
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	var floor_i: int = cfg.creation_attribute_floor
	for attr in _Sch.ALL_ATTRIBUTES:
		var s: Variant = _creation_sliders_by_attr.get(attr, null)
		if s == null or not (s is Range):
			continue
		var r: Range = s as Range
		var v: int = int(_creation_alloc.get(attr, floor_i))
		var max_v: int = _creation_max_allow_for_attribute(attr)
		r.set_block_signals(true)
		r.min_value = float(floor_i)
		r.max_value = float(max_v)
		r.step = 1.0
		r.value = float(v)
		r.set_block_signals(false)


func _refresh_creation_increment_buttons() -> void:
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	var floor_i: int = cfg.creation_attribute_floor
	for attr in _Sch.ALL_ATTRIBUTES:
		var v: int = int(_creation_alloc.get(attr, floor_i))
		var max_v: int = _creation_max_allow_for_attribute(attr)
		var mb: Variant = _creation_minus_buttons_by_attr.get(attr, null)
		if mb is BaseButton:
			(mb as BaseButton).disabled = v <= floor_i
		var pb: Variant = _creation_plus_buttons_by_attr.get(attr, null)
		if pb is BaseButton:
			(pb as BaseButton).disabled = v >= max_v


func _refresh_creation_alloc_ui() -> void:
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	var floor_i: int = cfg.creation_attribute_floor
	var rem: int = _creation_points_remaining()
	if _creation_points_label != null:
		_creation_points_label.text = (
			"Attribute points remaining: %d  ·  each stat %d–%d  ·  %d points to distribute (spend all to create)"
			% [rem, floor_i, cfg.creation_attribute_cap, cfg.creation_attribute_pool]
		)
	for attr in _Sch.ALL_ATTRIBUTES:
		var vl: Variant = _creation_value_labels_by_attr.get(attr, null)
		if vl is Label:
			(vl as Label).text = str(int(_creation_alloc.get(attr, floor_i)))
	_refresh_creation_slider_ranges()
	_refresh_creation_increment_buttons()
	if _creation_dialog != null:
		var ok: Button = _creation_dialog.get_ok_button()
		if ok != null:
			var name_ok: bool = not _creation_name_edit.text.strip_edges().is_empty()
			ok.disabled = rem != 0 or not name_ok


func _on_creation_slider_value_changed(attr: String, value: float) -> void:
	var floor_i: int = _creation_balance_config().creation_attribute_floor
	var old_v: int = int(_creation_alloc.get(attr, floor_i))
	var max_v: int = _creation_max_allow_for_attribute(attr)
	var new_v: int = clampi(int(round(value)), floor_i, max_v)
	if new_v != old_v:
		_creation_alloc[attr] = new_v
	_refresh_creation_alloc_ui()


func _on_creation_attr_adjust(attr: String, delta: int) -> void:
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	var floor_i: int = cfg.creation_attribute_floor
	var v: int = int(_creation_alloc.get(attr, floor_i))
	var next_v: int = v + delta
	var max_v: int = _creation_max_allow_for_attribute(attr)
	if delta < 0:
		next_v = maxi(next_v, floor_i)
	elif delta > 0:
		next_v = mini(next_v, max_v)
	if next_v == v:
		return
	_creation_alloc[attr] = next_v
	_refresh_creation_alloc_ui()


func _on_creation_name_text_changed(_new_text: String) -> void:
	_refresh_creation_alloc_ui()


func _ensure_creation_dialog() -> void:
	if is_instance_valid(_creation_dialog):
		return
	_creation_dialog = AcceptDialog.new()
	_creation_dialog.title = "Create character"
	_creation_dialog.ok_button_text = "Create"
	## Let content drive height; a large min height was stretching the native window and pushing the OK row off-screen.
	_creation_dialog.min_size = Vector2i(420, 0)
	_creation_dialog.max_size = Vector2i(640, 900)
	_creation_dialog.unresizable = true
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_theme_constant_override("separation", 8)
	_creation_name_edit = LineEdit.new()
	_creation_name_edit.placeholder_text = "Character name"
	_creation_name_edit.custom_minimum_size = Vector2(360, 0)
	_creation_name_edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_creation_name_edit.text_changed.connect(_on_creation_name_text_changed)
	vb.add_child(_creation_name_edit)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(360, 0)
	hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var c0: CharacterBalanceConfig = _creation_balance_config()
	## GDScript supports %d / %f etc.; %g is not valid and breaks the whole %-format (placeholders stay visible).
	hint.text = (
		(
			"All stats start at minimum (%d). Drag sliders to spend your %d points (each stat %d–%d). Skills use stretched attributes ÷ %.2f plus XP ranks."
		)
		% [
			c0.creation_attribute_floor,
			c0.creation_attribute_pool,
			c0.creation_attribute_floor,
			c0.creation_attribute_cap,
			c0.skill_base_divisor,
		]
	)
	vb.add_child(hint)
	_creation_points_label = Label.new()
	_creation_points_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_creation_points_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creation_points_label.custom_minimum_size = Vector2(360, 0)
	vb.add_child(_creation_points_label)
	var attrs_box := VBoxContainer.new()
	attrs_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	attrs_box.add_theme_constant_override("separation", 4)
	_creation_sliders_by_attr.clear()
	_creation_value_labels_by_attr.clear()
	_creation_minus_buttons_by_attr.clear()
	_creation_plus_buttons_by_attr.clear()
	for attr in _Sch.ALL_ATTRIBUTES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_theme_constant_override("separation", 6)
		var cap := Label.new()
		cap.text = attr.capitalize()
		cap.custom_minimum_size = Vector2(96, 0)
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var minus_b := Button.new()
		minus_b.text = "−"
		minus_b.custom_minimum_size = Vector2(36, 30)
		minus_b.focus_mode = Control.FOCUS_NONE
		minus_b.pressed.connect(_on_creation_attr_adjust.bind(attr, -1))
		var slid := HSlider.new()
		slid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slid.custom_minimum_size = Vector2(80, 0)
		slid.step = 1.0
		slid.value_changed.connect(_on_creation_slider_value_changed.bind(attr))
		var plus_b := Button.new()
		plus_b.text = "+"
		plus_b.custom_minimum_size = Vector2(36, 30)
		plus_b.focus_mode = Control.FOCUS_NONE
		plus_b.pressed.connect(_on_creation_attr_adjust.bind(attr, 1))
		var val_lbl := Label.new()
		val_lbl.custom_minimum_size = Vector2(44, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cap)
		row.add_child(minus_b)
		row.add_child(slid)
		row.add_child(plus_b)
		row.add_child(val_lbl)
		attrs_box.add_child(row)
		_creation_sliders_by_attr[attr] = slid
		_creation_value_labels_by_attr[attr] = val_lbl
		_creation_minus_buttons_by_attr[attr] = minus_b
		_creation_plus_buttons_by_attr[attr] = plus_b
	vb.add_child(attrs_box)
	var weapon_lbl := Label.new()
	weapon_lbl.text = "Starter weapon (optional)"
	weapon_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_child(weapon_lbl)
	_creation_weapon_select = OptionButton.new()
	_creation_weapon_select.custom_minimum_size = Vector2(280, 0)
	_creation_weapon_select.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for pair in [
		["No weapon", &""],
		["Sword", &"iron_sword"],
		["Bow", &"short_bow"],
		["Crossbow", &"crossbow"],
		["Wand", &"oak_wand"],
		["Orb", &"focus_orb"],
	]:
		_creation_weapon_select.add_item(str(pair[0]))
		_creation_weapon_select.set_item_metadata(_creation_weapon_select.item_count - 1, pair[1])
	vb.add_child(_creation_weapon_select)
	margin.add_child(vb)
	_creation_dialog.add_child(margin)
	add_child(_creation_dialog)
	if _option_popup_theme != null:
		_creation_weapon_select.get_popup().theme = _option_popup_theme
	_wire_option_button_popup(_creation_weapon_select)
	_creation_dialog.confirmed.connect(_on_creation_confirmed)
	_creation_dialog.visibility_changed.connect(_on_creation_visibility_changed)
	_reset_creation_allocation_to_default()
	_refresh_creation_alloc_ui()


func _on_creation_visibility_changed() -> void:
	if _creation_dialog != null and _creation_dialog.visible:
		_reset_creation_allocation_to_default()
		_refresh_creation_alloc_ui()
		if _creation_weapon_select != null:
			_creation_weapon_select.select(0)
		if _creation_name_edit != null:
			_creation_name_edit.call_deferred("grab_focus")
		_creation_dialog.call_deferred(&"reset_size")


func _on_creation_confirmed() -> void:
	if _registry == null or _group_system == null:
		return
	var n: String = _creation_name_edit.text.strip_edges() if _creation_name_edit != null else ""
	if n.is_empty():
		_append_command_feed("[ui] Choose a name to create a character.")
		return
	if _creation_points_remaining() != 0:
		_append_command_feed("[ui] Spend all attribute points before creating.")
		return
	if not _registry.has_method("can_register") or not _registry.can_register():
		_append_command_feed("[ui] Roster is full — cannot create more characters.")
		return
	var roster: PackedStringArray = _roster_ids()
	if roster.size() >= _Sch.MAX_PARTY_SIZE:
		_append_command_feed("[ui] Party is full — remove a member before creating another.")
		return
	var cd: Resource = CharacterDataScr.new()
	cd.character_id = "char_%d" % Time.get_ticks_msec()
	cd.user_name = n
	cd.is_logged_in = false
	cd.ensure_defaults()
	var cfg: CharacterBalanceConfig = _creation_balance_config()
	for attr in _Sch.ALL_ATTRIBUTES:
		cd.attributes[attr] = int(_creation_alloc.get(attr, cfg.creation_attribute_floor))
	if _registry.register_character(cd) != OK:
		_append_command_feed("[ui] Could not register new character.")
		return
	var new_id: StringName = StringName(cd.character_id)
	if _group_system.add_member(new_id) != OK:
		_append_command_feed("[ui] Could not add new character to the party.")
		return
	if _stats != null and _equipment != null:
		var st0: Dictionary = _stats.get_effective_stats(new_id, cd, _equipment)
		cd.current_health = float(st0.get("max_health", 1.0))
		cd.current_stamina = float(st0.get("max_stamina", 1.0))
		cd.current_mana = float(st0.get("max_mana", 0.0))
		_stats.invalidate(new_id)
	if _creation_weapon_select != null and _inventory != null and _inventory.has_method("try_add_item"):
		var widx: int = clampi(_creation_weapon_select.selected, 0, _creation_weapon_select.item_count - 1)
		var wmeta: Variant = _creation_weapon_select.get_item_metadata(widx)
		var wid: StringName = &""
		if wmeta is StringName:
			wid = wmeta as StringName
		elif wmeta is String and not (wmeta as String).is_empty():
			wid = StringName(wmeta as String)
		if wid != &"":
			_inventory.try_add_item(new_id, wid, 1)
			if wid == &"oak_wand" or wid == &"focus_orb":
				_grant_all_spell_scrolls_for_testing(new_id)
	_focus_character_id = new_id
	_selected_card_slot = mini(_group_system.get_roster().size() - 1, _MAX_PARTY_CARDS - 1)
	if _inventory_panel != null and _inventory_panel.has_method("switch_character"):
		_inventory_panel.switch_character(_focus_character_id)
	_sync_selection_visual_only()
	_refresh_party_cards()
	_sync_world_actors()
	_rebuild_progression_panels()
	_refresh_hud_vitals()
	_refresh_login_button_states()
	_sync_runner_dropdown_to_id(_focus_character_id)
	_populate_runner_options()
	_refresh_follow_target_options()
	_append_command_feed("[ui] Created \"%s\" — use Log in when ready to spawn them." % n, new_id)


func bind_inventory_ui(
	registry: Node,
	inventory: Node,
	equipment: Node,
	catalog: Node,
	stats: Node,
	char_balance: Resource,
	inv_balance: Resource,
	character_id: StringName
) -> void:
	_registry = registry
	_stats = stats
	_equipment = equipment
	_inventory = inventory
	_catalog = catalog
	_balance = char_balance
	_focus_character_id = character_id
	if _inventory_panel != null:
		_inventory_panel.queue_free()
	var packed: PackedScene = load("res://ui/inventory_equipment_panel.tscn") as PackedScene
	if packed == null:
		push_error("MainShell: missing inventory_equipment_panel.tscn")
		return
	_inventory_panel = packed.instantiate()
	for c in _d_inventory_host.get_children():
		c.queue_free()
	_d_inventory_host.add_child(_inventory_panel)
	if _inventory_panel is Control:
		var inv_c: Control = _inventory_panel as Control
		inv_c.set_anchors_preset(Control.PRESET_FULL_RECT)
		inv_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inv_c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## `setup()` touches @onready nodes; they are not ready until this node's `_ready` runs
	## (after `add_child` returns). Defer so grids/labels exist — otherwise setup throws and the shell never finishes wiring.
	if _inventory_panel.has_signal(&"setup_completed"):
		var on_setup_done := Callable(self, "_on_inventory_panel_setup_completed")
		if _inventory_panel.is_connected(&"setup_completed", on_setup_done):
			_inventory_panel.disconnect(&"setup_completed", on_setup_done)
		_inventory_panel.connect(&"setup_completed", on_setup_done)
	if _inventory_panel.has_method(&"setup"):
		_inventory_panel.call_deferred(
			"setup",
			registry,
			inventory,
			equipment,
			catalog,
			stats,
			char_balance,
			inv_balance,
			character_id
		)
	if not _boot_combat_hint_logged and _focus_character_id != &"":
		_append_command_feed(
			"[combat] Press Space or E near a red square to melee (training dummies).",
			_focus_character_id,
		)
		_boot_combat_hint_logged = true
	_refresh_feed_labels()


func bind_combat_system(combat: CombatSystem) -> void:
	_combat = combat


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.physical_keycode != KEY_SPACE and k.physical_keycode != KEY_E:
		return
	if _try_melee_for_focus():
		get_viewport().set_input_as_handled()


func _find_nearest_enemy(from_global: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for n in get_tree().get_nodes_in_group(&"combat_enemies"):
		if not (n is Node2D):
			continue
		var d2: float = from_global.distance_squared_to((n as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n as Node2D
	return best


func _resolve_runner_to_character_id(runner_id: StringName) -> StringName:
	var rs: String = String(runner_id)
	if rs.begins_with(_AUTO_GROUP_PREFIX):
		var gid: StringName = StringName(rs.substr(_AUTO_GROUP_PREFIX.length()))
		if _group_system != null and _group_system.has_method("get_roster"):
			var roster: PackedStringArray = _group_system.get_roster(gid)
			for m in roster:
				if _world_actor_by_id.has(m):
					return m
		return &""
	return runner_id


func _enemy_engaged_with_party_actor(enemy: Node, ally_id: StringName) -> bool:
	if ally_id == &"":
		return false
	if enemy.has_method("is_engaged_with") and bool(enemy.call("is_engaged_with", ally_id)):
		return true
	if enemy.has_method("is_hostile_toward") and bool(enemy.call("is_hostile_toward", ally_id)):
		return true
	if enemy.has_method("has_landed_hit_from") and bool(enemy.call("has_landed_hit_from", ally_id)):
		return true
	return false


func _pick_assist_enemy_for_runner(runner_cid: StringName, ally_id: StringName) -> Node2D:
	if runner_cid == &"" or ally_id == &"":
		return null
	var runner: Node2D = _world_actor_by_id.get(runner_cid) as Node2D
	if runner == null:
		return null
	var best: Node2D = null
	var best_d2: float = INF
	for n in get_tree().get_nodes_in_group(&"combat_enemies"):
		if not (n is Node2D):
			continue
		if not _enemy_engaged_with_party_actor(n, ally_id):
			continue
		var d2: float = runner.global_position.distance_squared_to((n as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n as Node2D
	return best


func _attack_context_for(attacker_id: StringName) -> Dictionary:
	var out: Dictionary = {
		"mode": "none",
		"range_px": 0.0,
		"dmg_min": 0,
		"dmg_max": 0,
		"damage_type": DamageTypes.Id.SLASHING,
		"spell_id": &"",
		"mana_cost": 0,
	}
	if _catalog == null or _equipment == null or attacker_id == &"":
		return out
	var def: Resource = WeaponItemUtils.main_hand_definition(attacker_id, _equipment, _catalog)
	if def == null:
		return out
	var kind: String = WeaponItemUtils.weapon_kind(def)
	if kind == "melee":
		out["mode"] = "melee"
		out["range_px"] = _MELEE_RANGE_PX
		out["dmg_min"] = int(def.damage_min)
		out["dmg_max"] = int(def.damage_max)
		out["damage_type"] = int(def.damage_type)
		return out
	if kind == "missile":
		out["mode"] = "missile"
		out["range_px"] = _MISSILE_RANGE_PX
		out["dmg_min"] = int(def.damage_min)
		out["dmg_max"] = int(def.damage_max)
		out["damage_type"] = int(def.damage_type)
		return out
	if kind == "casting":
		out["range_px"] = _SPELL_CAST_RANGE_PX
		var data: Resource = _registry.get_character(attacker_id) if _registry != null else null
		var sel_var: Variant = _bd_spell_selection_by_character.get(attacker_id, "")
		var sel: StringName = StringName(str(sel_var))
		var tier: int = 1
		out["spell_tier"] = tier
		if sel == &"" or data == null or not data.has_method(&"knows_spell") or not data.knows_spell(sel):
			out["mode"] = "casting_no_spell"
			return out
		if not MagicRules.is_offensive_bolt(sel):
			out["mode"] = "casting_support"
			out["spell_id"] = sel
			out["mana_cost"] = MagicRules.spell_mana_cost(sel, tier)
			return out
		var dr: Vector2i = MagicRules.spell_damage_range_for_tier(sel, tier)
		out["mode"] = "casting"
		out["spell_id"] = sel
		out["dmg_min"] = dr.x
		out["dmg_max"] = dr.y
		out["damage_type"] = MagicRules.offensive_spell_damage_type(sel)
		out["mana_cost"] = MagicRules.spell_mana_cost(sel, tier)
		return out
	return out


func _engagement_range_for_hunter(hunter_cid: StringName) -> float:
	var ctx: Dictionary = _attack_context_for(hunter_cid)
	var r: float = float(ctx.get("range_px", _MELEE_RANGE_PX))
	if r < 8.0:
		r = _MELEE_RANGE_PX
	return r


func _on_hunt_world_pulse(_runner_id: StringName, task: Variant) -> void:
	if _combat == null or _registry == null or _stats == null or _equipment == null:
		return
	if task == null or not (task is AutomationSystem.AutomationTask):
		return
	var at: AutomationSystem.AutomationTask = task as AutomationSystem.AutomationTask
	var cid: StringName = _resolve_runner_to_character_id(_runner_id)
	if cid == &"":
		return
	var hunt_ctx: Dictionary = _attack_context_for(cid)
	if hunt_ctx.get("mode", "none") in ["none", "casting_no_spell", "casting_support"]:
		return
	var now: int = Time.get_ticks_msec()
	var last: int = int(at.data.get("hunt_last_strike_ms", 0))
	const HUNT_STRIKE_COOLDOWN_MS := 650
	if now - last < HUNT_STRIKE_COOLDOWN_MS:
		return
	var lock_id: int = int(at.data.get("hunt_lock_instance_id", 0))
	var outcome: Dictionary
	if lock_id != 0:
		var locked: Object = instance_from_id(lock_id)
		if locked is Node2D and is_instance_valid(locked) and (locked as Node).is_inside_tree():
			outcome = _perform_melee_against_node(cid, locked as Node2D, true, "[auto]")
		else:
			outcome = _perform_melee_exchange(cid, true, "[auto]")
	else:
		outcome = _perform_melee_exchange(cid, true, "[auto]")
	if bool(outcome.get("struck", false)):
		at.data["hunt_last_strike_ms"] = now
	if bool(outcome.get("killed", false)):
		at.data["kills_achieved"] = int(at.data.get("kills_achieved", 0)) + 1


func _on_assist_world_pulse(_runner_id: StringName, task: Variant) -> void:
	if _combat == null or _registry == null or _stats == null or _equipment == null:
		return
	if task == null or not (task is AutomationSystem.AutomationTask):
		return
	var at: AutomationSystem.AutomationTask = task as AutomationSystem.AutomationTask
	var cid: StringName = _resolve_runner_to_character_id(_runner_id)
	if cid == &"":
		return
	var assist_ctx: Dictionary = _attack_context_for(cid)
	if assist_ctx.get("mode", "none") in ["none", "casting_no_spell", "casting_support"]:
		return
	var ally_var: Variant = at.data.get("ally_character_id", &"")
	var ally_id: StringName = ally_var as StringName if ally_var is StringName else StringName(str(ally_var))
	var prey: Node2D = _pick_assist_enemy_for_runner(cid, ally_id)
	if prey == null:
		return
	var now: int = Time.get_ticks_msec()
	var last: int = int(at.data.get("assist_last_strike_ms", 0))
	const ASSIST_STRIKE_COOLDOWN_MS := 650
	if now - last < ASSIST_STRIKE_COOLDOWN_MS:
		return
	var outcome: Dictionary = _perform_melee_against_node(cid, prey, true, "[assist]")
	if bool(outcome.get("struck", false)):
		at.data["assist_last_strike_ms"] = now


func _perform_melee_exchange(attacker_id: StringName, to_feed: bool, feed_prefix: String) -> Dictionary:
	var outcome: Dictionary = {"handled": false, "struck": false, "killed": false}
	if _combat == null or _registry == null or _stats == null or _equipment == null:
		return outcome
	var data: Resource = _registry.get_character(attacker_id)
	if data == null:
		return outcome
	var ctx: Dictionary = _attack_context_for(attacker_id)
	var mode: String = str(ctx.get("mode", "none"))
	if mode == "none":
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Equip a weapon to attack." % feed_prefix, attacker_id)
		return outcome
	if mode == "casting_no_spell":
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Select a spell (Panel B.d)." % feed_prefix, attacker_id)
		return outcome
	if mode == "casting_support":
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Pick a combat bolt for auto-attack." % feed_prefix, attacker_id)
		return outcome
	var attacker: Node2D = _world_actor_by_id.get(attacker_id) as Node2D
	if attacker == null:
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Log in and select a character with a world body to attack." % feed_prefix, attacker_id)
		return outcome
	var atk_stats: Dictionary = _stats.get_effective_stats(attacker_id, data, _equipment)
	var best: Node = null
	var best_d2: float = INF
	var reach: float = float(ctx.get("range_px", _MELEE_RANGE_PX))
	var r2: float = reach * reach
	for n in get_tree().get_nodes_in_group(&"combat_enemies"):
		if not (n is Node2D):
			continue
		var d2: float = attacker.global_position.distance_squared_to((n as Node2D).global_position)
		if d2 <= r2 and d2 < best_d2:
			best_d2 = d2
			best = n
	if best == null:
		outcome["handled"] = true
		var now_ms: int = Time.get_ticks_msec()
		var not_before: int = int(_attack_no_target_not_before_ms.get(attacker_id, 0))
		if now_ms >= not_before:
			_attack_no_target_not_before_ms[attacker_id] = now_ms + _NO_TARGET_RETRY_MS
			if to_feed:
				_append_command_feed("%s No target in range." % feed_prefix, attacker_id)
		return outcome
	return _apply_pc_hit_on_enemy_node(attacker_id, data, atk_stats, best, ctx, to_feed, feed_prefix)


func _perform_melee_against_node(
	attacker_id: StringName,
	enemy: Node2D,
	to_feed: bool,
	feed_prefix: String,
	ctx_snapshot: Dictionary = {},
	apply_mana_cost: bool = true,
) -> Dictionary:
	var outcome: Dictionary = {"handled": false, "struck": false, "killed": false}
	if _combat == null or _registry == null or _stats == null or _equipment == null:
		return outcome
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return outcome
	var data: Resource = _registry.get_character(attacker_id)
	if data == null:
		return outcome
	var ctx: Dictionary = ctx_snapshot if not ctx_snapshot.is_empty() else _attack_context_for(attacker_id)
	var mode: String = str(ctx.get("mode", "none"))
	if mode == "none":
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Equip a weapon to attack." % feed_prefix, attacker_id)
		return outcome
	if mode == "casting_no_spell":
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Select a spell (Panel B.d)." % feed_prefix, attacker_id)
		return outcome
	var attacker: Node2D = _world_actor_by_id.get(attacker_id) as Node2D
	if attacker == null:
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Log in and select a character with a world body to attack." % feed_prefix, attacker_id)
		return outcome
	var reach: float = float(ctx.get("range_px", _MELEE_RANGE_PX))
	var r2: float = reach * reach
	if attacker.global_position.distance_squared_to(enemy.global_position) > r2:
		outcome["handled"] = true
		return outcome
	var party_target_id: StringName = _party_character_id_from_world_body(enemy)
	if mode == "casting_support":
		if party_target_id != &"":
			return _apply_pc_support_spell_on_party_actor(
				attacker_id,
				party_target_id,
				ctx,
				to_feed,
				feed_prefix,
				apply_mana_cost,
			)
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Support spells target allies; combat bolts target enemies." % feed_prefix, attacker_id)
		return outcome
	var atk_stats: Dictionary = _stats.get_effective_stats(attacker_id, data, _equipment)
	if mode == "casting":
		if party_target_id != &"":
			if party_target_id == attacker_id:
				outcome["handled"] = true
				if to_feed:
					_append_command_feed("%s Pick another character as the bolt target." % feed_prefix, attacker_id)
				return outcome
			return _apply_pc_offensive_spell_on_party_actor(
				attacker_id,
				party_target_id,
				data,
				atk_stats,
				ctx,
				to_feed,
				feed_prefix,
				apply_mana_cost,
			)
		return _apply_pc_hit_on_enemy_node(
			attacker_id,
			data,
			atk_stats,
			enemy,
			ctx,
			to_feed,
			feed_prefix,
			apply_mana_cost,
		)
	return _apply_pc_hit_on_enemy_node(
		attacker_id,
		data,
		atk_stats,
		enemy,
		ctx,
		to_feed,
		feed_prefix,
		apply_mana_cost,
	)


func _apply_pc_hit_on_enemy_node(
	attacker_id: StringName,
	data: Resource,
	atk_stats: Dictionary,
	best: Node,
	ctx: Dictionary,
	to_feed: bool,
	feed_prefix: String,
	apply_mana_cost: bool = true,
) -> Dictionary:
	var outcome: Dictionary = {"handled": false, "struck": false, "killed": false}
	if not best.has_method("get_combat_stats") or not best.has_method("take_damage"):
		return outcome
	var mc: int = int(ctx.get("mana_cost", 0))
	if apply_mana_cost and mc > 0 and float(data.current_mana) < float(mc):
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Not enough mana." % feed_prefix, attacker_id)
		return outcome
	if apply_mana_cost and mc > 0:
		data.current_mana = maxf(0.0, float(data.current_mana) - float(mc))
		if _stats != null:
			_stats.invalidate(attacker_id)
	var enemy_stats: Dictionary = best.call("get_combat_stats") as Dictionary
	var dt: int = int(ctx.get("damage_type", DamageTypes.Id.SLASHING))
	var dmin: int = int(ctx.get("dmg_min", 0))
	var dmax: int = int(ctx.get("dmg_max", 0))
	var res: Dictionary = _combat.resolve_melee_hit(atk_stats, enemy_stats, dt, dmin, dmax)
	var dmg: float = float(res.get("damage", 0.0))
	var tgt_label: String = str(best.name)
	if tgt_label.is_empty():
		tgt_label = "target"
	var survived: bool = bool(best.call("take_damage", dmg, attacker_id))
	outcome["handled"] = true
	outcome["struck"] = dmg > 0.0
	outcome["killed"] = not survived
	if to_feed:
		_append_command_feed("%s %s hit %s for %.1f" % [feed_prefix, String(attacker_id), tgt_label, dmg], attacker_id)
	if outcome["killed"] and _progression != null:
		var xp_award: int = 15
		if best.get_script() == _CombatTestEnemyScr:
			var xpv: Variant = best.get("xp_reward")
			if xpv != null:
				xp_award = int(xpv)
		_award_kill_experience_split(xp_award, attacker_id, to_feed, feed_prefix)
	_refresh_hud_vitals()
	_refresh_party_cards()
	return outcome


func _party_character_id_from_world_body(node: Node2D) -> StringName:
	if node == null or not node.is_in_group(&"world_party_actors"):
		return &""
	var v: Variant = node.get("character_id")
	if v is StringName:
		return v as StringName
	return StringName(str(v))


func _apply_pc_offensive_spell_on_party_actor(
	attacker_id: StringName,
	target_id: StringName,
	data: Resource,
	atk_stats: Dictionary,
	ctx: Dictionary,
	to_feed: bool,
	feed_prefix: String,
	apply_mana_cost: bool = true,
) -> Dictionary:
	var outcome: Dictionary = {"handled": false, "struck": false, "killed": false}
	var tdata: Resource = _registry.get_character(target_id)
	if tdata == null:
		return outcome
	var mc: int = int(ctx.get("mana_cost", 0))
	if apply_mana_cost and mc > 0 and float(data.current_mana) < float(mc):
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Not enough mana." % feed_prefix, attacker_id)
		return outcome
	if apply_mana_cost and mc > 0:
		data.current_mana = maxf(0.0, float(data.current_mana) - float(mc))
		if _stats != null:
			_stats.invalidate(attacker_id)
	var def_stats: Dictionary = _stats.get_effective_stats(target_id, tdata, _equipment)
	var dt: int = int(ctx.get("damage_type", DamageTypes.Id.SLASHING))
	var dmin: int = int(ctx.get("dmg_min", 0))
	var dmax: int = int(ctx.get("dmg_max", 0))
	var res: Dictionary = _combat.resolve_melee_hit(atk_stats, def_stats, dt, dmin, dmax)
	var dmg: float = float(res.get("damage", 0.0))
	_combat.apply_vitals_damage(_registry, _stats, target_id, dmg)
	outcome["handled"] = true
	outcome["struck"] = dmg > 0.0
	outcome["killed"] = float(tdata.current_health) <= 0.0
	if to_feed:
		var bolt_line: String = "%s %s bolted %s for %.1f" % [feed_prefix, String(attacker_id), String(target_id), dmg]
		_append_command_feed(bolt_line, attacker_id)
		_append_command_feed(bolt_line, target_id)
	_refresh_hud_vitals()
	_refresh_party_cards()
	return outcome


func _apply_pc_support_spell_on_party_actor(
	attacker_id: StringName,
	target_id: StringName,
	ctx: Dictionary,
	to_feed: bool,
	feed_prefix: String,
	apply_mana_cost: bool = true,
) -> Dictionary:
	var outcome: Dictionary = {"handled": false, "struck": false, "killed": false}
	var data: Resource = _registry.get_character(attacker_id)
	var tdata: Resource = _registry.get_character(target_id)
	if data == null or tdata == null:
		return outcome
	var spell_id: StringName = ctx.get("spell_id", &"") as StringName
	var mc: int = int(ctx.get("mana_cost", 0))
	if apply_mana_cost and mc > 0 and float(data.current_mana) < float(mc):
		outcome["handled"] = true
		if to_feed:
			_append_command_feed("%s Not enough mana." % feed_prefix, attacker_id)
		return outcome
	if apply_mana_cost and mc > 0:
		data.current_mana = maxf(0.0, float(data.current_mana) - float(mc))
		if _stats != null:
			_stats.invalidate(attacker_id)
	var tst: Dictionary = _stats.get_effective_stats(target_id, tdata, _equipment)
	var tname: String = str(tdata.user_name)
	var detail: String = ""
	match spell_id:
		MagicRules.SPELL_HEAL:
			var mh: float = float(tst.get("max_health", 1.0))
			tdata.current_health = clampf(float(tdata.current_health) + 14.0, 0.0, mh)
			detail = "healed %s" % tname
		MagicRules.SPELL_REJUVENATE:
			var mh2: float = float(tst.get("max_health", 1.0))
			var ms2: float = float(tst.get("max_stamina", 1.0))
			tdata.current_health = clampf(float(tdata.current_health) + 10.0, 0.0, mh2)
			tdata.current_stamina = clampf(float(tdata.current_stamina) + 14.0, 0.0, ms2)
			detail = "rejuvenated %s" % tname
		MagicRules.SPELL_REPLENISH:
			var mm: float = float(tst.get("max_mana", 1.0))
			tdata.current_mana = clampf(float(tdata.current_mana) + 18.0, 0.0, mm)
			detail = "replenished mana for %s" % tname
		MagicRules.SPELL_REFLEXES_BUFF:
			var ak: String = _Sch.ATTRIBUTE_REFLEXES
			tdata.transient_attribute_bonus[ak] = int(tdata.transient_attribute_bonus.get(ak, 0)) + 2
			detail = "buffed Reflexes on %s" % tname
		MagicRules.SPELL_MELEE_COMBAT_BUFF:
			var sk: String = _Sch.SKILL_MELEE_COMBAT
			tdata.transient_skill_bonus[sk] = int(tdata.transient_skill_bonus.get(sk, 0)) + 2
			detail = "buffed Melee Combat on %s" % tname
		_:
			var mh3: float = float(tst.get("max_health", 1.0))
			tdata.current_health = clampf(float(tdata.current_health) + 8.0, 0.0, mh3)
			detail = "aided %s" % tname
	if _stats != null:
		_stats.invalidate(target_id)
	outcome["handled"] = true
	outcome["struck"] = true
	if to_feed:
		var sup_line: String = "%s %s — %s." % [feed_prefix, String(attacker_id), detail]
		_append_command_feed(sup_line, attacker_id)
		_append_command_feed(sup_line, target_id)
	_refresh_hud_vitals()
	_refresh_party_cards()
	return outcome


func _try_melee_for_focus() -> bool:
	if _combat == null or _registry == null or _stats == null or _equipment == null:
		return false
	var cid: StringName = _focus_character_id
	if cid == &"":
		return false
	var r: Dictionary = _perform_melee_exchange(cid, true, "[combat]")
	return bool(r.get("handled", false))


func _tick_hostile_enemies(delta: float) -> void:
	for n in get_tree().get_nodes_in_group(&"combat_enemies"):
		if n.has_method("tick_hostile_combat"):
			n.call("tick_hostile_combat", delta, self)


func try_enemy_melee_character(enemy: Node, victim_id: StringName) -> bool:
	if _combat == null or _registry == null or _stats == null or _equipment == null:
		return false
	if enemy == null or not (enemy is Node2D):
		return false
	if enemy.has_method("has_landed_hit_from") and not bool(enemy.call("has_landed_hit_from", victim_id)):
		return false
	if not enemy.has_method("is_hostile_toward") or not bool(enemy.call("is_hostile_toward", victim_id)):
		return false
	var victim: Node2D = _world_actor_by_id.get(victim_id) as Node2D
	if victim == null:
		return false
	var reach: float = _MELEE_RANGE_PX
	if enemy.get_script() == _CombatTestEnemyScr:
		var rv: Variant = enemy.get("melee_range_px")
		if rv != null:
			reach = float(rv)
	var dist: float = (enemy as Node2D).global_position.distance_to(victim.global_position)
	if dist > reach + 0.5:
		return false
	_resolve_enemy_melee_exchange(enemy as Node2D, victim_id)
	return true


func _resolve_enemy_melee_exchange(enemy: Node2D, victim_id: StringName) -> void:
	var enemy_stats: Dictionary = enemy.call("get_combat_stats") as Dictionary
	var data: Resource = _registry.get_character(victim_id)
	if data == null:
		return
	var vic_stats: Dictionary = _stats.get_effective_stats(victim_id, data, _equipment)
	var wmin: int = int(enemy_stats.get("weapon_damage_min", 0))
	var wmax: int = int(enemy_stats.get("weapon_damage_max", 0))
	var edt: int = int(enemy_stats.get("damage_type", DamageTypes.Id.SLASHING))
	var res: Dictionary = _combat.resolve_melee_hit(enemy_stats, vic_stats, edt, wmin, wmax)
	var dmg: float = float(res.get("damage", 0.0))
	_combat.apply_vitals_damage(_registry, _stats, victim_id, dmg)
	if dmg > 0.0 and enemy.has_method("register_aggro_against"):
		enemy.call("register_aggro_against", victim_id)
	var elabel: String = str(enemy.name)
	if elabel.is_empty():
		elabel = "enemy"
	_append_command_feed("[combat] %s hits %s for %.1f" % [elabel, String(victim_id), dmg], victim_id)
	_refresh_hud_vitals()
	_refresh_party_cards()


func bind_progression_system(progression: Node, balance: Resource) -> void:
	if _progression != null:
		if _progression.has_signal("unspent_changed") and _progression.unspent_changed.is_connected(_on_progression_unspent):
			_progression.unspent_changed.disconnect(_on_progression_unspent)
		if _progression.has_signal("attribute_changed") and _progression.attribute_changed.is_connected(_on_progression_attr):
			_progression.attribute_changed.disconnect(_on_progression_attr)
		if _progression.has_signal("skill_rank_changed") and _progression.skill_rank_changed.is_connected(_on_progression_skill):
			_progression.skill_rank_changed.disconnect(_on_progression_skill)
		if _progression.has_signal("level_changed") and _progression.level_changed.is_connected(_on_progression_level):
			_progression.level_changed.disconnect(_on_progression_level)
	_progression = progression
	_balance = balance
	if _progression != null:
		if _progression.has_signal("unspent_changed"):
			_progression.unspent_changed.connect(_on_progression_unspent)
		if _progression.has_signal("attribute_changed"):
			_progression.attribute_changed.connect(_on_progression_attr)
		if _progression.has_signal("skill_rank_changed"):
			_progression.skill_rank_changed.connect(_on_progression_skill)
		if _progression.has_signal("level_changed"):
			_progression.level_changed.connect(_on_progression_level)
	_rebuild_progression_panels()


func _on_progression_unspent(_character_id: StringName, _new_unspent: int) -> void:
	_rebuild_progression_panels()
	_refresh_party_cards()
	_refresh_hud_vitals()


func _on_progression_attr(_character_id: StringName, _attribute_id: StringName, _new_value: int) -> void:
	_rebuild_progression_panels()
	_refresh_party_cards()
	_refresh_hud_vitals()


func _on_progression_skill(_character_id: StringName, _skill_id: StringName, _new_rank: int) -> void:
	_rebuild_progression_panels()
	_refresh_party_cards()
	_refresh_hud_vitals()


func _on_progression_level(_character_id: StringName, _new_level: int) -> void:
	_rebuild_progression_panels()
	_refresh_party_cards()
	_refresh_hud_vitals()


func bind_automation_system(
	system: AutomationSystem,
	registry: Node = null,
	group_system: Node = null
) -> void:
	if _automation != null:
		if _automation.queue_changed.is_connected(_on_automation_queue_changed):
			_automation.queue_changed.disconnect(_on_automation_queue_changed)
		if _automation.runner_queue_changed.is_connected(_on_automation_runner_queue_changed):
			_automation.runner_queue_changed.disconnect(_on_automation_runner_queue_changed)
		if _automation.status_logged.is_connected(_on_automation_status_logged):
			_automation.status_logged.disconnect(_on_automation_status_logged)
		if _automation.hunt_world_pulse.is_connected(_on_hunt_world_pulse):
			_automation.hunt_world_pulse.disconnect(_on_hunt_world_pulse)
		if _automation.assist_world_pulse.is_connected(_on_assist_world_pulse):
			_automation.assist_world_pulse.disconnect(_on_assist_world_pulse)
	_automation = system
	if registry != null:
		_registry = registry
	_group_system = group_system
	if _group_system != null and not _group_signals_connected:
		if _group_system.has_signal("group_roster_changed"):
			_group_system.group_roster_changed.connect(_on_group_roster_changed)
		if _group_system.has_signal("active_group_changed"):
			_group_system.active_group_changed.connect(_on_active_group_changed)
		_group_signals_connected = true
	if _automation != null:
		_automation.queue_changed.connect(_on_automation_queue_changed)
		_automation.runner_queue_changed.connect(_on_automation_runner_queue_changed)
		_automation.status_logged.connect(_on_automation_status_logged)
		_automation.hunt_world_pulse.connect(_on_hunt_world_pulse)
		_automation.assist_world_pulse.connect(_on_assist_world_pulse)
	_refresh_group_selector()
	_populate_runner_options()
	_on_automation_queue_changed()
	_refresh_party_cards()
	_sync_automation_to_panel_b_selection()
	_ensure_automation_tab_controls()
	_sync_world_actors()


func _on_group_roster_changed(_group_id: StringName) -> void:
	_refresh_party_cards()
	_sync_world_actors()
	_populate_runner_options()
	_refresh_follow_target_options()


func _on_active_group_changed(_group_id: StringName) -> void:
	_ensure_focus_in_active_roster()
	_refresh_party_cards()
	_sync_world_actors()
	_refresh_follow_target_options()
	_refresh_hud_vitals()
	_refresh_login_button_states()
	_apply_world_control_focus()
	_refresh_feed_labels()


func _feed_buffer_for(is_command: bool, character_id: StringName) -> Dictionary:
	var root: Dictionary = _feed_command_by_character if is_command else _feed_combat_by_character
	if not root.has(character_id):
		root[character_id] = {"lines": PackedStringArray(), "rkey": "", "rcount": 0}
	return root[character_id]


func _append_to_feed_buffer(bucket: Dictionary, line: String) -> void:
	var lines: PackedStringArray = bucket["lines"]
	var rkey: String = str(bucket["rkey"])
	var rcount: int = int(bucket["rcount"])
	if line == rkey:
		rcount += 1
		var shown: String = line if rcount <= 1 else "%s (%d)" % [line, rcount]
		if lines.is_empty():
			lines.append(shown)
		else:
			lines[lines.size() - 1] = shown
	else:
		rkey = line
		rcount = 1
		lines.append(line)
	while lines.size() > _COMMAND_FEED_MAX_LINES:
		lines.remove_at(0)
	bucket["lines"] = lines
	bucket["rkey"] = rkey
	bucket["rcount"] = rcount


func _buffer_text(bucket: Dictionary) -> String:
	var lines: PackedStringArray = bucket["lines"]
	var acc := ""
	for si in range(lines.size()):
		if si > 0:
			acc += "\n"
		acc += lines[si]
	return acc


func _refresh_feed_labels() -> void:
	if _command_feed == null or _combat_feed == null:
		return
	if _focus_character_id == &"":
		_command_feed.text = ""
		_combat_feed.text = ""
		return
	var cmd_b: Dictionary = _feed_buffer_for(true, _focus_character_id)
	var cbt_b: Dictionary = _feed_buffer_for(false, _focus_character_id)
	_command_feed.text = _buffer_text(cmd_b)
	_combat_feed.text = _buffer_text(cbt_b)


func _feed_line_is_combat_channel(line: String) -> bool:
	var t: String = line.strip_edges()
	if (
		t.begins_with("[attack]")
		or t.begins_with("[cast]")
		or t.begins_with("[auto]")
		or t.begins_with("[assist]")
		or t.begins_with("[combat]")
	):
		return true
	if t.begins_with("[ui]"):
		var low: String = t.to_lower()
		if (
			low.contains("hunt needs")
			or low.contains("follow needs")
			or low.contains("assist combat needs")
			or low.contains("queued ")
			or low.contains("automation dispatch")
			or low.contains("cleared automation queue")
		):
			return false
		if (
			low.contains("casting")
			or low.contains("fizzle")
			or low.contains("cast cancelled")
			or low.contains("cast lost")
			or low.contains("cast interrupted")
		):
			return true
		if low.contains("not enough mana"):
			return true
		if low.contains("out of range to cast"):
			return true
		if low.contains("attack mode on"):
			return true
		if (
			low.contains("spell")
			or low.contains("bolt")
			or low.contains("scroll")
			or low.contains("wand")
			or low.contains("orb")
		):
			return true
	return false


func _append_command_feed(line: String, character_id: StringName = &"") -> void:
	var cid: StringName = character_id
	if cid == &"":
		cid = _focus_character_id
	if cid == &"":
		return
	var combat_ch: bool = _feed_line_is_combat_channel(line)
	var bucket: Dictionary = _feed_buffer_for(not combat_ch, cid)
	_append_to_feed_buffer(bucket, line)
	if cid == _focus_character_id:
		if combat_ch:
			_combat_feed.text = _buffer_text(bucket)
		else:
			_command_feed.text = _buffer_text(bucket)


func _append_command_feed_to_each(line: String, character_ids: PackedStringArray) -> void:
	for i in range(character_ids.size()):
		_append_command_feed(line, character_ids[i])


func _tick_passive_mana_regen(delta: float) -> void:
	if _registry == null or _stats == null or _equipment == null:
		return
	if not _registry.has_method(&"list_character_ids"):
		return
	for cid in _registry.list_character_ids():
		var data: Resource = _registry.get_character(cid)
		if data == null or not bool(data.is_logged_in):
			_passive_mana_elapsed.erase(cid)
			continue
		if not data.has_method(&"get_effective_attribute"):
			continue
		var mind: float = float(data.get_effective_attribute(&"mind"))
		var wis: float = float(data.get_effective_attribute(&"wisdom"))
		var interval: float = GameConstants.mana_regen_interval_sec(mind, wis)
		if interval < 0.001:
			continue
		var acc: float = float(_passive_mana_elapsed.get(cid, 0.0)) + delta
		var st: Dictionary = _stats.get_effective_stats(cid, data, _equipment)
		var mm: float = float(st.get("max_mana", 1.0))
		while acc >= interval:
			acc -= interval
			var cm: float = float(data.current_mana)
			if cm < mm - 0.001:
				data.current_mana = minf(cm + 1.0, mm)
				_stats.invalidate(cid)
		_passive_mana_elapsed[cid] = acc


func _on_world_actor_meditation_resource_tick(character_id: StringName, kind: StringName, amount: float) -> void:
	if _registry == null:
		return
	var data: Resource = _registry.get_character(character_id)
	if data == null:
		return
	if kind == &"health":
		data.current_health += amount
	elif kind == &"stamina":
		data.current_stamina += amount
	else:
		return
	if _stats != null and _equipment != null:
		var st: Dictionary = _stats.get_effective_stats(character_id, data, _equipment)
		var mh: float = float(st.get("max_health", 99999.0))
		var ms: float = float(st.get("max_stamina", 99999.0))
		data.current_health = clampf(float(data.current_health), 0.0, mh)
		data.current_stamina = clampf(float(data.current_stamina), 0.0, ms)
	if _stats != null:
		_stats.invalidate(character_id)
	_refresh_party_cards()


func _ensure_meditation_signals_on_actors() -> void:
	var cb := Callable(self, &"_on_world_actor_meditation_resource_tick")
	for wa in _world_actor_by_id.values():
		if wa == null or not is_instance_valid(wa):
			continue
		if not wa.has_signal(&"meditation_resource_tick"):
			continue
		if not wa.is_connected(&"meditation_resource_tick", cb):
			wa.meditation_resource_tick.connect(_on_world_actor_meditation_resource_tick)


func _pretty_skill_label(skill_id: String) -> String:
	var parts: PackedStringArray = String(skill_id).split("_")
	var acc := ""
	for i in range(parts.size()):
		if i > 0:
			acc += " "
		var p: String = parts[i]
		if p.is_empty():
			continue
		acc += p.capitalize()
	return acc


func _refresh_bc_meditate_button_label() -> void:
	if _btn_bc_meditate == null or _focus_character_id == &"":
		return
	var wa: Node = _world_actor_by_id.get(_focus_character_id) as Node
	if wa == null:
		return
	var want: String = "Stop meditation" if bool(wa.is_meditating) else "Meditate"
	if _btn_bc_meditate.text != want:
		_btn_bc_meditate.text = want


func _on_bc_meditate_pressed() -> void:
	if _focus_character_id == &"" or _registry == null:
		_append_command_feed("[ui] Select a character to meditate.")
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null:
		return
	if not bool(data.is_logged_in):
		_append_command_feed("[ui] Log in to meditate.")
		return
	var wa: Node = _world_actor_by_id.get(_focus_character_id) as Node
	if wa == null or not wa.has_method(&"set_meditating"):
		_append_command_feed("[ui] No world body for this character.")
		return
	var on: bool = not bool(wa.is_meditating)
	wa.set_meditating(on)
	_append_command_feed("[ui] Meditation %s for %s." % ["started" if on else "stopped", str(data.user_name)])
	_refresh_login_button_states()


func _on_automation_status_logged(runner_id: StringName, message: String) -> void:
	var cid: StringName = _resolve_runner_to_character_id(runner_id)
	if cid == &"":
		cid = _focus_character_id
	_append_command_feed("%s · %s" % [String(runner_id), message], cid)


func _mount_world() -> void:
	var packed: PackedScene = load(GameConstants.PLACEHOLDER_MAP) as PackedScene
	if packed == null:
		push_error("MainShell: missing map at %s" % GameConstants.PLACEHOLDER_MAP)
		return
	_world_actor_by_id.clear()
	for ch in _world_viewport.get_children():
		ch.queue_free()
	var instance: Node = packed.instantiate()
	_world_viewport.add_child(instance)
	_actors_root = null
	if instance.has_method("get_actors_root"):
		_actors_root = instance.call("get_actors_root") as Node2D
	else:
		var maybe_actors: Node = instance.get_node_or_null("Actors")
		if maybe_actors is Node2D:
			_actors_root = maybe_actors as Node2D


func _setup_hud_placeholders() -> void:
	_hud_health.max_value = 100.0
	_hud_health.value = 100.0
	_hud_stamina.max_value = 100.0
	_hud_stamina.value = 100.0
	_hud_mana.max_value = 100.0
	_hud_mana.value = 100.0
	_hud_health_value.text = "— / —"
	_hud_stamina_value.text = "— / —"
	_hud_mana_value.text = "— / —"


func _refresh_hud_vitals() -> void:
	if _focus_character_id == &"" or _registry == null or _stats == null or _equipment == null:
		_hud_health_value.text = "— / —"
		_hud_stamina_value.text = "— / —"
		_hud_mana_value.text = "— / —"
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null:
		_hud_health_value.text = "— / —"
		_hud_stamina_value.text = "— / —"
		_hud_mana_value.text = "— / —"
		return
	var st: Dictionary = _stats.get_effective_stats(_focus_character_id, data, _equipment)
	var mh: float = float(st.get("max_health", 1.0))
	var ms: float = float(st.get("max_stamina", 1.0))
	var mm: float = float(st.get("max_mana", 1.0))
	_hud_health.max_value = mh
	var ch: float = clampf(float(data.current_health), 0.0, mh)
	_hud_health.value = ch
	_hud_stamina.max_value = ms
	var cs: float = clampf(float(data.current_stamina), 0.0, ms)
	_hud_stamina.value = cs
	_hud_mana.max_value = mm
	var cm: float = clampf(float(data.current_mana), 0.0, mm)
	_hud_mana.value = cm
	_hud_health_value.text = "%.0f / %.0f" % [ch, mh]
	_hud_stamina_value.text = "%.0f / %.0f" % [cs, ms]
	_hud_mana_value.text = "%.0f / %.0f" % [cm, mm]


func _refresh_group_selector() -> void:
	_group_selector.set_block_signals(true)
	_option_button_clear_all(_group_selector)
	var added: int = 0
	if _group_system != null and _group_system.has_method("list_group_ids"):
		for gid in _group_system.list_group_ids():
			_group_selector.add_item(String(gid))
			_group_selector.set_item_metadata(_group_selector.item_count - 1, gid)
			added += 1
	if added == 0:
		_group_selector.add_item("default")
		_group_selector.set_item_metadata(0, &"default")
	var pick: int = 0
	if _group_system != null and _group_system.has_method("get_active_group_id"):
		var active: StringName = _group_system.get_active_group_id()
		var picked: bool = false
		for j in range(_group_selector.item_count):
			if _variant_group_id_matches(_group_selector.get_item_metadata(j), active):
				pick = j
				picked = true
				break
		if not picked and _group_selector.item_count > 0:
			pick = 0
	elif _group_selector.item_count > 0:
		pick = 0
	if _group_selector.item_count > 0:
		_group_selector.select(pick)
	_group_selector.set_block_signals(false)


func _on_group_item_selected(index: int) -> void:
	if _group_system == null:
		return
	var m: Variant = _group_selector.get_item_metadata(index)
	if m is StringName:
		_group_system.set_active_group(m)
	elif m is String:
		_group_system.set_active_group(StringName(m))
	else:
		return


func _cycle_active_group(delta: int) -> void:
	if _group_system == null or not _group_system.has_method("set_active_group"):
		return
	var ids: Array[StringName] = _sorted_group_ids_for_ui()
	if ids.is_empty():
		return
	var active: StringName = _group_system.get_active_group_id()
	var idx: int = 0
	for i in range(ids.size()):
		if _variant_group_id_matches(ids[i], active):
			idx = i
			break
	idx = posmod(idx + delta, ids.size())
	_group_system.set_active_group(ids[idx])
	_refresh_group_selector()


func _on_group_manage_pressed() -> void:
	_append_command_feed("[ui] Roster management is not wired yet — placeholder button.")


func _portrait_color_for(id: StringName) -> Color:
	var h: float = float(abs(String(id).hash()) % 360) / 360.0
	return Color.from_hsv(h, 0.5, 0.55, 1.0)


func _sync_world_actors() -> void:
	if _actors_root == null or _registry == null:
		return
	## All logged-in characters stay in the world regardless of which group is active (party switch is UI context only).
	var logged_in_list: Array = []
	if _registry.has_method("list_character_ids"):
		for cid in _registry.list_character_ids():
			var data: Resource = _registry.get_character(cid)
			if data != null and bool(data.is_logged_in):
				logged_in_list.append(cid)
	var should_exist: Dictionary = {}
	for cid in logged_in_list:
		should_exist[cid] = true
	var to_remove: Array = []
	for cid in _world_actor_by_id.keys():
		if not should_exist.has(cid):
			to_remove.append(cid)
	for cid in to_remove:
		var dead: Node = _world_actor_by_id[cid] as Node
		_world_actor_by_id.erase(cid)
		if dead != null and is_instance_valid(dead):
			dead.queue_free()
	for i in range(logged_in_list.size()):
		var cid2: StringName = logged_in_list[i]
		if not _world_actor_by_id.has(cid2):
			var spawn_x: float = 0.0
			for other_id in _world_actor_by_id.keys():
				var ex: Node2D = _world_actor_by_id[other_id] as Node2D
				if ex != null:
					spawn_x = maxf(spawn_x, ex.position.x + 56.0)
			var wa: Node = WorldActorScene.instantiate()
			wa.set_actor_id(cid2)
			wa.position = Vector2(spawn_x, 0.0)
			_actors_root.add_child(wa)
			_world_actor_by_id[cid2] = wa
	_apply_world_control_focus()
	_sync_world_actor_colors_from_cards()
	_ensure_meditation_signals_on_actors()
	_refresh_login_button_states()


func _apply_world_control_focus() -> void:
	for cid in _world_actor_by_id.keys():
		var node: Node = _world_actor_by_id[cid] as Node
		if node != null and node.has_method("set_controlled"):
			node.set_controlled(cid == _focus_character_id)


func _sync_world_actor_colors_from_cards() -> void:
	for i in range(_party_cards.size()):
		var card: Node = _party_cards[i]
		if card == null or not card.has_method("is_filled") or not card.is_filled():
			continue
		var cid: StringName = card.get_character_id()
		if cid == &"" or not _world_actor_by_id.has(cid):
			continue
		var node: Node = _world_actor_by_id[cid]
		if node == null or not node.has_method("set_glyph_color") or not card.has_method("get_display_portrait_color"):
			continue
		var c: Color = card.get_display_portrait_color()
		c.a = 1.0
		node.set_glyph_color(c)


func _refresh_party_cards() -> void:
	if _party_cards.is_empty():
		return
	var ids: PackedStringArray = _roster_ids()
	for i in range(_party_cards.size()):
		var card: Node = _party_cards[i]
		if i >= ids.size():
			if card.has_method("clear_slot"):
				card.clear_slot()
			continue
		var cid: StringName = ids[i]
		if _registry == null or not _registry.has_method("get_character"):
			if card.has_method("clear_slot"):
				card.clear_slot()
			continue
		var data: Resource = _registry.get_character(cid)
		if data == null:
			if card.has_method("clear_slot"):
				card.clear_slot()
			continue
		var hp_max: float = 100.0
		var hp: float = float(data.current_health)
		var st_max: float = 100.0
		var st: float = float(data.current_stamina)
		var mn_max: float = 100.0
		var mn: float = float(data.current_mana)
		if _stats != null and _equipment != null:
			var eff: Dictionary = _stats.get_effective_stats(cid, data, _equipment)
			hp_max = float(eff.get("max_health", maxf(hp, 100.0)))
			st_max = float(eff.get("max_stamina", maxf(st, 100.0)))
			mn_max = float(eff.get("max_mana", maxf(mn, 1.0)))
		else:
			hp_max = maxf(hp, 100.0)
			st_max = maxf(st, 100.0)
			mn_max = maxf(mn, 1.0)
		var display_name: String = str(data.user_name)
		if card.has_method("bind_character"):
			card.bind_character(
				cid,
				display_name,
				hp,
				hp_max,
				st,
				st_max,
				mn,
				mn_max,
				_portrait_color_for(cid),
				bool(data.is_logged_in),
			)
	for j in range(_party_cards.size()):
		var c: Node = _party_cards[j]
		if c.has_method("set_selected"):
			c.set_selected(j == _selected_card_slot)
	_sync_world_actor_colors_from_cards()
	_refresh_follow_target_options()


func _prey_hunters_map() -> Dictionary:
	var result: Dictionary = {}
	if _automation != null:
		for cid in _world_actor_by_id.keys():
			var node: Node = _world_actor_by_id[cid]
			if node == null or not (node is Node2D):
				continue
			var task_var: Variant = _automation.get_active_task_for(cid)
			if task_var == null or not task_var is AutomationSystem.AutomationTask:
				continue
			var at: AutomationSystem.AutomationTask = task_var as AutomationSystem.AutomationTask
			var prey: Node2D = null
			if at.type == AutomationSystem.TaskType.HUNT and not at.data.get("sim_only", false):
				prey = _find_nearest_enemy((node as Node2D).global_position)
			elif at.type == AutomationSystem.TaskType.ASSIST_COMBAT:
				var ally_var: Variant = at.data.get("ally_character_id", &"")
				var ally_id: StringName = ally_var as StringName if ally_var is StringName else StringName(str(ally_var))
				prey = _pick_assist_enemy_for_runner(cid, ally_id)
			if prey == null or not is_instance_valid(prey):
				continue
			var iid: int = prey.get_instance_id()
			if not result.has(iid):
				result[iid] = []
			(result[iid] as Array).append(cid)
	if _ui_attack_active and _focus_character_id != &"":
		var en: Node2D = _resolve_ui_attack_enemy()
		if en != null and is_instance_valid(en) and _world_actor_by_id.has(_focus_character_id):
			var iid2: int = en.get_instance_id()
			if not result.has(iid2):
				result[iid2] = []
			var arr2: Array = result[iid2] as Array
			if not arr2.has(_focus_character_id):
				arr2.append(_focus_character_id)
	for k in result.keys():
		var arr: Array = result[k] as Array
		arr.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	return result


func _hunt_ring_goal_for(prey: Node2D, hunter_cid: StringName, prey_hunters: Dictionary) -> Vector2:
	var center: Vector2 = prey.global_position
	var iid: int = prey.get_instance_id()
	var hunters: Array = prey_hunters.get(iid, []) as Array
	if hunters.size() <= 1:
		return center
	var idx: int = hunters.find(hunter_cid)
	if idx < 0:
		return center
	var n: int = hunters.size()
	var reach: float = _engagement_range_for_hunter(hunter_cid)
	var ring_r: float = reach * float(GameConstants.HUNT_ENGAGEMENT_RING_FRACTION)
	var theta: float = TAU * float(idx) / float(n)
	return center + Vector2(cos(theta), sin(theta)) * ring_r


func _apply_follow_movement(_delta: float) -> void:
	if _automation == null:
		return
	var prey_hunters: Dictionary = _prey_hunters_map()
	var tile_px: float = float(GameConstants.TILE_SIZE_PX)
	var min_sep_px: float = tile_px * float(GameConstants.FOLLOW_MIN_SEPARATION_TILES)
	var resume_px: float = tile_px * float(GameConstants.FOLLOW_RESUME_CHASE_TILES)
	const FOLLOW_SPEED: float = 170.0
	const FOLLOW_BACKOFF_SPEED: float = 120.0
	for cid in _world_actor_by_id.keys():
		var node: Node = _world_actor_by_id[cid]
		if node == null or not node.has_method("set_automation_velocity"):
			continue
		var vel := Vector2.ZERO
		var use_hunt_nav: bool = false
		var task_var: Variant = _automation.get_active_task_for(cid)
		if task_var != null and task_var is AutomationSystem.AutomationTask:
			var at: AutomationSystem.AutomationTask = task_var as AutomationSystem.AutomationTask
			if at.type == AutomationSystem.TaskType.HUNT and not at.data.get("sim_only", false):
				if node is Node2D and node.has_method("set_hunt_navigation_active"):
					var prey: Node2D = _find_nearest_enemy((node as Node2D).global_position)
					if prey != null:
						var hunt_reach: float = _engagement_range_for_hunter(cid)
						var diff_h: Vector2 = prey.global_position - (node as Node2D).global_position
						if diff_h.length() > hunt_reach * 0.92:
							use_hunt_nav = true
							node.set_hunt_navigation_active(true)
							node.update_hunt_navigation_goal(_hunt_ring_goal_for(prey, cid, prey_hunters))
						else:
							node.set_hunt_navigation_active(false)
					else:
						node.set_hunt_navigation_active(false)
			elif at.type == AutomationSystem.TaskType.ASSIST_COMBAT:
				var ally_var: Variant = at.data.get("ally_character_id", &"")
				var ally_id: StringName = ally_var as StringName if ally_var is StringName else StringName(str(ally_var))
				if node is Node2D and node.has_method("set_hunt_navigation_active"):
					var prey_a: Node2D = _pick_assist_enemy_for_runner(cid, ally_id)
					if prey_a != null:
						var assist_reach: float = _engagement_range_for_hunter(cid)
						var diff_a: Vector2 = prey_a.global_position - (node as Node2D).global_position
						if diff_a.length() > assist_reach * 0.92:
							use_hunt_nav = true
							node.set_hunt_navigation_active(true)
							node.update_hunt_navigation_goal(_hunt_ring_goal_for(prey_a, cid, prey_hunters))
						else:
							node.set_hunt_navigation_active(false)
					else:
						node.set_hunt_navigation_active(false)
			else:
				if node.has_method("set_hunt_navigation_active"):
					node.set_hunt_navigation_active(false)
				if cid != _focus_character_id and at.type == AutomationSystem.TaskType.FOLLOW_CHARACTER:
					var tid_var: Variant = at.data.get("target_character_id", &"")
					var tid: StringName = &""
					if tid_var is StringName:
						tid = tid_var as StringName
					else:
						tid = StringName(str(tid_var))
					if tid != &"" and tid != cid:
						var tgt_node: Node = _world_actor_by_id.get(tid) as Node
						if tgt_node is Node2D and node is Node2D:
							var from_p: Vector2 = (node as Node2D).global_position
							var to_p: Vector2 = (tgt_node as Node2D).global_position
							var diff: Vector2 = to_p - from_p
							var dist: float = diff.length()
							var caught: bool = bool(at.data.get("follow_caught_up", false))
							if dist < min_sep_px * 0.92:
								vel = -diff.normalized() * FOLLOW_BACKOFF_SPEED
								caught = true
							elif caught:
								if dist >= resume_px:
									caught = false
								else:
									vel = Vector2.ZERO
							else:
								if dist > min_sep_px:
									vel = diff.normalized() * FOLLOW_SPEED
								else:
									caught = true
									vel = Vector2.ZERO
							at.data["follow_caught_up"] = caught
		else:
			if node.has_method("set_hunt_navigation_active"):
				node.set_hunt_navigation_active(false)
		if use_hunt_nav:
			node.set_automation_velocity(Vector2.ZERO)
		elif cid != _focus_character_id:
			node.set_automation_velocity(vel)
		else:
			node.set_automation_velocity(Vector2.ZERO)



func _sync_follow_dropdown_selection_from_panel_b() -> void:
	if _opt_follow_target == null:
		return
	var n_items: int = _opt_follow_target.item_count
	if n_items <= 0:
		return
	var want: StringName = &""
	var self_cid: StringName = _drafting_automation_character_id()
	if self_cid == &"":
		self_cid = _focus_character_id
	if _selection_portrait_source == "world" and _selection_world_kind == "actor" and _selection_world_id != &"":
		var cand: StringName = _selection_world_id
		if cand != self_cid and _follow_roster_contains(cand):
			want = cand
	var pick: int = -1
	if want != &"":
		for i in range(n_items):
			var meta: Variant = _opt_follow_target.get_item_metadata(i)
			if meta == null:
				continue
			if StringName(str(meta)) == want:
				pick = i
				break
	_opt_follow_target.set_block_signals(true)
	if pick >= 0:
		_opt_follow_target.select(pick)
	elif n_items > 0:
		_opt_follow_target.select(0)
	_opt_follow_target.set_block_signals(false)


func _follow_roster_contains(cid: StringName) -> bool:
	if _group_system == null or not _group_system.has_method("get_roster"):
		return false
	for r in _group_system.get_roster():
		if r == cid:
			return true
	return false


func _refresh_follow_target_options() -> void:
	if _opt_follow_target == null:
		return
	_opt_follow_target.set_block_signals(true)
	_option_button_clear_all(_opt_follow_target)
	var added: int = 0
	var self_cid: StringName = _resolve_runner_to_character_id(_current_runner_id)
	if self_cid == &"":
		self_cid = _focus_character_id
	if _group_system != null and _group_system.has_method("get_roster") and _registry != null:
		for cid in _group_system.get_roster():
			if cid == self_cid:
				continue
			var data: Resource = _registry.get_character(cid)
			var label: String = str(data.user_name) if data != null else String(cid)
			_opt_follow_target.add_item("%s (%s)" % [label, String(cid)])
			_opt_follow_target.set_item_metadata(_opt_follow_target.item_count - 1, cid)
			added += 1
	if added == 0:
		_opt_follow_target.add_item("(no other party members)")
	_sync_follow_dropdown_selection_from_panel_b()


func _rebuild_progression_panels() -> void:
	_rebuild_attributes_panel()
	_rebuild_skills_panel()


func _rebuild_attributes_panel() -> void:
	for c in _d_attributes_host.get_children():
		c.queue_free()
	if _focus_character_id == &"" or _registry == null or _balance == null:
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null:
		return
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var hdr := Label.new()
	var xp_to_next: int = 0
	if _balance != null and _balance.has_method("get_xp_to_next_level"):
		xp_to_next = int(_balance.call("get_xp_to_next_level", int(data.total_experience), int(data.level)))
	hdr.text = "Unspent XP: %d  ·  Lv.%d  ·  XP to next level: %d  ·  Total XP: %d" % [
		int(data.unspent_experience),
		int(data.level),
		xp_to_next,
		int(data.total_experience),
	]
	v.add_child(hdr)
	var st_eff: Dictionary = {}
	if _stats != null and _equipment != null:
		st_eff = _stats.get_effective_stats(_focus_character_id, data, _equipment)
	var bal_cfg: CharacterBalanceConfig = _balance as CharacterBalanceConfig
	for attr in _Sch.ALL_ATTRIBUTES:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, float(_PROGRESSION_ROW_MIN_HEIGHT_PX))
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var cap: int = int(data.attributes.get(attr, 10))
		var eff: int = int(data.get_effective_attribute(StringName(attr)))
		var purchases: int = int(data.attribute_xp_purchases.get(attr, 0))
		var cost: int = 0
		if bal_cfg != null:
			cost = bal_cfg.get_unspent_cost_for_xp_purchase_count(purchases)
		else:
			cost = _balance.get_unspent_cost_raise_attribute(cap)
		var lbl := Label.new()
		var bonus: int = eff - cap
		if bonus != 0:
			lbl.text = "%s   %d (%+d)" % [String(attr).capitalize(), eff, bonus]
		else:
			lbl.text = "%s   %d" % [String(attr).capitalize(), eff]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.clip_text = true
		var btn := Button.new()
		btn.text = "Raise · %d XP" % cost
		btn.custom_minimum_size = Vector2(0, float(_PROGRESSION_RAISE_BTN_MIN_HEIGHT_PX))
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.disabled = cap >= int(_balance.max_attribute_value) or int(data.unspent_experience) < cost
		btn.pressed.connect(_on_buy_attribute_pressed.bind(StringName(attr)))
		row.add_child(lbl)
		row.add_child(btn)
		v.add_child(row)
	if bal_cfg != null:
		var vital_defs: Array = [
			{
				"id": &"health",
				"title": "Max Health",
				"cur": data.current_health,
				"max_k": "max_health",
			},
			{
				"id": &"stamina",
				"title": "Max Stamina",
				"cur": data.current_stamina,
				"max_k": "max_stamina",
			},
			{
				"id": &"mana",
				"title": "Max Mana",
				"cur": data.current_mana,
				"max_k": "max_mana",
			},
		]
		for vd in vital_defs:
			var vid: StringName = vd["id"] as StringName
			var vk: String = String(vid)
			var rowv := HBoxContainer.new()
			rowv.custom_minimum_size = Vector2(0, float(_PROGRESSION_ROW_MIN_HEIGHT_PX))
			rowv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rowv.alignment = BoxContainer.ALIGNMENT_CENTER
			var mx: float = float(st_eff.get(vd["max_k"], 0.0))
			var vpurch: int = int(data.vital_xp_purchases.get(vk, 0))
			var vcost: int = bal_cfg.get_unspent_cost_for_xp_purchase_count(vpurch)
			var lblv := Label.new()
			lblv.text = "%s   %.0f / %.0f" % [vd["title"], float(vd["cur"]), mx]
			lblv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lblv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			lblv.clip_text = true
			var btnv := Button.new()
			btnv.text = "Raise max · %d XP" % vcost
			btnv.custom_minimum_size = Vector2(0, float(_PROGRESSION_RAISE_BTN_MIN_HEIGHT_PX))
			btnv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btnv.disabled = int(data.unspent_experience) < vcost
			btnv.pressed.connect(_on_buy_vital_pressed.bind(vid))
			rowv.add_child(lblv)
			rowv.add_child(btnv)
			v.add_child(rowv)
	margin.add_child(v)
	sc.add_child(margin)
	_d_attributes_host.add_child(sc)


func _on_buy_attribute_pressed(attr_id: StringName) -> void:
	if _progression == null:
		return
	_progression.try_raise_attribute(_focus_character_id, attr_id)
	if _stats != null:
		_stats.invalidate(_focus_character_id)
	_rebuild_progression_panels()
	_refresh_party_cards()
	_refresh_hud_vitals()


func _on_buy_vital_pressed(vital_id: StringName) -> void:
	if _progression == null:
		return
	_progression.try_raise_vital_pool(_focus_character_id, vital_id)
	if _stats != null:
		_stats.invalidate(_focus_character_id)
	_rebuild_progression_panels()
	_refresh_party_cards()
	_refresh_hud_vitals()


func _merged_skill_ranks_for_progression(data: Resource) -> Dictionary:
	var merged: Dictionary = {}
	for skill_id in _Sch.ALL_SKILLS:
		merged[skill_id] = int(data.skill_levels.get(skill_id, 0)) + int(data.transient_skill_bonus.get(skill_id, 0))
	return merged


func _rebuild_skills_panel() -> void:
	var prev_scroll: int = 0
	for c in _d_skills_host.get_children():
		if c is ScrollContainer:
			prev_scroll = (c as ScrollContainer).scroll_vertical
			break
	for c in _d_skills_host.get_children():
		c.queue_free()
	if _focus_character_id == &"" or _registry == null or _balance == null:
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null:
		return
	var skill_mods: Dictionary = {}
	if _stats != null and _equipment != null:
		var st_sk: Dictionary = _stats.get_effective_stats(_focus_character_id, data, _equipment)
		skill_mods = st_sk.get("skill_modifiers", {}) as Dictionary
	elif _balance is CharacterBalanceConfig:
		skill_mods = (_balance as CharacterBalanceConfig).get_all_skill_total_modifiers(
			data.attributes,
			_merged_skill_ranks_for_progression(data),
		)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var hdr2 := Label.new()
	var xp_to_next2: int = 0
	if _balance != null and _balance.has_method("get_xp_to_next_level"):
		xp_to_next2 = int(_balance.call("get_xp_to_next_level", int(data.total_experience), int(data.level)))
	hdr2.text = "Unspent XP: %d  ·  Lv.%d  ·  XP to next level: %d  ·  Total XP: %d" % [
		int(data.unspent_experience),
		int(data.level),
		xp_to_next2,
		int(data.total_experience),
	]
	v.add_child(hdr2)
	for sk in _Sch.ALL_SKILLS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, float(_PROGRESSION_ROW_MIN_HEIGHT_PX))
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var bought_rank: int = int(data.skill_levels.get(sk, 0))
		var buff_rank: int = int(data.transient_skill_bonus.get(sk, 0))
		var mod_total: float = float(skill_mods.get(sk, 0.0))
		var sk_purchases: int = int(data.skill_xp_purchases.get(sk, 0))
		var cost: int = _balance.get_unspent_cost_raise_skill(sk_purchases)
		var lbl := Label.new()
		var line: String = "%s   %.2f   (ranks %d" % [_pretty_skill_label(sk), mod_total, bought_rank]
		if buff_rank != 0:
			line += " +%d buff" % buff_rank
		line += ")"
		lbl.text = line
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.clip_text = true
		var btn := Button.new()
		btn.text = "Raise · %d XP" % cost
		btn.custom_minimum_size = Vector2(0, float(_PROGRESSION_RAISE_BTN_MIN_HEIGHT_PX))
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.disabled = int(data.unspent_experience) < cost
		btn.pressed.connect(_on_buy_skill_pressed.bind(StringName(sk)))
		row.add_child(lbl)
		row.add_child(btn)
		v.add_child(row)
	margin.add_child(v)
	sc.add_child(margin)
	_d_skills_host.add_child(sc)
	sc.set_deferred(&"scroll_vertical", prev_scroll)


func _on_buy_skill_pressed(skill_id: StringName) -> void:
	if _progression == null:
		return
	_progression.try_raise_skill(_focus_character_id, skill_id)
	if _stats != null:
		_stats.invalidate(_focus_character_id)
	_rebuild_progression_panels()
	_refresh_party_cards()
	_refresh_hud_vitals()


func _ensure_automation_tab_controls() -> void:
	if _automation_tab_built_revision >= _AUTOMATION_PANEL_REVISION:
		return
	_automation_tab_built_revision = _AUTOMATION_PANEL_REVISION
	for c in _d_automation_host.get_children():
		c.queue_free()
	_opt_follow_target = null
	_opt_automation_task = null
	_chk_automation_queue_hold = null
	_lbl_automation_context = null
	_automation_follow_block = null
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var hint := Label.new()
	hint.text = "Pick a task, Add to queue, then Begin. When Follow is selected, choose a party follow target below; if B.b has a followable ally, that entry is selected by default."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	_lbl_automation_context = Label.new()
	_lbl_automation_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_automation_context)
	_chk_automation_queue_hold = CheckBox.new()
	_chk_automation_queue_hold.text = "Hold queue until Begin"
	_chk_automation_queue_hold.button_pressed = true
	_chk_automation_queue_hold.toggled.connect(_on_automation_queue_hold_toggled)
	v.add_child(_chk_automation_queue_hold)
	var row_pick := HBoxContainer.new()
	row_pick.add_theme_constant_override("separation", 8)
	var lbl_task := Label.new()
	lbl_task.text = "Task:"
	row_pick.add_child(lbl_task)
	_opt_automation_task = OptionButton.new()
	_opt_automation_task.custom_minimum_size = Vector2(200, 0)
	_opt_automation_task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair in [
		["Idle", AutomationSystem.TaskType.IDLE],
		["Wait", AutomationSystem.TaskType.WAIT],
		["Hunt", AutomationSystem.TaskType.HUNT],
		["Follow", AutomationSystem.TaskType.FOLLOW_CHARACTER],
		["Assist combat", AutomationSystem.TaskType.ASSIST_COMBAT],
	]:
		_opt_automation_task.add_item(pair[0] as String)
		_opt_automation_task.set_item_metadata(_opt_automation_task.item_count - 1, pair[1] as int)
	if _option_popup_theme != null:
		_opt_automation_task.get_popup().theme = _option_popup_theme
	elif theme != null:
		_opt_automation_task.get_popup().theme = _build_option_popup_theme(theme as Theme)
	_wire_option_button_popup(_opt_automation_task)
	if _opt_automation_task.item_count > 0:
		_opt_automation_task.select(0)
	row_pick.add_child(_opt_automation_task)
	v.add_child(row_pick)
	var row_actions := HBoxContainer.new()
	row_actions.add_theme_constant_override("separation", 8)
	var btn_add := Button.new()
	btn_add.text = "Add to queue"
	btn_add.pressed.connect(_on_automation_add_to_queue)
	var btn_begin := Button.new()
	btn_begin.text = "Begin automation"
	btn_begin.pressed.connect(_on_automation_begin_pressed)
	var btn_clear := Button.new()
	btn_clear.text = "Clear queue"
	btn_clear.pressed.connect(_on_automation_clear_queue_pressed)
	row_actions.add_child(btn_add)
	row_actions.add_child(btn_begin)
	row_actions.add_child(btn_clear)
	v.add_child(row_actions)
	_automation_follow_block = VBoxContainer.new()
	_automation_follow_block.visible = false
	_automation_follow_block.add_theme_constant_override("separation", 6)
	var lbl_follow := Label.new()
	lbl_follow.text = "Follow target (party):"
	lbl_follow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_automation_follow_block.add_child(lbl_follow)
	var opt_follow := OptionButton.new()
	opt_follow.custom_minimum_size = Vector2(200, 0)
	opt_follow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _option_popup_theme != null:
		opt_follow.get_popup().theme = _option_popup_theme
	elif theme != null:
		opt_follow.get_popup().theme = _build_option_popup_theme(theme as Theme)
	_wire_option_button_popup(opt_follow)
	_opt_follow_target = opt_follow
	_automation_follow_block.add_child(opt_follow)
	v.add_child(_automation_follow_block)
	margin.add_child(v)
	_d_automation_host.add_child(margin)
	if _opt_automation_task != null:
		_opt_automation_task.item_selected.connect(_on_automation_task_selected)
	_refresh_follow_target_options()
	_refresh_automation_follow_visibility()
	_refresh_automation_context_label()
	if _automation != null:
		_automation.set_dispatch_held(_current_runner_id, _chk_automation_queue_hold.button_pressed)


func _drafting_automation_character_id() -> StringName:
	return _resolve_runner_to_character_id(_current_runner_id)


func _automation_ui_log_character_id() -> StringName:
	var cid: StringName = _drafting_automation_character_id()
	if cid == &"":
		cid = _focus_character_id
	return cid


func _get_automation_task_type_from_ui() -> int:
	if _opt_automation_task == null:
		return AutomationSystem.TaskType.IDLE
	var i: int = _opt_automation_task.selected
	if i < 0:
		return AutomationSystem.TaskType.IDLE
	var m: Variant = _opt_automation_task.get_item_metadata(i)
	return int(m) if m != null else AutomationSystem.TaskType.IDLE


func _refresh_automation_follow_visibility() -> void:
	if _automation_follow_block == null or _opt_automation_task == null:
		return
	var tt: int = _get_automation_task_type_from_ui()
	_automation_follow_block.visible = tt == AutomationSystem.TaskType.FOLLOW_CHARACTER


func _on_automation_task_selected(_idx: int) -> void:
	_refresh_automation_follow_visibility()


func _resolve_follow_target_for_task() -> StringName:
	var self_cid: StringName = _drafting_automation_character_id()
	if _opt_follow_target != null and _opt_follow_target.item_count > 0:
		var sel_idx: int = clampi(_opt_follow_target.selected, 0, _opt_follow_target.item_count - 1)
		var meta: Variant = _opt_follow_target.get_item_metadata(sel_idx)
		if meta != null:
			var oid: StringName = StringName(str(meta))
			if oid != &"" and oid != self_cid:
				return oid
	if _selection_portrait_source == "world" and _selection_world_kind == "actor":
		var tid: StringName = _selection_world_id
		if tid != &"" and tid != self_cid:
			return tid
	return &""


func _resolve_assist_ally_for_task() -> StringName:
	var self_cid: StringName = _drafting_automation_character_id()
	if _selection_portrait_source == "world" and _selection_world_kind == "actor":
		var tid: StringName = _selection_world_id
		if tid != &"" and tid != self_cid:
			return tid
	return &""


func _on_automation_add_to_queue() -> void:
	if _automation == null:
		return
	var tt: int = _get_automation_task_type_from_ui()
	var t := AutomationSystem.AutomationTask.new()
	t.type = tt
	t.label = "ui_%s" % str(tt)
	t.interruptible = true
	match tt:
		AutomationSystem.TaskType.HUNT:
			var hunt_cid: StringName = _drafting_automation_character_id()
			var hctx: Dictionary = _attack_context_for(hunt_cid)
			var hm: String = str(hctx.get("mode", "none"))
			if hm in ["none", "casting_no_spell", "casting_support"]:
				_append_command_feed(
					"[ui] Hunt needs a melee, missile, or offensive spell setup (weapon + bolt selected).",
					_automation_ui_log_character_id(),
				)
				return
			t.priority = 2
			t.data["hunt_kills_target"] = 1
		AutomationSystem.TaskType.FOLLOW_CHARACTER:
			var target_id: StringName = _resolve_follow_target_for_task()
			if target_id == &"":
				_append_command_feed(
					"[ui] Follow needs another character — select one in the world (B.b) or the party dropdown.",
					_automation_ui_log_character_id(),
				)
				return
			t.priority = 2
			t.label = "follow:%s" % String(target_id)
			t.data["target_character_id"] = target_id
		AutomationSystem.TaskType.ASSIST_COMBAT:
			var ally: StringName = _resolve_assist_ally_for_task()
			if ally == &"":
				_append_command_feed(
					"[ui] Assist combat needs an ally — select another party character in the world (B.b).",
					_automation_ui_log_character_id(),
				)
				return
			t.priority = 3
			t.label = "assist:%s" % String(ally)
			t.data["ally_character_id"] = ally
		_:
			t.data["sim_ticks"] = 2
	_automation.enqueue_for(_current_runner_id, t)
	_append_command_feed(
		"[ui] Queued %s for runner %s" % [_automation_task_name(tt), String(_current_runner_id)],
		_automation_ui_log_character_id(),
	)


func _on_automation_begin_pressed() -> void:
	if _automation == null:
		return
	_automation.set_dispatch_held(_current_runner_id, false)
	if _chk_automation_queue_hold != null:
		_chk_automation_queue_hold.set_block_signals(true)
		_chk_automation_queue_hold.button_pressed = false
		_chk_automation_queue_hold.set_block_signals(false)
	_append_command_feed(
		"[ui] Automation dispatch started for runner %s." % String(_current_runner_id),
		_automation_ui_log_character_id(),
	)


func _on_automation_queue_hold_toggled(pressed: bool) -> void:
	if _automation == null:
		return
	_automation.set_dispatch_held(_current_runner_id, pressed)


func _on_automation_clear_queue_pressed() -> void:
	if _automation == null:
		return
	_automation.clear_queue(_current_runner_id)
	_append_command_feed(
		"[ui] Cleared automation queue for %s." % String(_current_runner_id),
		_automation_ui_log_character_id(),
	)


func _refresh_automation_context_label() -> void:
	if _lbl_automation_context == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Runner (Panel E): %s" % String(_current_runner_id))
	var self_cid: StringName = _drafting_automation_character_id()
	if self_cid != &"":
		lines.append("World body for runner: %s" % String(self_cid))
	if _selection_portrait_source == "world" and _selection_world_kind == "actor" and _selection_world_id != &"":
		var nm: String = String(_selection_world_id)
		if _registry != null:
			var dres: Resource = _registry.get_character(_selection_world_id)
			if dres != null:
				nm = str(dres.user_name)
		lines.append("B.b: %s (%s) — used for Follow / Assist target" % [nm, String(_selection_world_id)])
	elif _selection_portrait_source == "world" and _selection_world_kind == "enemy":
		lines.append("B.b: enemy — not valid as Follow / Assist ally")
	else:
		lines.append("B.b: select a party character in the world for Follow / Assist")
	_lbl_automation_context.text = "\n".join(lines)


func _sync_automation_hold_checkbox() -> void:
	if _chk_automation_queue_hold == null or _automation == null:
		return
	_chk_automation_queue_hold.set_block_signals(true)
	_chk_automation_queue_hold.button_pressed = _automation.is_dispatch_held(_current_runner_id)
	_chk_automation_queue_hold.set_block_signals(false)


func _sync_automation_to_panel_b_selection() -> void:
	if _focus_character_id == &"":
		return
	_sync_runner_dropdown_to_id(_focus_character_id)


func _sync_runner_dropdown_to_id(cid: StringName) -> void:
	if cid == &"":
		return
	_current_runner_id = cid
	if _automation != null:
		_automation.ensure_runner(cid)
	_automation_runner_select.set_block_signals(true)
	var found: bool = false
	for i in range(_automation_runner_select.item_count):
		var m: Variant = _automation_runner_select.get_item_metadata(i)
		if StringName(str(m)) == cid:
			_automation_runner_select.select(i)
			found = true
			break
	if not found:
		_automation_runner_select.select(maxi(0, _automation_runner_select.item_count - 1))
	_automation_runner_select.set_block_signals(false)
	_refresh_automation_panel()
	_refresh_follow_target_options()
	_refresh_automation_follow_visibility()


func _on_party_add_pressed(slot_index: int) -> void:
	var roster_sz: int = _roster_ids().size()
	if roster_sz >= _Sch.MAX_PARTY_SIZE:
		_append_command_feed("[ui] Party is full.")
		return
	if slot_index != roster_sz:
		_append_command_feed("[ui] Fill party slots in order — use the next +.")
		return
	_ensure_creation_dialog()
	if _creation_name_edit != null:
		_creation_name_edit.text = ""
	_creation_dialog.popup_centered()
	## First layout pass often leaves the native window at a bad default height; shrink to content + OK row.
	_creation_dialog.call_deferred(&"reset_size")
	call_deferred(&"_refresh_creation_alloc_ui")


func _grant_all_spell_scrolls_for_testing(character_id: StringName) -> void:
	if _inventory == null:
		return
	for sid: StringName in MagicRules.all_scroll_teach_spell_ids():
		var key: String = String(sid).replace("/", "_")
		var iid: StringName = StringName("scroll_%s" % key)
		if _catalog != null and _catalog.has_method(&"has_item") and not _catalog.has_item(iid):
			continue
		_inventory.try_add_item(character_id, iid, 1)


func _on_inventory_slot_context_menu_requested(kind: String, payload: Dictionary, at_global: Vector2) -> void:
	var sel: Dictionary = {}
	if kind == "bag":
		var idx: int = int(payload.get("index", -1))
		var iid: String = ""
		var qty: int = 0
		if _inventory != null and _focus_character_id != &"":
			var cell: Variant = _inventory.get_cell(_focus_character_id, idx)
			if cell is Dictionary:
				var d: Dictionary = cell as Dictionary
				iid = String(d.get("item_id", ""))
				qty = int(d.get("quantity", 1))
		sel = {"source": "bag", "index": idx, "item_id": iid, "quantity": qty}
	elif kind == "equip":
		var slot_s: String = String(payload.get("equip_slot", ""))
		var eiid: String = ""
		if _equipment != null and _focus_character_id != &"" and not slot_s.is_empty():
			eiid = String(_equipment.get_equipped_item(_focus_character_id, StringName(slot_s)))
		sel = {"source": "equip", "equip_slot": slot_s, "item_id": eiid, "quantity": 1}
	else:
		return
	if _inventory_panel != null and _inventory_panel.has_method(&"set_programmatic_selection"):
		_inventory_panel.set_programmatic_selection(sel)
	else:
		_selection_inventory_snapshot = sel.duplicate()
		_selection_portrait_source = "inventory"
		_set_ui_attack_active(false)
		_clear_player_spell_cast()
		_refresh_selection_portrait()
	_show_selection_context_menu_at(at_global)


func _ensure_selection_actions_popup() -> void:
	if _selection_actions_popup != null:
		return
	_selection_actions_popup = PopupMenu.new()
	if theme != null:
		_selection_actions_popup.theme = theme
	add_child(_selection_actions_popup)
	_selection_actions_popup.id_pressed.connect(_on_selection_actions_id_pressed)


func _show_selection_context_menu_at(global_position: Vector2) -> void:
	_ensure_selection_actions_popup()
	var pm: PopupMenu = _selection_actions_popup
	pm.clear()
	var added: int = 0
	if _selection_portrait_source == "inventory" and not _selection_inventory_snapshot.is_empty():
		var src: String = String(_selection_inventory_snapshot.get("source", ""))
		if src == "bag":
			var iid_b: String = String(_selection_inventory_snapshot.get("item_id", ""))
			if not iid_b.is_empty() and _catalog != null:
				var def_b: Resource = _catalog.get_definition(StringName(iid_b)) as Resource
				if def_b != null:
					var es: String = str(def_b.equip_slot)
					if not es.is_empty():
						pm.add_item("Equip", _SEL_CTX_EQUIP)
						added += 1
					if not String(def_b.scroll_teaches_spell).strip_edges().is_empty():
						pm.add_item("Read scroll", _SEL_CTX_READ_SCROLL)
						added += 1
		elif src == "equip":
			var eiid: String = String(_selection_inventory_snapshot.get("item_id", ""))
			if not eiid.is_empty():
				pm.add_item("Unequip", _SEL_CTX_UNEQUIP)
				added += 1
		pm.add_item("Inspect", _SEL_CTX_INSPECT)
		added += 1
	elif _selection_portrait_source == "world" and _selection_world_kind != "none" and _selection_world_node != null:
		pm.add_item("Inspect", _SEL_CTX_INSPECT)
		added += 1
		if _selection_world_kind == "enemy":
			var ctx: Dictionary = _attack_context_for(_focus_character_id)
			var mode: String = str(ctx.get("mode", "none"))
			var can_strike: bool = mode in ["melee", "missile", "casting"]
			var casting: bool = WeaponItemUtils.is_casting_weapon(WeaponItemUtils.main_hand_definition(_focus_character_id, _equipment, _catalog))
			var cast_busy: bool = _spell_cast_busy and _spell_cast_attacker_id == _focus_character_id
			var atk_lbl: String = (
				"Casting…"
				if (casting and cast_busy)
				else ("Stop attack" if _ui_attack_active else ("Cast" if casting else "Attack"))
			)
			pm.add_item(atk_lbl, _SEL_CTX_ATTACK_CAST)
			var atk_ix: int = pm.get_item_index(_SEL_CTX_ATTACK_CAST)
			if atk_ix >= 0:
				pm.set_item_disabled(atk_ix, not can_strike or (casting and cast_busy))
			added += 1
		elif _selection_world_kind == "actor":
			var ctx_a: Dictionary = _attack_context_for(_focus_character_id)
			var mode_a: String = str(ctx_a.get("mode", "none"))
			var casting_a: bool = WeaponItemUtils.is_casting_weapon(
				WeaponItemUtils.main_hand_definition(_focus_character_id, _equipment, _catalog),
			)
			var cast_on_actor: bool = casting_a and (
				mode_a == "casting_support"
				or (mode_a == "casting" and _selection_world_id != _focus_character_id)
			)
			if cast_on_actor:
				var can_cast_a: bool = mode_a == "casting_support" or mode_a == "casting"
				var cast_busy_a: bool = _spell_cast_busy and _spell_cast_attacker_id == _focus_character_id
				var atk_lbl_a: String = "Casting…" if cast_busy_a else "Cast"
				pm.add_item(atk_lbl_a, _SEL_CTX_ATTACK_CAST)
				var atk_ix_a: int = pm.get_item_index(_SEL_CTX_ATTACK_CAST)
				if atk_ix_a >= 0:
					pm.set_item_disabled(atk_ix_a, not can_cast_a or cast_busy_a)
				added += 1
		if _focus_character_id != &"" and _registry != null:
			var fd: Resource = _registry.get_character(_focus_character_id)
			var wa: Node = _world_actor_by_id.get(_focus_character_id) as Node
			if fd != null and bool(fd.is_logged_in) and wa != null:
				var med_lbl: String = "Stop meditation" if bool(wa.is_meditating) else "Meditate"
				pm.add_item(med_lbl, _SEL_CTX_MEDITATE)
				added += 1
	if added <= 0:
		return
	pm.position = Vector2i(global_position)
	pm.reset_size()
	pm.popup()


func _on_selection_actions_id_pressed(menu_id: int) -> void:
	match menu_id:
		_SEL_CTX_INSPECT:
			_on_bc_inspect_pressed()
		_SEL_CTX_EQUIP, _SEL_CTX_UNEQUIP:
			_on_bb_equip_pressed()
		_SEL_CTX_READ_SCROLL:
			_on_bb_read_scroll_pressed()
		_SEL_CTX_ATTACK_CAST:
			_on_bc_attack_pressed()
		_SEL_CTX_MEDITATE:
			_on_bc_meditate_pressed()


func _on_bb_read_scroll_pressed() -> void:
	if _selection_portrait_source != "inventory":
		return
	var src: String = String(_selection_inventory_snapshot.get("source", ""))
	if src != "bag":
		return
	var idx: int = int(_selection_inventory_snapshot.get("index", -1))
	if idx < 0:
		return
	try_read_scroll_from_bag(idx)


func try_read_scroll_from_bag(bag_index: int) -> void:
	if _focus_character_id == &"" or _inventory == null or _catalog == null or _registry == null:
		return
	var cell: Variant = _inventory.get_cell(_focus_character_id, bag_index)
	if cell == null or not (cell is Dictionary):
		return
	var d: Dictionary = cell as Dictionary
	var raw_id: StringName = d.get("item_id", &"") as StringName
	var def: Resource = _catalog.get_definition(raw_id)
	if def == null:
		return
	var teach: String = String(def.scroll_teaches_spell).strip_edges()
	if teach.is_empty():
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null or not data.has_method(&"learn_spell"):
		return
	if not data.learn_spell(StringName(teach)):
		_append_command_feed("[ui] Already know %s." % MagicRules.spell_display_name(StringName(teach)))
		return
	_inventory.try_take_single(_focus_character_id, bag_index)
	_append_command_feed("[ui] Learned %s from scroll." % MagicRules.spell_display_name(StringName(teach)))
	if _inventory_panel != null and _inventory_panel.has_method("refresh"):
		_inventory_panel.refresh()
	if _stats != null:
		_stats.invalidate(_focus_character_id)
	_refresh_panel_b_auxiliary()


func _on_equipment_changed_for_b_panels(character_id: StringName) -> void:
	if character_id == _focus_character_id:
		_refresh_panel_b_auxiliary()


func _on_party_card_pressed(slot_index: int) -> void:
	_selected_card_slot = slot_index
	var card: Node = _party_cards[slot_index] if slot_index >= 0 and slot_index < _party_cards.size() else null
	if card == null:
		_sync_selection_visual_only()
		return
	if not card.has_method("is_filled") or not card.is_filled():
		_sync_selection_visual_only()
		return
	_focus_character_id = card.get_character_id()
	if _inventory_panel != null and _inventory_panel.has_method("switch_character"):
		_inventory_panel.switch_character(_focus_character_id)
	_sync_selection_visual_only()
	_sync_runner_dropdown_to_id(_focus_character_id)
	_rebuild_progression_panels()
	_refresh_hud_vitals()
	_refresh_login_button_states()
	_apply_world_control_focus()
	_refresh_panel_b_auxiliary()
	_append_command_feed("[ui] Panel B → %s" % String(_focus_character_id))
	_refresh_feed_labels()


func _sync_selection_from_focus() -> void:
	if _focus_character_id == &"":
		_sync_selection_visual_only()
		return
	for i in range(_party_cards.size()):
		var card: Node = _party_cards[i]
		if card.has_method("get_character_id") and card.get_character_id() == _focus_character_id:
			_selected_card_slot = i
			break
	_sync_selection_visual_only()


func _sync_selection_visual_only() -> void:
	for j in range(_party_cards.size()):
		var c: Node = _party_cards[j]
		if c.has_method("set_selected"):
			c.set_selected(j == _selected_card_slot)


func _populate_runner_options() -> void:
	_automation_runner_select.set_block_signals(true)
	_option_button_clear_all(_automation_runner_select)
	if _registry != null and _registry.has_method("list_character_ids"):
		for cid in _registry.list_character_ids():
			_automation_runner_select.add_item("Char: %s" % String(cid))
			_automation_runner_select.set_item_metadata(_automation_runner_select.item_count - 1, cid)
	if _group_system != null and _group_system.has_method("list_group_ids"):
		for gid in _group_system.list_group_ids():
			_automation_runner_select.add_item("Group: %s" % String(gid))
			_automation_runner_select.set_item_metadata(
				_automation_runner_select.item_count - 1,
				AutomationSystem.group_runner_id(gid),
			)
	_automation_runner_select.add_item("Default runner")
	_automation_runner_select.set_item_metadata(_automation_runner_select.item_count - 1, &"default")
	_automation_runner_select.set_block_signals(false)
	if _focus_character_id != &"":
		_sync_runner_dropdown_to_id(_focus_character_id)
	elif _automation_runner_select.item_count > 0:
		_automation_runner_select.set_block_signals(true)
		_automation_runner_select.select(0)
		var m0: Variant = _automation_runner_select.get_item_metadata(0)
		if m0 is StringName:
			_current_runner_id = m0
		elif m0 is String:
			_current_runner_id = StringName(m0)
		else:
			_current_runner_id = &"default"
		if _automation != null:
			_automation.ensure_runner(_current_runner_id)
		_automation_runner_select.set_block_signals(false)
		_refresh_automation_panel()


func _on_automation_runner_selected(index: int) -> void:
	var meta: Variant = _automation_runner_select.get_item_metadata(index)
	if meta is StringName:
		_current_runner_id = meta
	elif meta is String:
		_current_runner_id = StringName(meta)
	else:
		_current_runner_id = &"default"
	if _automation != null:
		_automation.ensure_runner(_current_runner_id)
	_refresh_automation_panel()
	_refresh_follow_target_options()
	_refresh_automation_follow_visibility()


func _on_automation_runner_queue_changed(runner_id: StringName) -> void:
	if runner_id == _current_runner_id:
		_refresh_automation_panel()


func _on_automation_queue_changed() -> void:
	_refresh_automation_status()
	_refresh_automation_panel()


func _on_automation_queue_reorder(from_index: int, to_index: int) -> void:
	if _automation == null:
		return
	if from_index == to_index:
		_refresh_automation_panel()
		return
	_automation.reorder_queue_relative(_current_runner_id, from_index, to_index)
	_refresh_automation_panel()


func _on_automation_queue_continuous_toggled(pressed: bool, task_id: int) -> void:
	if _automation == null:
		return
	_automation.set_queue_task_continuous(_current_runner_id, task_id, pressed)


func _on_automation_interrupt_pressed() -> void:
	if _automation == null:
		return
	_automation.interrupt_active(_current_runner_id)


func _on_automation_resume_pressed() -> void:
	if _automation == null:
		return
	_automation.resume_suspended(_current_runner_id)


func _refresh_automation_status() -> void:
	if _automation == null:
		_automation_status.text = "Summary: (no automation system)"
		return
	var ids: PackedStringArray = _automation.list_runner_ids()
	var busy: int = 0
	for rid in ids:
		if _automation.get_active_task_for(rid) != null:
			busy += 1
	_automation_status.text = "Summary: %d runner(s), %d active" % [ids.size(), busy]


func _refresh_automation_panel() -> void:
	if _automation == null:
		_automation_active.text = "—"
		for c in _automation_queue_host.get_children():
			c.queue_free()
		_automation_previous.clear()
		_automation_status_log.clear()
		return
	var active: Variant = _automation.get_active_task_for(_current_runner_id)
	if active != null and active is AutomationSystem.AutomationTask:
		var at: AutomationSystem.AutomationTask = active as AutomationSystem.AutomationTask
		_automation_active.text = "[b]%s[/b]  prio=%d  id=%d\n[i]%s[/i]" % [
			_automation_task_name(at.type),
			at.priority,
			at.task_id,
			at.label,
		]
	else:
		var susp: Array = _automation.get_suspended_snapshot_for(_current_runner_id)
		if not susp.is_empty():
			var t: AutomationSystem.AutomationTask = susp[susp.size() - 1] as AutomationSystem.AutomationTask
			_automation_active.text = "(none active; last suspended: [i]%s[/i])" % t.label
		else:
			_automation_active.text = "—"

	for c in _automation_queue_host.get_children():
		c.queue_free()
	var q: Array = _automation.get_queue_snapshot_for(_current_runner_id)
	var qi: int = 0
	for tq in q:
		if tq is AutomationSystem.AutomationTask:
			var qt: AutomationSystem.AutomationTask = tq as AutomationSystem.AutomationTask
			var row := HBoxContainer.new()
			row.set_script(_AutomationQueueRowScr)
			row.row_index = qi
			row.add_theme_constant_override("separation", 6)
			row.custom_minimum_size.y = 28
			var chk_loop := CheckBox.new()
			chk_loop.text = "Loop"
			chk_loop.tooltip_text = "When checked, this task is queued again after it completes successfully."
			chk_loop.focus_mode = Control.FOCUS_NONE
			chk_loop.set_block_signals(true)
			chk_loop.button_pressed = qt.continuous
			chk_loop.set_block_signals(false)
			var tid_loop: int = qt.task_id
			chk_loop.toggled.connect(_on_automation_queue_continuous_toggled.bind(tid_loop))
			var lbl_q := Label.new()
			lbl_q.set_script(_AutomationQueueTaskLabelScr)
			lbl_q.row_index = qi
			lbl_q.text = "%2d  %s  %s" % [qt.priority, _automation_task_name(qt.type), qt.label]
			lbl_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_q.mouse_default_cursor_shape = Control.CURSOR_MOVE
			row.add_child(chk_loop)
			row.add_child(lbl_q)
			_automation_queue_host.add_child(row)
			qi += 1

	_automation_previous.clear()
	var prev: Array = _automation.get_previous_tasks_for(_current_runner_id)
	for i in range(prev.size() - 1, -1, -1):
		var row: Dictionary = prev[i] as Dictionary
		var ok: bool = bool(row.get("success", false))
		var lbl: String = str(row.get("label", ""))
		var typ: int = int(row.get("type", 0))
		_automation_previous.add_item("%s  %s  %s" % ["ok" if ok else "x", _automation_task_name(typ), lbl])

	_automation_status_log.clear()
	for line in _automation.get_status_messages_for(_current_runner_id):
		_automation_status_log.add_item(line)

	_refresh_automation_context_label()
	_sync_automation_hold_checkbox()


func _automation_task_name(task_type: int) -> String:
	match task_type:
		AutomationSystem.TaskType.IDLE:
			return "IDLE"
		AutomationSystem.TaskType.MOVE_TO:
			return "MOVE_TO"
		AutomationSystem.TaskType.INTERACT:
			return "INTERACT"
		AutomationSystem.TaskType.WAIT:
			return "WAIT"
		AutomationSystem.TaskType.NAVIGATE_MAP:
			return "NAV_MAP"
		AutomationSystem.TaskType.USE_PORTAL:
			return "PORTAL"
		AutomationSystem.TaskType.HUNT:
			return "HUNT"
		AutomationSystem.TaskType.SEARCH_LOOT:
			return "LOOT"
		AutomationSystem.TaskType.COMPLETE_QUEST:
			return "QUEST"
		AutomationSystem.TaskType.SELL_EXCESS_LOOT:
			return "SELL"
		AutomationSystem.TaskType.SHARE_LOOT_GROUP:
			return "SHARE"
		AutomationSystem.TaskType.SUPPORT_ALLY:
			return "SUPPORT"
		AutomationSystem.TaskType.FOLLOW_CHARACTER:
			return "FOLLOW"
		AutomationSystem.TaskType.ASSIST_COMBAT:
			return "ASSIST"
		_:
			return "UNKNOWN"


func _container_local_to_world_2d(container_local: Vector2) -> Vector2:
	if _world_viewport == null or _world_viewport_container == null:
		return Vector2.ZERO
	var csize: Vector2 = _world_viewport_container.get_rect().size
	if csize.x <= 0.0 or csize.y <= 0.0:
		return Vector2.ZERO
	var scale_xy: Vector2 = Vector2(_world_viewport.size) / csize
	var in_vp: Vector2 = container_local * scale_xy
	var xf: Transform2D = _world_viewport.get_canvas_transform()
	return xf.affine_inverse() * in_vp


func _on_world_viewport_container_gui_input(event: InputEvent) -> void:
	if _world_viewport == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var world_pr: Vector2 = _container_local_to_world_2d(mb.position)
			_pick_world_at_world_pos(world_pr)
			_show_selection_context_menu_at(mb.global_position)
			_world_viewport_container.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_focus_camera_zoom_wheel(true)
			_world_viewport_container.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_focus_camera_zoom_wheel(false)
			_world_viewport_container.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_p: Vector2 = _container_local_to_world_2d(mb.position)
			_pick_world_at_world_pos(world_p)
			_world_viewport_container.accept_event()


func _apply_focus_camera_zoom_wheel(zoom_in: bool) -> void:
	if _focus_character_id == &"":
		return
	var wa: Node = _world_actor_by_id.get(_focus_character_id) as Node
	if wa != null and wa.has_method(&"adjust_camera_zoom_wheel"):
		wa.adjust_camera_zoom_wheel(zoom_in)


func _pick_world_at_world_pos(world_p: Vector2) -> void:
	var pick_r2: float = float(GameConstants.TILE_SIZE_PX * GameConstants.TILE_SIZE_PX)
	var best_node: Node2D = null
	var best_d2: float = INF
	var best_kind: String = "none"
	var best_id: StringName = &""
	for cid in _world_actor_by_id.keys():
		var n: Node = _world_actor_by_id[cid]
		if n is Node2D:
			if not _world_viewport.is_ancestor_of(n):
				continue
			var d2: float = world_p.distance_squared_to((n as Node2D).global_position)
			if d2 < best_d2:
				best_d2 = d2
				best_node = n as Node2D
				best_kind = "actor"
				best_id = cid
	for en in get_tree().get_nodes_in_group(&"combat_enemies"):
		if not (en is Node2D):
			continue
		var e2d: Node2D = en as Node2D
		if not _world_viewport.is_ancestor_of(e2d):
			continue
		var d2e: float = world_p.distance_squared_to(e2d.global_position)
		if d2e < best_d2:
			best_d2 = d2e
			best_node = e2d
			best_kind = "enemy"
			best_id = StringName(str(e2d.get_instance_id()))
	if best_node == null or best_d2 > pick_r2:
		_selection_world_kind = "none"
		_selection_world_id = &""
		_selection_world_node = null
	else:
		_selection_world_kind = best_kind
		_selection_world_id = best_id
		_selection_world_node = best_node
	_selection_portrait_source = "world"
	_refresh_selection_portrait()


func _on_inventory_panel_setup_completed() -> void:
	if _inventory_panel == null or not is_instance_valid(_inventory_panel):
		return
	if _inventory_panel.has_signal(&"bag_slot_double_clicked"):
		var on_dbl := Callable(self, "try_read_scroll_from_bag")
		if not _inventory_panel.is_connected(&"bag_slot_double_clicked", on_dbl):
			_inventory_panel.connect(&"bag_slot_double_clicked", on_dbl)
	if _inventory_panel.has_signal(&"slot_context_menu_requested"):
		var on_ctx := Callable(self, "_on_inventory_slot_context_menu_requested")
		if not _inventory_panel.is_connected(&"slot_context_menu_requested", on_ctx):
			_inventory_panel.connect(&"slot_context_menu_requested", on_ctx)
	if _equipment != null and _equipment.has_signal(&"equipment_changed"):
		var on_eq := Callable(self, "_on_equipment_changed_for_b_panels")
		if not _equipment.is_connected(&"equipment_changed", on_eq):
			_equipment.equipment_changed.connect(_on_equipment_changed_for_b_panels)
	if _inventory_panel.has_signal(&"slot_selection_changed"):
		var on_slot := Callable(self, "_on_inventory_slot_selection_changed")
		if not _inventory_panel.is_connected(&"slot_selection_changed", on_slot):
			_inventory_panel.connect(&"slot_selection_changed", on_slot)
	_refresh_party_cards()
	_sync_selection_from_focus()
	_sync_automation_to_panel_b_selection()
	_rebuild_progression_panels()
	_refresh_hud_vitals()
	_refresh_login_button_states()
	_sync_world_actors()
	_refresh_group_selector()
	_populate_runner_options()
	_refresh_follow_target_options()
	_refresh_panel_b_auxiliary()
	_refresh_feed_labels()


func _on_inventory_slot_selection_changed(selection: Dictionary) -> void:
	if String(selection.get("source", "none")) == "none":
		_selection_inventory_snapshot = {}
		if _selection_portrait_source == "inventory":
			_selection_portrait_source = "none"
	else:
		_selection_inventory_snapshot = selection.duplicate()
		_selection_portrait_source = "inventory"
	_set_ui_attack_active(false)
	_clear_player_spell_cast()
	_refresh_selection_portrait()


func _deferred_sync_follow_dropdown_from_portrait() -> void:
	_sync_follow_dropdown_selection_from_panel_b()


func _refresh_selection_portrait() -> void:
	if _bb_title == null or _bb_subtitle == null or _bb_portrait == null or _bb_fallback == null:
		return
	call_deferred(&"_deferred_sync_follow_dropdown_from_portrait")
	call_deferred(&"_refresh_automation_context_label")
	if _selection_portrait_source == "inventory" and not _selection_inventory_snapshot.is_empty():
		var src: String = String(_selection_inventory_snapshot.get("source", ""))
		var title: String = "Inventory"
		var sub: String = ""
		var col: Color = Color(0.22, 0.24, 0.3, 1.0)
		if src == "bag":
			var idx: int = int(_selection_inventory_snapshot.get("index", -1))
			var iid: String = String(_selection_inventory_snapshot.get("item_id", ""))
			var qty: int = int(_selection_inventory_snapshot.get("quantity", 0))
			title = "Bag slot %d" % idx if idx >= 0 else "Bag"
			if iid.is_empty():
				sub = "Empty slot"
			else:
				sub = "%s × %d" % [iid, qty]
				col = _portrait_color_for(StringName(iid))
		elif src == "equip":
			var eslot: String = String(_selection_inventory_snapshot.get("equip_slot", ""))
			var eiid: String = String(_selection_inventory_snapshot.get("item_id", ""))
			title = "Equipment: %s" % eslot if not eslot.is_empty() else "Equipment"
			sub = eiid if not eiid.is_empty() else "Empty"
			if not eiid.is_empty():
				col = _portrait_color_for(StringName(eiid))
		_bb_title.text = title
		_bb_subtitle.text = sub
		_bb_portrait.texture = null
		_bb_fallback.color = col
		_bb_fallback.visible = true
		_sync_ui_attack_to_selection()
		_refresh_panel_b_auxiliary()
		return
	if _selection_portrait_source == "world" and _selection_world_kind != "none" and _selection_world_node != null:
		if _selection_world_kind == "actor":
			var aid: StringName = _selection_world_id
			var aname: String = String(aid)
			if _registry != null:
				var dres: Resource = _registry.get_character(aid)
				if dres != null:
					aname = str(dres.user_name)
			_bb_title.text = aname
			_bb_subtitle.text = "Character · %s" % String(aid)
			_bb_portrait.texture = null
			_bb_fallback.color = _portrait_color_for(aid)
			_bb_fallback.visible = true
			_sync_ui_attack_to_selection()
			_refresh_panel_b_auxiliary()
			return
		if _selection_world_kind == "enemy":
			_bb_title.text = "Enemy"
			if _selection_world_node.get_script() == _CombatTestEnemyScr:
				## Object.get() only accepts the property name; use fallbacks manually.
				var cur: float = _node_get_float(_selection_world_node, &"current_health", 0.0)
				var mx: float = _node_get_float(_selection_world_node, &"max_health", 1.0)
				var xp: int = _node_get_int(_selection_world_node, &"xp_reward", 0)
				_bb_subtitle.text = "HP %.0f / %.0f · +%d XP" % [cur, mx, xp]
			else:
				_bb_subtitle.text = String(_selection_world_node.name)
			_bb_portrait.texture = null
			_bb_fallback.color = Color(0.62, 0.22, 0.22, 1.0)
			_bb_fallback.visible = true
			_sync_ui_attack_to_selection()
			_refresh_panel_b_auxiliary()
			return
	_bb_title.text = "Nothing selected"
	_bb_subtitle.text = "Click world or inventory. Shift+click bag/equip to use."
	_bb_portrait.texture = null
	_bb_fallback.color = Color(0.22, 0.24, 0.3, 1.0)
	_bb_fallback.visible = true
	_sync_ui_attack_to_selection()
	_refresh_panel_b_auxiliary()


func _set_ui_attack_active(active: bool) -> void:
	_ui_attack_active = active
	if not active:
		_ui_attack_enemy_iid = 0
		if _focus_character_id != &"":
			var act: Node = _world_actor_by_id.get(_focus_character_id) as Node
			if act != null and act.has_method("set_hunt_navigation_active"):
				act.call("set_hunt_navigation_active", false)
	_refresh_panel_b_auxiliary()


func _resolve_ui_attack_enemy() -> Node2D:
	if _ui_attack_enemy_iid == 0:
		return null
	var o: Object = instance_from_id(_ui_attack_enemy_iid)
	if o is Node2D and is_instance_valid(o) and (o as Node).is_inside_tree():
		return o as Node2D
	return null


func _clear_player_spell_cast() -> void:
	_spell_cast_busy = false
	_spell_cast_elapsed_ms = 0.0
	_spell_cast_duration_ms = 0.0
	_spell_cast_target_iid = 0
	_spell_cast_attacker_id = &""
	_spell_cast_ctx.clear()


func _try_start_player_spell_cast() -> void:
	if _spell_cast_busy:
		_append_command_feed("[ui] Already casting.")
		return
	if _focus_character_id == &"" or _selection_world_node == null or not (_selection_world_node is Node2D):
		return
	var is_enemy: bool = _selection_world_kind == "enemy"
	var is_actor: bool = _selection_world_kind == "actor"
	if not is_enemy and not is_actor:
		return
	var ctx: Dictionary = _attack_context_for(_focus_character_id)
	var mode: String = str(ctx.get("mode", "none"))
	if mode != "casting" and mode != "casting_support":
		return
	if mode == "casting_no_spell":
		_append_command_feed("[ui] Select a spell in Panel B.d.")
		return
	if is_enemy and mode == "casting_support":
		_append_command_feed("[ui] Choose a combat bolt to use on enemies.")
		return
	if is_actor:
		if mode == "casting" and _selection_world_id == _focus_character_id:
			_append_command_feed("[ui] Pick another character as the bolt target.")
			return
	var target: Node2D = _selection_world_node as Node2D
	var attacker: Node2D = _world_actor_by_id.get(_focus_character_id) as Node2D
	if attacker == null:
		_append_command_feed("[ui] Log in to cast.")
		return
	var reach: float = float(ctx.get("range_px", _SPELL_CAST_RANGE_PX))
	if attacker.global_position.distance_squared_to(target.global_position) > reach * reach:
		_append_command_feed("[ui] Out of range to cast.")
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null:
		return
	var mc: int = int(ctx.get("mana_cost", 0))
	if mc > 0 and float(data.current_mana) < float(mc):
		_append_command_feed("[ui] Not enough mana to cast.")
		return
	_set_ui_attack_active(false)
	_spell_cast_busy = true
	_spell_cast_elapsed_ms = 0.0
	_spell_cast_duration_ms = float(MagicRules.spell_cast_time_ms(int(ctx.get("spell_tier", 1))))
	_spell_cast_target_iid = target.get_instance_id()
	_spell_cast_attacker_id = _focus_character_id
	_spell_cast_ctx = ctx.duplicate(true)
	var sid: StringName = ctx.get("spell_id", &"") as StringName
	_append_command_feed("[ui] Casting %s…" % MagicRules.spell_display_name(sid))
	_refresh_panel_b_auxiliary()


func _tick_player_spell_cast(delta: float) -> void:
	if not _spell_cast_busy:
		return
	if _focus_character_id != _spell_cast_attacker_id:
		var caster: StringName = _spell_cast_attacker_id
		_clear_player_spell_cast()
		_append_command_feed("[ui] Cast cancelled.", caster)
		_refresh_panel_b_auxiliary()
		return
	var tgt: Node2D
	var o: Object = instance_from_id(_spell_cast_target_iid)
	if o is Node2D and is_instance_valid(o) and (o as Node).is_inside_tree():
		tgt = o as Node2D
	if tgt == null:
		var caster_lt: StringName = _spell_cast_attacker_id
		_clear_player_spell_cast()
		_append_command_feed("[ui] Cast lost target.", caster_lt)
		_refresh_panel_b_auxiliary()
		return
	var attacker: Node2D = _world_actor_by_id.get(_spell_cast_attacker_id) as Node2D
	if attacker == null:
		var caster_na: StringName = _spell_cast_attacker_id
		_clear_player_spell_cast()
		_append_command_feed("[ui] Cast cancelled.", caster_na)
		_refresh_panel_b_auxiliary()
		return
	var reach: float = float(_spell_cast_ctx.get("range_px", _SPELL_CAST_RANGE_PX))
	if attacker.global_position.distance_squared_to(tgt.global_position) > reach * reach:
		var caster_ir: StringName = _spell_cast_attacker_id
		_clear_player_spell_cast()
		_append_command_feed("[ui] Cast interrupted (out of range).", caster_ir)
		_refresh_panel_b_auxiliary()
		return
	_spell_cast_elapsed_ms += delta * 1000.0
	if _spell_cast_elapsed_ms < _spell_cast_duration_ms:
		return
	var data: Resource = _registry.get_character(_spell_cast_attacker_id)
	if data == null:
		_clear_player_spell_cast()
		_refresh_panel_b_auxiliary()
		return
	var sid: StringName = _spell_cast_ctx.get("spell_id", &"") as StringName
	var tier: int = int(_spell_cast_ctx.get("spell_tier", 1))
	var mc_skill: float = 0.0
	var ms_skill: float = 0.0
	if _stats != null and _equipment != null:
		var st_cast: Dictionary = _stats.get_effective_stats(_spell_cast_attacker_id, data, _equipment)
		var sm: Dictionary = st_cast.get("skill_modifiers", {}) as Dictionary
		mc_skill = float(sm.get(_Sch.SKILL_MAGIC_COMBAT, 0.0))
		ms_skill = float(sm.get(_Sch.SKILL_MAGIC_SUPPORT, 0.0))
	elif _balance is CharacterBalanceConfig:
		var cfg_mc: CharacterBalanceConfig = _balance as CharacterBalanceConfig
		var rmap: Dictionary = _merged_skill_ranks_for_progression(data)
		mc_skill = cfg_mc.get_skill_total_modifier(
			StringName(_Sch.SKILL_MAGIC_COMBAT),
			data.attributes,
			int(rmap.get(_Sch.SKILL_MAGIC_COMBAT, 0)),
		)
		ms_skill = cfg_mc.get_skill_total_modifier(
			StringName(_Sch.SKILL_MAGIC_SUPPORT),
			data.attributes,
			int(rmap.get(_Sch.SKILL_MAGIC_SUPPORT, 0)),
		)
	var fizzle_p: float = MagicRules.spell_resolve_fizzle_probability(mc_skill, ms_skill, sid, tier)
	var fizzled: bool = randf() < fizzle_p
	if fizzled:
		var caster_fz: StringName = _spell_cast_attacker_id
		_append_command_feed(
			"[ui] Fizzle! %s did not resolve." % MagicRules.spell_display_name(sid),
			caster_fz,
		)
		_clear_player_spell_cast()
		_refresh_panel_b_auxiliary()
		return
	_perform_melee_against_node(_spell_cast_attacker_id, tgt, true, "[cast]", _spell_cast_ctx, true)
	_clear_player_spell_cast()
	_refresh_panel_b_auxiliary()


func _sync_ui_attack_to_selection() -> void:
	if not _ui_attack_active:
		return
	if _selection_portrait_source != "world" or _selection_world_node == null:
		_set_ui_attack_active(false)
		return
	var ctx: Dictionary = _attack_context_for(_focus_character_id)
	var mode: String = str(ctx.get("mode", "none"))
	var casting_weapon: bool = WeaponItemUtils.is_casting_weapon(
		WeaponItemUtils.main_hand_definition(_focus_character_id, _equipment, _catalog),
	)
	var ok: bool = false
	if _selection_world_kind == "enemy":
		ok = mode in ["melee", "missile", "casting"]
	elif _selection_world_kind == "actor":
		ok = casting_weapon and (mode == "casting_support" or mode == "casting")
	if not ok:
		_set_ui_attack_active(false)
		return
	var sel_iid: int = _selection_world_node.get_instance_id()
	if _ui_attack_enemy_iid != sel_iid:
		_ui_attack_enemy_iid = sel_iid
		_ui_attack_last_strike_ms = 0


func _tick_ui_directed_attack(_delta: float) -> void:
	if not _ui_attack_active or _focus_character_id == &"":
		return
	var ctx_mode: Dictionary = _attack_context_for(_focus_character_id)
	if str(ctx_mode.get("mode", "")) in ["casting", "casting_support"]:
		return
	var enemy: Node2D = _resolve_ui_attack_enemy()
	if enemy == null:
		_set_ui_attack_active(false)
		return
	var actor: Node = _world_actor_by_id.get(_focus_character_id)
	if actor == null or not (actor is Node2D):
		return
	var dist: float = (actor as Node2D).global_position.distance_to(enemy.global_position)
	var ui_reach: float = float(_attack_context_for(_focus_character_id).get("range_px", _MELEE_RANGE_PX))
	if actor.has_method("set_hunt_navigation_active") and actor.has_method("update_hunt_navigation_goal"):
		if dist > ui_reach * 0.92:
			actor.call("set_hunt_navigation_active", true)
			var ph: Dictionary = _prey_hunters_map()
			var goal: Vector2 = _hunt_ring_goal_for(enemy, _focus_character_id, ph)
			actor.call("update_hunt_navigation_goal", goal)
		else:
			actor.call("set_hunt_navigation_active", false)
	var now: int = Time.get_ticks_msec()
	if now - _ui_attack_last_strike_ms < 650:
		return
	var outcome: Dictionary = _perform_melee_against_node(_focus_character_id, enemy, true, "[attack]")
	if bool(outcome.get("struck", false)):
		_ui_attack_last_strike_ms = now


func _refresh_panel_b_auxiliary() -> void:
	_refresh_bb_vitals_bars()
	_refresh_bb_equip_row()
	_refresh_bc_action_row()
	_rebuild_panel_bd_spells()


func _refresh_bb_vitals_bars() -> void:
	if _bb_vitals == null or _bb_bar_hp == null or _bb_bar_st == null or _bb_bar_mn == null:
		return
	if _selection_portrait_source == "world" and _selection_world_kind == "enemy" and _selection_world_node != null:
		_bb_vitals.visible = true
		_bb_bar_st.visible = false
		_bb_bar_mn.visible = false
		if _selection_world_node.get_script() == _CombatTestEnemyScr:
			var cur: float = _node_get_float(_selection_world_node, &"current_health", 0.0)
			var mx: float = _node_get_float(_selection_world_node, &"max_health", 1.0)
			_bb_bar_hp.max_value = maxf(1.0, mx)
			_bb_bar_hp.value = clampf(cur, 0.0, _bb_bar_hp.max_value)
		else:
			_bb_bar_hp.max_value = 1.0
			_bb_bar_hp.value = 0.0
		return
	if _selection_portrait_source == "world" and _selection_world_kind == "actor" and _selection_world_id != &"" and _registry != null and _stats != null and _equipment != null:
		_bb_vitals.visible = true
		_bb_bar_st.visible = true
		_bb_bar_mn.visible = true
		var dres: Resource = _registry.get_character(_selection_world_id)
		if dres != null:
			var st: Dictionary = _stats.get_effective_stats(_selection_world_id, dres, _equipment)
			var mh: float = float(st.get("max_health", 1.0))
			var ms: float = float(st.get("max_stamina", 1.0))
			var mm: float = float(st.get("max_mana", 1.0))
			_bb_bar_hp.max_value = mh
			_bb_bar_hp.value = clampf(float(dres.current_health), 0.0, mh)
			_bb_bar_st.max_value = ms
			_bb_bar_st.value = clampf(float(dres.current_stamina), 0.0, ms)
			_bb_bar_mn.max_value = mm
			_bb_bar_mn.value = clampf(float(dres.current_mana), 0.0, mm)
		return
	_bb_vitals.visible = false


func _refresh_bb_equip_row() -> void:
	if _bb_btn_equip == null:
		return
	var show_equip: bool = false
	var equip_lbl: String = "Equip"
	var show_read: bool = false
	if _selection_portrait_source == "inventory":
		var src: String = String(_selection_inventory_snapshot.get("source", ""))
		if src == "bag":
			var iid_b: String = String(_selection_inventory_snapshot.get("item_id", ""))
			if not iid_b.is_empty() and _catalog != null and _catalog.has_method("get_definition"):
				var def_b: Resource = _catalog.get_definition(StringName(iid_b)) as Resource
				if def_b != null:
					var es: String = str(def_b.equip_slot)
					if not es.is_empty():
						show_equip = true
						equip_lbl = "Equip"
					if not String(def_b.scroll_teaches_spell).strip_edges().is_empty():
						show_read = true
		elif src == "equip":
			var eiid: String = String(_selection_inventory_snapshot.get("item_id", ""))
			if not eiid.is_empty():
				show_equip = true
				equip_lbl = "Unequip"
	_bb_btn_equip.visible = show_equip
	_bb_btn_equip.text = equip_lbl
	if _bb_btn_read_scroll != null:
		_bb_btn_read_scroll.visible = show_read


func _refresh_bc_action_row() -> void:
	if _bc_btn_attack == null or _bc_btn_inspect == null:
		return
	var ctx: Dictionary = _attack_context_for(_focus_character_id)
	var mode: String = str(ctx.get("mode", "none"))
	var main_def: Resource = WeaponItemUtils.main_hand_definition(_focus_character_id, _equipment, _catalog)
	var casting_weapon: bool = WeaponItemUtils.is_casting_weapon(main_def)
	var enemy_ok: bool = (
		_selection_portrait_source == "world"
		and _selection_world_kind == "enemy"
		and _selection_world_node != null
	)
	var actor_ok: bool = (
		_selection_portrait_source == "world"
		and _selection_world_kind == "actor"
		and _selection_world_node != null
	)
	var show_on_enemy: bool = enemy_ok and mode in ["melee", "missile", "casting"]
	var cast_on_actor_ok: bool = (
		actor_ok
		and casting_weapon
		and (
			mode == "casting_support"
			or (mode == "casting" and _selection_world_id != _focus_character_id)
		)
	)
	var show_primary: bool = show_on_enemy or cast_on_actor_ok
	var can_strike: bool = false
	if show_on_enemy:
		can_strike = mode in ["melee", "missile", "casting"]
	elif cast_on_actor_ok:
		can_strike = mode == "casting_support" or mode == "casting"
	_bc_btn_attack.visible = show_primary
	var busy_cast: bool = _spell_cast_busy and (_spell_cast_attacker_id == _focus_character_id)
	_bc_btn_attack.disabled = (show_primary and not can_strike) or busy_cast
	if show_primary:
		if busy_cast:
			_bc_btn_attack.text = "Casting…"
		elif casting_weapon:
			_bc_btn_attack.text = "Cast"
		elif _ui_attack_active:
			_bc_btn_attack.text = "Stop attack"
		else:
			_bc_btn_attack.text = "Attack"
	var show_inspect: bool = _selection_portrait_source == "world" and _selection_world_kind != "none" and _selection_world_node != null
	_bc_btn_inspect.visible = show_inspect
	_bc_btn_inspect.disabled = not show_inspect


func _rebuild_panel_bd_spells() -> void:
	if _spells_list_host == null or _lbl_bd_selected == null:
		return
	for c in _spells_list_host.get_children():
		c.queue_free()
	if _focus_character_id == &"" or _registry == null or _catalog == null or _equipment == null:
		_lbl_bd_selected.text = "Selected: —"
		return
	var def: Resource = WeaponItemUtils.main_hand_definition(_focus_character_id, _equipment, _catalog)
	if not WeaponItemUtils.is_casting_weapon(def):
		_lbl_bd_selected.text = "Equip a wand or orb to manage spells."
		return
	var data: Resource = _registry.get_character(_focus_character_id)
	if data == null:
		return
	var sel_key: Variant = _bd_spell_selection_by_character.get(_focus_character_id, "")
	var sel: String = str(sel_key)
	if sel.is_empty():
		_lbl_bd_selected.text = "Selected: —"
	else:
		_lbl_bd_selected.text = "Selected: %s" % MagicRules.spell_display_name(StringName(sel))
	var known: PackedStringArray = data.known_spells
	if known.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No spells learned yet."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spells_list_host.add_child(empty_lbl)
		return
	for s in known:
		var sid: StringName = StringName(str(s))
		var btn := Button.new()
		btn.text = MagicRules.spell_display_name(sid)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_bd_spell_button_pressed.bind(sid))
		_spells_list_host.add_child(btn)


func _on_bd_spell_button_pressed(spell_id: StringName) -> void:
	if _focus_character_id == &"":
		return
	if _spell_cast_busy and _spell_cast_attacker_id == _focus_character_id:
		_clear_player_spell_cast()
		_append_command_feed("[ui] Cast cancelled (spell changed).")
	_bd_spell_selection_by_character[_focus_character_id] = String(spell_id)
	_refresh_panel_b_auxiliary()


func _on_bc_attack_pressed() -> void:
	if _selection_portrait_source != "world" or _selection_world_node == null or not (_selection_world_node is Node2D):
		return
	var is_enemy: bool = _selection_world_kind == "enemy"
	var is_actor: bool = _selection_world_kind == "actor"
	if not is_enemy and not is_actor:
		return
	if _focus_character_id == &"":
		_append_command_feed("[ui] Select a party character in Panel B.")
		return
	var ctx: Dictionary = _attack_context_for(_focus_character_id)
	var mode: String = str(ctx.get("mode", "none"))
	if mode == "none":
		_append_command_feed("[ui] Equip a weapon to attack.")
		return
	if mode == "casting_no_spell":
		_append_command_feed("[ui] Select a spell in Panel B.d.")
		return
	var main_def: Resource = WeaponItemUtils.main_hand_definition(_focus_character_id, _equipment, _catalog)
	var casting_weapon: bool = WeaponItemUtils.is_casting_weapon(main_def)
	if casting_weapon and (mode == "casting" or mode == "casting_support"):
		if is_enemy and mode == "casting_support":
			_append_command_feed("[ui] Choose a combat bolt to use on enemies.")
			return
		if is_actor:
			if mode not in ["casting", "casting_support"]:
				return
			if mode == "casting" and _selection_world_id == _focus_character_id:
				_append_command_feed("[ui] Pick another character as the bolt target.")
				return
		_try_start_player_spell_cast()
		return
	if _ui_attack_active:
		_set_ui_attack_active(false)
		return
	if is_enemy:
		if mode == "casting_support":
			_append_command_feed("[ui] Choose a combat bolt to use on enemies.")
			return
	_ui_attack_active = true
	_ui_attack_enemy_iid = _selection_world_node.get_instance_id()
	_ui_attack_last_strike_ms = 0
	_refresh_panel_b_auxiliary()
	var tgt_lbl: String = str(_selection_world_node.name)
	if is_actor and _registry != null:
		var td: Resource = _registry.get_character(_selection_world_id)
		if td != null:
			tgt_lbl = str(td.user_name)
	_append_command_feed("[ui] Attack mode on — %s → %s." % [String(_focus_character_id), tgt_lbl])


func _on_bb_equip_pressed() -> void:
	if _equipment == null or _inventory == null or _catalog == null or _focus_character_id == &"":
		return
	if _selection_portrait_source != "inventory":
		return
	var src: String = String(_selection_inventory_snapshot.get("source", ""))
	if src == "bag":
		var idx: int = int(_selection_inventory_snapshot.get("index", -1))
		if idx < 0:
			return
		var cell: Variant = _inventory.get_cell(_focus_character_id, idx)
		if cell == null:
			return
		var d: Dictionary = cell as Dictionary
		var iid: StringName = d.get("item_id", &"") as StringName
		var def: Resource = _catalog.get_definition(iid)
		if def == null:
			return
		var es: String = String(def.equip_slot)
		if es.is_empty():
			return
		_equipment.equip_from_bag(_focus_character_id, StringName(es), idx)
	elif src == "equip":
		var slot_s: String = String(_selection_inventory_snapshot.get("equip_slot", ""))
		if slot_s.is_empty():
			return
		_equipment.unequip_to_bag(_focus_character_id, StringName(slot_s))
	if _inventory_panel != null and _inventory_panel.has_method("refresh"):
		_inventory_panel.refresh()
	_refresh_panel_b_auxiliary()


func _ensure_inspect_dialog() -> void:
	if _inspect_dialog != null:
		return
	var dlg := AcceptDialog.new()
	dlg.title = "Inspect"
	dlg.ok_button_text = "Close"
	dlg.min_size = Vector2i(440, 300)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.custom_minimum_size = Vector2(400, 260)
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.scroll_active = true
	_inspect_body = rtl
	dlg.add_child(rtl)
	add_child(dlg)
	_inspect_dialog = dlg


func _build_inspect_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	if _selection_portrait_source == "world" and _selection_world_kind == "actor" and _selection_world_id != &"":
		lines.append("[b]Character[/b]")
		lines.append("Id: %s" % String(_selection_world_id))
		if _registry != null:
			var dres: Resource = _registry.get_character(_selection_world_id)
			if dres != null:
				lines.append("Name: %s" % str(dres.user_name))
				lines.append("Level: %d  XP: %d  Logged in: %s" % [int(dres.level), int(dres.total_experience), str(dres.is_logged_in)])
				if _stats != null and _equipment != null:
					var st: Dictionary = _stats.get_effective_stats(_selection_world_id, dres, _equipment)
					lines.append("Max HP: %.0f  Max STA: %.0f  Max MP: %.0f" % [
						float(st.get("max_health", 0.0)),
						float(st.get("max_stamina", 0.0)),
						float(st.get("max_mana", 0.0)),
					])
	elif _selection_portrait_source == "world" and _selection_world_kind == "enemy" and _selection_world_node != null:
		lines.append("[b]Enemy[/b]")
		lines.append("Node: %s" % str(_selection_world_node.name))
		if _selection_world_node.get_script() == _CombatTestEnemyScr:
			var cur: float = _node_get_float(_selection_world_node, &"current_health", 0.0)
			var mx: float = _node_get_float(_selection_world_node, &"max_health", 1.0)
			var xp: int = _node_get_int(_selection_world_node, &"xp_reward", 0)
			var atk: float = _node_get_float(_selection_world_node, &"attack_rating", 0.0)
			var defn: float = _node_get_float(_selection_world_node, &"defense_rating", 0.0)
			lines.append("HP: %.0f / %.0f" % [cur, mx])
			lines.append("Attack / Defense: %.1f / %.1f" % [atk, defn])
			lines.append("XP reward: %d" % xp)
	elif _selection_portrait_source == "inventory" and not _selection_inventory_snapshot.is_empty():
		lines.append("[b]Inventory selection[/b]")
		var src2: String = String(_selection_inventory_snapshot.get("source", ""))
		lines.append("Source: %s" % src2)
		if src2 == "bag":
			lines.append("Bag index: %d" % int(_selection_inventory_snapshot.get("index", -1)))
		elif src2 == "equip":
			lines.append("Slot: %s" % String(_selection_inventory_snapshot.get("equip_slot", "")))
		var ii: String = String(_selection_inventory_snapshot.get("item_id", ""))
		lines.append("Item id: %s" % ii)
		lines.append("Quantity: %d" % int(_selection_inventory_snapshot.get("quantity", 0)))
		if not ii.is_empty() and _catalog != null and _catalog.has_method("get_definition"):
			var def2: Resource = _catalog.get_definition(StringName(ii))
			if def2 != null:
				lines.append("Display name: %s" % str(def2.display_name))
				lines.append("Weight: %.2f  Stack: %d" % [float(def2.weight), int(def2.max_stack)])
				lines.append("Equip slot: %s" % str(def2.equip_slot))
				lines.append("Buy / sell: %d / %d" % [int(def2.buy_price), int(def2.sell_price)])
	else:
		lines.append("Nothing selected. Click the world (Panel A) or inventory (Panel D).")
	var acc: String = ""
	for i in range(lines.size()):
		if i > 0:
			acc += "\n"
		acc += lines[i]
	return acc


func _on_bc_inspect_pressed() -> void:
	_ensure_inspect_dialog()
	if _inspect_body != null:
		_inspect_body.clear()
		_inspect_body.parse_bbcode(_build_inspect_text())
	_inspect_dialog.popup_centered()


func _node_get_float(node: Node, key: StringName, fallback: float) -> float:
	var v: Variant = node.get(key)
	return fallback if v == null else float(v)


func _node_get_int(node: Node, key: StringName, fallback: int) -> int:
	var v: Variant = node.get(key)
	return fallback if v == null else int(v)
