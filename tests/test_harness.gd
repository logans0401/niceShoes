extends SceneTree

## Headless entrypoint: `-s res://tests/test_harness.gd` does not register `class_name`
## globals before parse, so this file uses explicit preloads only (Godot 4.6+).

const CharacterDataScr := preload("res://systems/character_data.gd")
const CharacterRegistryScr := preload("res://systems/character_registry_system.gd")
const CharacterProgressionScr := preload("res://systems/character_progression_system.gd")
const CharacterSaveScr := preload("res://systems/character_save_system.gd")
const GroupSystemScr := preload("res://systems/group_system.gd")
const EquipmentSystemScr := preload("res://systems/equipment_system.gd")
const InventoryScr := preload("res://systems/inventory_system.gd")
const InvBalScr := preload("res://data/inventory_balance_config.gd")
const CatScr := preload("res://systems/item_catalog.gd")
const ItemInstanceScr := preload("res://systems/item_instance_system.gd")
const TradeScr := preload("res://systems/trade_system.gd")
const GroundScr := preload("res://systems/ground_items_system.gd")
const CorpseScr := preload("res://systems/corpse_loot_system.gd")
const LootScr := preload("res://systems/loot_system.gd")
const LootTableConfigScr := preload("res://data/loot_table_config.gd")
const StatsSystemScr := preload("res://systems/stats_system.gd")
const CombatSystemScr := preload("res://systems/combat_system.gd")
const CombatBalanceScr := preload("res://data/combat_balance_config.gd")
const AutomationSystemScr := preload("res://systems/automation_system.gd")
const GameConstantsScr := preload("res://scripts/game_constants.gd")
const CharacterSchemaScr := preload("res://scripts/character_schema.gd")
const MagicRulesScr := preload("res://scripts/magic_rules.gd")

const _MAX_ROSTER := 13
const _MAX_PARTY := 4
const _SKILL_COUNT := 11
const _SKILL_COOKING := "cooking"


func _init() -> void:
	var exit_code: int = _run_all()
	quit(exit_code)


func _run_all() -> int:
	if not _test_character_data():
		push_error("test_harness: character data failed")
		return 1
	if not _test_stats():
		push_error("test_harness: stats failed")
		return 1
	if not _test_combat_melee_resolve():
		push_error("test_harness: combat melee resolve failed")
		return 1
	if not _test_combat_stats_pipeline():
		push_error("test_harness: combat stats pipeline failed")
		return 1
	if not _test_combat_body_area_mitigation():
		push_error("test_harness: combat body-area mitigation failed")
		return 1
	if not _test_arcane_connection_reduces_mana_cost():
		push_error("test_harness: arcane connection mana reduction failed")
		return 1
	if not _test_buff_spell_catalog():
		push_error("test_harness: buff spell catalog failed")
		return 1
	if not _test_all_spells_testing_scroll():
		push_error("test_harness: all-spells testing scroll failed")
		return 1
	if not _test_protection_spell_catalog_and_mitigation():
		push_error("test_harness: protection spell catalog/mitigation failed")
		return 1
	if not _test_item_magic_spell_pool():
		push_error("test_harness: item magic spell pool failed")
		return 1
	if not _test_automation():
		push_error("test_harness: automation failed")
		return 1
	if not _test_automation_priority_order():
		push_error("test_harness: automation priority failed")
		return 1
	if not _test_automation_interrupt_resume():
		push_error("test_harness: automation interrupt/resume failed")
		return 1
	if not _test_automation_queue_preemption_resume():
		push_error("test_harness: automation queue preemption failed")
		return 1
	if not _test_automation_enqueue_interruptible_high_priority_resume():
		push_error("test_harness: automation interruptible high priority failed")
		return 1
	if not _test_automation_four_character_simulation():
		push_error("test_harness: automation four-character sim failed")
		return 1
	if not _test_automation_four_runners_simultaneous():
		push_error("test_harness: automation simultaneous runners failed")
		return 1
	if not _test_project_assets():
		push_error("test_harness: project assets missing")
		return 1
	if not _test_character_data_resource_script():
		push_error("test_harness: character data script resource invalid")
		return 1
	if not _test_level_progression_first_map():
		push_error("test_harness: level progression / first map goal failed")
		return 1
	if not _test_unspent_spend_preserves_total():
		push_error("test_harness: unspent spend / total XP invariant failed")
		return 1
	if not _test_party_xp_distribute():
		push_error("test_harness: party XP distribute failed")
		return 1
	if not _test_skill_and_attribute_xp_curves():
		push_error("test_harness: skill/attribute XP curves failed")
		return 1
	if not _test_party_and_roster_limits():
		push_error("test_harness: party/roster limits failed")
		return 1
	if not _test_save_roundtrip():
		push_error("test_harness: save/load roundtrip failed")
		return 1
	if not _test_burden_penalty_edges():
		push_error("test_harness: burden penalty edges failed")
		return 1
	if not _test_inventory_equip_and_burden():
		push_error("test_harness: inventory/equip/burden failed")
		return 1
	if not _test_item_instances_and_equipment_details():
		push_error("test_harness: item instances/equipment failed")
		return 1
	if not _test_accessory_generation_data():
		push_error("test_harness: accessory generation data failed")
		return 1
	if not _test_item_magic_spell_chance_ladders():
		push_error("test_harness: item magic spell chance ladders failed")
		return 1
	if not _test_death_penalty_fades_with_full_xp():
		push_error("test_harness: death penalty fade failed")
		return 1
	if not _test_loot_tiers_and_corpse_transfer():
		push_error("test_harness: loot tier/corpse transfer failed")
		return 1
	if not _test_trade_range_gate():
		push_error("test_harness: trade range failed")
		return 1
	if not _test_ground_item_decay():
		push_error("test_harness: ground decay failed")
		return 1
	print("NiceShoes: headless harness OK")
	return 0


func _free_node(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.free()


func _test_character_data() -> bool:
	var cd = CharacterDataScr.new()
	cd.character_id = "unit_char"
	cd.user_name = "Unit"
	cd.ensure_defaults()
	if cd.attributes.is_empty():
		return false
	if int(cd.skill_levels.get(_SKILL_COOKING, -1)) < 0:
		return false
	var copy = cd.duplicate_data()
	return copy.character_id == "unit_char" and copy.user_name == "Unit"


func _balance():
	return load("res://data/default_character_balance.tres")


func _test_stats() -> bool:
	var cd = CharacterDataScr.new()
	cd.character_id = "unit_char"
	cd.ensure_defaults()
	var eq = EquipmentSystemScr.new()
	var st = StatsSystemScr.new()
	st.configure(_balance())
	st.configure_inventory_penalties(load("res://data/default_inventory_balance.tres") as Resource)
	var stats: Dictionary = st.get_effective_stats(&"unit_char", cd, eq)
	var sm: Dictionary = stats.get("skill_modifiers", {}) as Dictionary
	var ok: bool = (
		float(stats.get("max_health", 0.0)) > 0.0
		and float(stats.get("burden_capacity", 0.0)) > 0.0
		and sm.size() == _SKILL_COUNT
		and float(sm.get(_SKILL_COOKING, 0.0)) > 0.0
		and stats.has("movement_speed_multiplier")
	)
	_free_node(st)
	_free_node(eq)
	return ok


func _test_combat_melee_resolve() -> bool:
	var combat: Node = CombatSystemScr.new()
	var hi: Dictionary = combat.resolve_melee_hit({"attack_rating": 10.0}, {"defense_rating": 0.0})
	if not bool(hi.get("hit", false)) or not is_equal_approx(float(hi.get("damage", 0.0)), 10.0):
		_free_node(combat)
		return false
	var floor_dmg: Dictionary = combat.resolve_melee_hit({"attack_rating": 5.0}, {"defense_rating": 20.0})
	if not bool(floor_dmg.get("hit", false)) or not is_equal_approx(float(floor_dmg.get("damage", 0.0)), 1.0):
		_free_node(combat)
		return false
	var mid: Dictionary = combat.resolve_melee_hit({"attack_rating": 5.0}, {"defense_rating": 10.0})
	if not bool(mid.get("hit", false)) or not is_equal_approx(float(mid.get("damage", 0.0)), 1.5):
		_free_node(combat)
		return false
	_free_node(combat)
	return true


func _test_combat_stats_pipeline() -> bool:
	## Effective attack/defense from StatsSystem should drive melee damage (stronger build > weaker vs same target).
	var balance = _balance()
	var inv_bal = load("res://data/default_inventory_balance.tres") as Resource
	var st = StatsSystemScr.new()
	st.configure(balance)
	st.configure_inventory_penalties(inv_bal)
	var eq = EquipmentSystemScr.new()
	var bruiser = CharacterDataScr.new()
	bruiser.character_id = "combat_br"
	bruiser.ensure_defaults()
	bruiser.attributes["strength"] = 16
	bruiser.attributes["ability"] = 14
	bruiser.skill_levels["melee_combat"] = 8
	var rookie = CharacterDataScr.new()
	rookie.character_id = "combat_ro"
	rookie.ensure_defaults()
	var sa: Dictionary = st.get_effective_stats(&"combat_br", bruiser, eq)
	var sb: Dictionary = st.get_effective_stats(&"combat_ro", rookie, eq)
	if float(sa.get("attack_rating", 0.0)) <= float(sb.get("attack_rating", 0.0)):
		_free_node(st)
		_free_node(eq)
		return false
	var combat: Node = CombatSystemScr.new()
	var strong_hit: Dictionary = combat.resolve_melee_hit(sa, sb)
	var weak_hit: Dictionary = combat.resolve_melee_hit(sb, sa)
	_free_node(combat)
	_free_node(st)
	_free_node(eq)
	var d1: float = float(strong_hit.get("damage", 0.0))
	var d2: float = float(weak_hit.get("damage", 0.0))
	return bool(strong_hit.get("hit", false)) and bool(weak_hit.get("hit", false)) and d1 > d2


func _test_combat_body_area_mitigation() -> bool:
	var combat: Node = CombatSystemScr.new()
	var cfg = CombatBalanceScr.new()
	combat.configure(cfg)
	var armor_by_area: Dictionary = {}
	for area in CombatBalanceScr.BODY_AREAS:
		armor_by_area[area] = {"armor_level": 5.0, "damage_ratings": {DamageTypes.Id.SLASHING: 5}}
	var res: Dictionary = combat.resolve_melee_hit(
		{"attack_rating": 10.0},
		{"defense_rating": 0.0, "armor_by_area": armor_by_area},
		DamageTypes.Id.SLASHING,
	)
	var ok: bool = (
		res.has("target_area")
		and res.has("raw_damage")
		and float(res.get("damage", 0.0)) < float(res.get("raw_damage", 0.0))
	)
	_free_node(combat)
	return ok


func _test_arcane_connection_reduces_mana_cost() -> bool:
	var base: int = MagicRulesScr.spell_mana_cost(MagicRulesScr.BOLT_FIRE, 1)
	var reduced: int = MagicRulesScr.spell_mana_cost_after_arcane_connection(MagicRulesScr.BOLT_FIRE, 1, 40.0)
	var capped: int = MagicRulesScr.spell_mana_cost_after_arcane_connection(MagicRulesScr.BOLT_FIRE, 1, 999.0)
	return reduced < base and capped >= 1 and capped <= reduced


func _test_buff_spell_catalog() -> bool:
	var buffs: Dictionary = MagicRulesScr.buff_spell_catalog()
	var expected_count: int = CharacterSchemaScr.ALL_ATTRIBUTES.size() + CharacterSchemaScr.ALL_SKILLS.size()
	if buffs.size() != expected_count:
		return false
	for attr in CharacterSchemaScr.ALL_ATTRIBUTES:
		var sid := StringName("%s_buff" % str(attr))
		var def: Dictionary = buffs.get(sid, {}) as Dictionary
		if str(def.get("kind", "")) != MagicRulesScr.BUFF_KIND_ATTRIBUTE:
			return false
		if str(def.get("target_id", "")) != str(attr):
			return false
	for skill in CharacterSchemaScr.ALL_SKILLS:
		var sid2 := StringName("%s_buff" % str(skill))
		var def2: Dictionary = buffs.get(sid2, {}) as Dictionary
		if str(def2.get("kind", "")) != MagicRulesScr.BUFF_KIND_SKILL:
			return false
		if str(def2.get("target_id", "")) != str(skill):
			return false
	var scrolls: Array[StringName] = MagicRulesScr.all_scroll_teach_spell_ids()
	return (
		scrolls.size() == 12
		and scrolls.has(MagicRulesScr.SPELL_REFLEXES_BUFF)
		and scrolls.has(MagicRulesScr.SPELL_MELEE_COMBAT_BUFF)
	)


func _test_all_spells_testing_scroll() -> bool:
	var ids: Array[StringName] = MagicRulesScr.all_spell_ids()
	var expected_size: int = (
		MagicRulesScr.all_scroll_teach_spell_ids().size()
		+ CharacterSchemaScr.ALL_ATTRIBUTES.size()
		+ CharacterSchemaScr.ALL_SKILLS.size()
		- 2
		+ MagicRulesScr.all_protection_spell_ids().size()
	)
	if ids.size() != expected_size:
		return false
	for sid in MagicRulesScr.all_scroll_teach_spell_ids():
		if not ids.has(sid):
			return false
	for sid2 in MagicRulesScr.all_buff_spell_ids():
		if not ids.has(sid2):
			return false
	for sid3 in MagicRulesScr.all_protection_spell_ids():
		if not ids.has(sid3):
			return false
	var cat: Node = CatScr.new()
	cat.call("ensure_items")
	var def: Resource = cat.call("get_definition", &"scroll_all_spells") as Resource
	if def == null:
		cat.free()
		return false
	var ok: bool = int(def.buy_price) == 0 and String(def.scroll_teaches_spell) == String(MagicRulesScr.SCROLL_TEACHES_ALL_SPELLS)
	cat.free()
	return ok


func _test_protection_spell_catalog_and_mitigation() -> bool:
	var protections: Dictionary = MagicRulesScr.protection_spell_catalog()
	if protections.size() != 8:
		return false
	var armor_def: Dictionary = protections.get(&"armor_protection", {}) as Dictionary
	if str(armor_def.get("kind", "")) != MagicRulesScr.PROTECTION_KIND_ARMOR:
		return false
	if not is_equal_approx(float(armor_def.get("armor_bonus", 0.0)), MagicRulesScr.ARMOR_PROTECTION_AMOUNT):
		return false
	for spell_id in MagicRulesScr.all_protection_spell_ids():
		if MagicRulesScr.spell_display_name(spell_id).is_empty():
			return false
	var cd: Resource = CharacterDataScr.new()
	cd.transient_armor_bonus = MagicRulesScr.ARMOR_PROTECTION_AMOUNT
	cd.transient_damage_protection_percent[str(DamageTypes.Id.FIRE)] = MagicRulesScr.DAMAGE_TYPE_PROTECTION_PERCENT
	var stats: Node = StatsSystemScr.new()
	stats.configure(load("res://data/default_character_balance.tres") as Resource)
	stats.configure_inventory_penalties(InvBalScr.new())
	stats.configure_combat_balance(CombatBalanceScr.new())
	var effective: Dictionary = stats.get_effective_stats(&"prot", cd, null)
	var armor: Dictionary = effective.get("armor_by_area", {}) as Dictionary
	for area in CombatBalanceScr.BODY_AREAS:
		var area_stats: Dictionary = armor.get(area, {}) as Dictionary
		if not is_equal_approx(float(area_stats.get("armor_level", 0.0)), MagicRulesScr.ARMOR_PROTECTION_AMOUNT):
			_free_node(stats)
			return false
	var combat: Node = CombatSystemScr.new()
	combat.configure(CombatBalanceScr.new())
	var base: Dictionary = combat.resolve_melee_hit(
		{"attack_rating": 10.0},
		{"defense_rating": 0.0},
		DamageTypes.Id.FIRE,
		1000,
		1000,
	)
	var protected: Dictionary = combat.resolve_melee_hit(
		{"attack_rating": 10.0},
		effective,
		DamageTypes.Id.FIRE,
		1000,
		1000,
	)
	var ok: bool = float(protected.get("damage", 0.0)) < float(base.get("damage", 0.0))
	_free_node(combat)
	_free_node(stats)
	return ok


func _test_item_magic_spell_pool() -> bool:
	var ids: Array[StringName] = MagicRulesScr.all_item_magic_spell_ids()
	var expected_size: int = MagicRulesScr.all_buff_spell_ids().size() + MagicRulesScr.all_protection_spell_ids().size()
	if ids.size() != expected_size:
		return false
	for sid in ids:
		if MagicRulesScr.is_offensive_bolt(sid):
			return false
		if not MagicRulesScr.is_buff_spell(sid) and not MagicRulesScr.is_protection_spell(sid):
			return false
	return true


func _test_automation() -> bool:
	var auto = AutomationSystemScr.new()
	var idle = AutomationSystemScr.AutomationTask.new()
	idle.type = AutomationSystemScr.TaskType.IDLE
	idle.label = "unit_idle"
	auto.enqueue(idle)
	auto.tick(0.016)
	var ok: bool = auto.get_active_task() == null
	_free_node(auto)
	return ok


func _test_automation_priority_order() -> bool:
	var auto = AutomationSystemScr.new()
	var rid := &"prio_unit"
	var w = AutomationSystemScr.AutomationTask.new()
	w.type = AutomationSystemScr.TaskType.WAIT
	w.priority = 1
	w.data["sim_ticks"] = 1
	w.label = "wait"
	var h = AutomationSystemScr.AutomationTask.new()
	h.type = AutomationSystemScr.TaskType.HUNT
	h.priority = 10
	h.data["sim_only"] = true
	h.data["sim_ticks"] = 1
	h.label = "hunt"
	auto.enqueue_for(rid, w)
	auto.enqueue_for(rid, h)
	for _i in range(16):
		auto.tick_all(0.01)
	var prev: Array = auto.get_previous_tasks_for(rid)
	var ok: bool = prev.size() == 2 and int((prev[0] as Dictionary).get("type")) == AutomationSystemScr.TaskType.HUNT
	_free_node(auto)
	return ok


func _test_automation_interrupt_resume() -> bool:
	var auto = AutomationSystemScr.new()
	var rid := &"irq_unit"
	var w = AutomationSystemScr.AutomationTask.new()
	w.type = AutomationSystemScr.TaskType.WAIT
	w.interruptible = true
	w.data["sim_ticks"] = 5
	w.label = "long_wait"
	auto.enqueue_for(rid, w)
	auto.tick_all(0.01)
	if auto.get_active_task_for(rid) == null:
		_free_node(auto)
		return false
	if not auto.interrupt_active(rid):
		_free_node(auto)
		return false
	if auto.get_active_task_for(rid) != null:
		_free_node(auto)
		return false
	if not auto.resume_suspended(rid):
		_free_node(auto)
		return false
	for _i in range(32):
		auto.tick_all(0.01)
	if auto.get_active_task_for(rid) != null:
		_free_node(auto)
		return false
	var prev: Array = auto.get_previous_tasks_for(rid)
	var ok: bool = not prev.is_empty() and str((prev[prev.size() - 1] as Dictionary).get("label")) == "long_wait"
	_free_node(auto)
	return ok


func _test_automation_queue_preemption_resume() -> bool:
	var auto = AutomationSystemScr.new()
	auto.queue_preempts_lower_priority_active = true
	var rid := &"preempt_u"
	var wait = AutomationSystemScr.AutomationTask.new()
	wait.type = AutomationSystemScr.TaskType.WAIT
	wait.priority = 1
	wait.interruptible = true
	wait.data["sim_ticks"] = 99
	wait.label = "long_wait"
	var hunt = AutomationSystemScr.AutomationTask.new()
	hunt.type = AutomationSystemScr.TaskType.HUNT
	hunt.priority = 10
	hunt.interruptible = true
	hunt.data["sim_only"] = true
	hunt.data["sim_ticks"] = 1
	hunt.label = "hunt_prio"
	auto.enqueue_for(rid, wait)
	auto.tick_all(0.01)
	if auto.get_active_task_for(rid) == null:
		_free_node(auto)
		return false
	auto.enqueue_for(rid, hunt)
	auto.tick_all(0.01)
	var a2: Variant = auto.get_active_task_for(rid)
	if a2 == null or not a2 is AutomationSystemScr.AutomationTask:
		_free_node(auto)
		return false
	var at2: AutomationSystemScr.AutomationTask = a2 as AutomationSystemScr.AutomationTask
	if at2.type != AutomationSystemScr.TaskType.HUNT:
		_free_node(auto)
		return false
	for _i in range(64):
		auto.tick_all(0.01)
	var a3: Variant = auto.get_active_task_for(rid)
	if a3 == null or not a3 is AutomationSystemScr.AutomationTask:
		_free_node(auto)
		return false
	var at3: AutomationSystemScr.AutomationTask = a3 as AutomationSystemScr.AutomationTask
	var ok2: bool = at3.type == AutomationSystemScr.TaskType.WAIT
	_free_node(auto)
	return ok2


func _test_automation_enqueue_interruptible_high_priority_resume() -> bool:
	var auto = AutomationSystemScr.new()
	var rid := &"ehq_u"
	var f = AutomationSystemScr.AutomationTask.new()
	f.type = AutomationSystemScr.TaskType.FOLLOW_CHARACTER
	f.interruptible = true
	f.label = "follow"
	var sup = AutomationSystemScr.AutomationTask.new()
	sup.type = AutomationSystemScr.TaskType.SUPPORT_ALLY
	sup.interruptible = true
	sup.label = "burst"
	sup.data["ally_id"] = "ally"
	sup.data["sim_ticks"] = 1
	auto.enqueue_for(rid, f)
	auto.tick_all(0.01)
	if auto.get_active_task_for(rid) == null:
		_free_node(auto)
		return false
	auto.enqueue_interruptible_high_priority(rid, sup)
	for _j in range(80):
		auto.tick_all(0.01)
	var a: Variant = auto.get_active_task_for(rid)
	if a == null or not a is AutomationSystemScr.AutomationTask:
		_free_node(auto)
		return false
	var at: AutomationSystemScr.AutomationTask = a as AutomationSystemScr.AutomationTask
	var ok: bool = at.type == AutomationSystemScr.TaskType.FOLLOW_CHARACTER
	_free_node(auto)
	return ok


func _test_automation_four_character_simulation() -> bool:
	var auto = AutomationSystemScr.new()
	var types := [
		AutomationSystemScr.TaskType.HUNT,
		AutomationSystemScr.TaskType.SEARCH_LOOT,
		AutomationSystemScr.TaskType.COMPLETE_QUEST,
		AutomationSystemScr.TaskType.SELL_EXCESS_LOOT,
	]
	var labels := ["hunt", "loot", "quest", "sell"]
	for i in range(4):
		var rid := StringName("sim_char_%d" % i)
		var t = AutomationSystemScr.AutomationTask.new()
		t.type = types[i]
		t.label = labels[i]
		t.data["sim_ticks"] = 2
		if t.type == AutomationSystemScr.TaskType.HUNT:
			t.data["sim_only"] = true
		if t.type == AutomationSystemScr.TaskType.SEARCH_LOOT:
			t.data["loot_filter"] = {"item_id": &"scrap"}
		if t.type == AutomationSystemScr.TaskType.COMPLETE_QUEST:
			t.data["quest_id"] = "demo_quest"
		if t.type == AutomationSystemScr.TaskType.SELL_EXCESS_LOOT:
			t.data["merchant_id"] = "default_merchant"
		auto.enqueue_for(rid, t)
	for _i in range(48):
		auto.tick_all(0.01)
	var ok: bool = true
	for i in range(4):
		var rid := StringName("sim_char_%d" % i)
		if auto.get_active_task_for(rid) != null:
			ok = false
			break
		if auto.get_previous_tasks_for(rid).is_empty():
			ok = false
			break
	_free_node(auto)
	return ok


func _test_automation_four_runners_simultaneous() -> bool:
	var auto = AutomationSystemScr.new()
	var rids: Array = [
		&"sim_r0",
		&"sim_r1",
		AutomationSystemScr.group_runner_id(&"party_a"),
		AutomationSystemScr.group_runner_id(&"party_b"),
	]
	for rid in rids:
		var t = AutomationSystemScr.AutomationTask.new()
		t.type = AutomationSystemScr.TaskType.NAVIGATE_MAP
		t.data["sim_ticks"] = 3
		t.data["map_id"] = "map_test"
		t.label = "nav"
		auto.enqueue_for(rid, t)
	auto.tick_all(0.001)
	var active_count: int = 0
	for rid in rids:
		if auto.get_active_task_for(rid) != null:
			active_count += 1
	if active_count != 4:
		_free_node(auto)
		return false
	for _i in range(64):
		auto.tick_all(0.01)
	var ok: bool = true
	for rid in rids:
		if auto.get_active_task_for(rid) != null:
			ok = false
			break
	_free_node(auto)
	return ok


func _test_project_assets() -> bool:
	if not ResourceLoader.exists("res://main.tscn"):
		return false
	if not ResourceLoader.exists("res://ui/main_shell.tscn"):
		return false
	if not ResourceLoader.exists(GameConstantsScr.PLACEHOLDER_MAP):
		return false
	if not ResourceLoader.exists("res://data/default_character_balance.tres"):
		return false
	if not ResourceLoader.exists("res://data/default_inventory_balance.tres"):
		return false
	return true


func _test_character_data_resource_script() -> bool:
	var cd = CharacterDataScr.new()
	cd.character_id = "script_fixture"
	cd.ensure_defaults()
	return cd.get_script() == CharacterDataScr


func _test_level_progression_first_map() -> bool:
	var balance = _balance()
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var cd = CharacterDataScr.new()
	cd.character_id = "prog_a"
	cd.user_name = "Prog"
	cd.ensure_defaults()
	var ok: bool = false
	if reg.register_character(cd) == OK:
		var prog = CharacterProgressionScr.new()
		prog.configure(reg, balance)
		prog.add_total_experience(&"prog_a", balance.first_map_total_xp_budget)
		ok = (
			cd.level >= 3
			and balance.get_level_from_total_xp(cd.total_experience) == cd.level
			and cd.unspent_experience == cd.total_experience
			and cd.total_experience == balance.first_map_total_xp_budget
		)
		_free_node(prog)
	_free_node(reg)
	return ok


func _test_unspent_spend_preserves_total() -> bool:
	var balance = _balance()
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var cd = CharacterDataScr.new()
	cd.character_id = "spend_a"
	cd.user_name = "Spend"
	cd.ensure_defaults()
	if reg.register_character(cd) != OK:
		_free_node(reg)
		return false
	var prog = CharacterProgressionScr.new()
	prog.configure(reg, balance)
	prog.add_total_experience(&"spend_a", 400)
	var total: int = cd.total_experience
	var unspent_before: int = cd.unspent_experience
	var aid: StringName = CharacterSchemaScr.ALL_ATTRIBUTES[0]
	if prog.try_raise_attribute(&"spend_a", aid) != OK:
		_free_node(prog)
		_free_node(reg)
		return false
	var ok: bool = cd.total_experience == total and cd.unspent_experience < unspent_before
	_free_node(prog)
	_free_node(reg)
	return ok


func _test_party_xp_distribute() -> bool:
	var balance = _balance()
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var gs = GroupSystemScr.new()
	gs.configure(reg)
	var prog = CharacterProgressionScr.new()
	prog.configure(reg, balance)
	for sid in [&"xp_a", &"xp_b"]:
		var cd = CharacterDataScr.new()
		cd.character_id = String(sid)
		cd.user_name = String(sid)
		cd.ensure_defaults()
		if reg.register_character(cd) != OK:
			_free_node(prog)
			_free_node(gs)
			_free_node(reg)
			return false
		if gs.add_member(sid) != OK:
			_free_node(prog)
			_free_node(gs)
			_free_node(reg)
			return false
	var base: int = 100
	prog.distribute_experience_among(PackedStringArray([&"xp_a", &"xp_b"]), base, true)
	var da: Resource = reg.get_character(&"xp_a")
	var db: Resource = reg.get_character(&"xp_b")
	var pool: int = maxi(1, int(floor(float(base) * 1.15)))
	var xa: int = int(da.total_experience)
	var xb: int = int(db.total_experience)
	var ok: bool = (xa + xb == pool) and abs(xa - xb) <= 1
	_free_node(prog)
	_free_node(gs)
	_free_node(reg)
	return ok


func _test_skill_and_attribute_xp_curves() -> bool:
	var balance = _balance()
	var low: int = balance.get_skill_xp_to_advance(0)
	var high: int = balance.get_skill_xp_to_advance(12)
	if high <= low:
		return false
	var a1: int = balance.get_attribute_xp_to_advance(10)
	var a2: int = balance.get_attribute_xp_to_advance(25)
	return a2 > a1


func _test_party_and_roster_limits() -> bool:
	var balance = _balance()
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var party = GroupSystemScr.new()
	var duo = GroupSystemScr.new()
	var trio = GroupSystemScr.new()
	var ok: bool = false

	for i in range(_MAX_ROSTER):
		var cd = CharacterDataScr.new()
		cd.character_id = "roster_%d" % i
		cd.user_name = "R%d" % i
		cd.ensure_defaults()
		if reg.register_character(cd) != OK:
			_free_node(trio)
			_free_node(duo)
			_free_node(party)
			_free_node(reg)
			return false

	var overflow = CharacterDataScr.new()
	overflow.character_id = "overflow"
	overflow.ensure_defaults()
	if reg.register_character(overflow) == OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false

	party.configure(reg)
	for i in range(_MAX_PARTY):
		var cid: StringName = StringName("roster_%d" % i)
		if party.add_member(cid) != OK:
			_free_node(trio)
			_free_node(duo)
			_free_node(party)
			_free_node(reg)
			return false

	if party.add_member(&"roster_10") == OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false

	if party.remove_member(&"roster_3") != OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false
	if party.remove_member(&"roster_2") != OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false
	if party.remove_member(&"roster_1") == OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false

	duo.configure(reg)
	if duo.add_member(&"roster_0") != OK or duo.add_member(&"roster_1") != OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false
	if duo.try_set_character_logged_in(&"roster_0", false) != OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false
	var duo0 = reg.get_character(&"roster_0")
	if duo0 == null or duo0.is_logged_in or duo.get_roster().size() != 2:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false

	trio.configure(reg)
	if trio.add_member(&"roster_5") != OK or trio.add_member(&"roster_6") != OK or trio.add_member(&"roster_7") != OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false
	if trio.try_set_character_logged_in(&"roster_7", false) != OK:
		_free_node(trio)
		_free_node(duo)
		_free_node(party)
		_free_node(reg)
		return false

	ok = true
	_free_node(trio)
	_free_node(duo)
	_free_node(party)
	_free_node(reg)
	return ok


func _test_save_roundtrip() -> bool:
	var balance = _balance()
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var cd = CharacterDataScr.new()
	cd.character_id = "save_a"
	cd.user_name = "Persist"
	cd.ensure_defaults()
	if reg.register_character(cd) != OK:
		_free_node(reg)
		return false
	var prog = CharacterProgressionScr.new()
	prog.configure(reg, balance)
	prog.add_total_experience(&"save_a", balance.first_map_total_xp_budget)

	var inv_bal = load("res://data/default_inventory_balance.tres") as Resource
	var cat = CatScr.new()
	cat.ensure_items()
	var inv = InventoryScr.new()
	var eq = EquipmentSystemScr.new()
	inv.configure(cat, reg, inv_bal)
	eq.configure(inv, cat)
	inv.attach_equipment(eq)
	inv.try_add_item(&"save_a", &"scrap", 4)

	var saver = CharacterSaveScr.new()
	var path: String = "user://niceshoes_unit_save.json"
	if saver.save_registry(path, reg, inv, eq) != OK:
		inv.attach_equipment(null)
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(saver)
		_free_node(prog)
		_free_node(reg)
		return false

	var reg2 = CharacterRegistryScr.new()
	reg2.configure(balance)
	var cat2 = CatScr.new()
	cat2.ensure_items()
	var inv2 = InventoryScr.new()
	var eq2 = EquipmentSystemScr.new()
	inv2.configure(cat2, reg2, inv_bal)
	eq2.configure(inv2, cat2)
	inv2.attach_equipment(eq2)
	if saver.load_registry(path, reg2, inv2, eq2) != OK:
		_free_node(eq2)
		_free_node(inv2)
		_free_node(cat2)
		_free_node(reg2)
		inv.attach_equipment(null)
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(saver)
		_free_node(prog)
		_free_node(reg)
		return false

	var loaded = reg2.get_character(&"save_a")
	var cell = inv2.get_cell(&"save_a", 0)
	var ok: bool = (
		loaded != null
		and loaded.user_name == "Persist"
		and loaded.level >= 3
		and loaded.unspent_experience == loaded.total_experience
		and loaded.total_experience == balance.first_map_total_xp_budget
		and cell != null
	)
	_free_node(eq2)
	_free_node(inv2)
	_free_node(cat2)
	_free_node(reg2)
	inv.attach_equipment(null)
	_free_node(eq)
	_free_node(inv)
	_free_node(cat)
	_free_node(saver)
	_free_node(prog)
	_free_node(reg)
	return ok


func _test_burden_penalty_edges() -> bool:
	var cfg = load("res://data/default_inventory_balance.tres") as Resource
	if cfg == null:
		return false
	var r0: float = cfg.get_burden_ratio(0.0, 80.0)
	var r_over: float = cfg.get_burden_ratio(200.0, 80.0)
	var p_light: Dictionary = cfg.get_penalty_multipliers(r0)
	var p_heavy: Dictionary = cfg.get_penalty_multipliers(r_over)
	var m0: float = float(p_light.get("movement_speed_multiplier", 0.0))
	var m1: float = float(p_heavy.get("movement_speed_multiplier", 1.0))
	if m0 <= m1:
		return false
	var s0: float = float(p_light.get("stamina_use_multiplier", 99.0))
	var s1: float = float(p_heavy.get("stamina_use_multiplier", 0.0))
	return s1 >= s0


func _test_inventory_equip_and_burden() -> bool:
	var balance = _balance()
	var inv_bal = load("res://data/default_inventory_balance.tres") as Resource
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var cat = CatScr.new()
	cat.ensure_items()
	var inv = InventoryScr.new()
	var eq = EquipmentSystemScr.new()
	inv.configure(cat, reg, inv_bal)
	eq.configure(inv, cat)
	inv.attach_equipment(eq)
	var cd = CharacterDataScr.new()
	cd.character_id = "inv_u"
	cd.ensure_defaults()
	if reg.register_character(cd) != OK:
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	if inv.try_add_item(&"inv_u", &"iron_sword", 1) > 0:
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	var before_slots: int = _count_bag_items(inv.get_bag_copy(&"inv_u"))
	if eq.equip_from_bag(&"inv_u", &"main_hand", 0) != OK:
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	var after_slots: int = _count_bag_items(inv.get_bag_copy(&"inv_u"))
	if after_slots >= before_slots:
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	if cd.laden_burden < 5.9:
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	var st = StatsSystemScr.new()
	st.configure(balance)
	st.configure_inventory_penalties(inv_bal)
	cd.laden_burden = 200.0
	st.invalidate(&"inv_u")
	var cap: float = float(st.get_effective_stats(&"inv_u", cd, eq).get("burden_capacity", 1.0))
	var stats_heavy: Dictionary = st.get_effective_stats(&"inv_u", cd, eq)
	var def_skill_pen: float = float(stats_heavy.get("defense_skill_multiplier", 1.0))
	if def_skill_pen >= 1.0:
		_free_node(st)
		_free_node(eq)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	cd.laden_burden = 0.0
	st.invalidate(&"inv_u")
	var stats_light: Dictionary = st.get_effective_stats(&"inv_u", cd, eq)
	var def_ok: float = float(stats_light.get("defense_skill_multiplier", 0.0))
	_free_node(st)
	_free_node(eq)
	_free_node(inv)
	_free_node(cat)
	_free_node(reg)
	return def_ok > def_skill_pen and cap > 0.0


func _count_bag_items(bag: Array) -> int:
	var n: int = 0
	for c in bag:
		if c != null:
			n += 1
	return n


func _test_item_instances_and_equipment_details() -> bool:
	var balance = _balance()
	var inv_bal = load("res://data/default_inventory_balance.tres") as Resource
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var cat = CatScr.new()
	cat.ensure_items()
	var inst = ItemInstanceScr.new()
	inst.configure(cat)
	var inv = InventoryScr.new()
	var eq = EquipmentSystemScr.new()
	inv.configure(cat, reg, inv_bal, inst)
	eq.configure(inv, cat, inst)
	inv.attach_equipment(eq)
	var cd = CharacterDataScr.new()
	cd.character_id = "inst_u"
	cd.ensure_defaults()
	reg.register_character(cd)
	var left: int = inv.try_add_item(&"inst_u", &"iron_sword", 1)
	var cell: Variant = inv.get_cell(&"inst_u", 0)
	var ok: bool = left == 0 and cell is Dictionary and String((cell as Dictionary).get("instance_id", "")) != ""
	if ok:
		ok = eq.equip_from_bag(&"inst_u", &"main_hand", 0) == OK
	if ok:
		var key: StringName = eq.get_equipped_key(&"inst_u", &"main_hand")
		var details: Dictionary = eq.get_equipped_details(&"inst_u", &"main_hand")
		ok = key != &"" and eq.get_equipped_item(&"inst_u", &"main_hand") == &"iron_sword" and int(details.get("damage_max", 0)) >= 3
	_free_node(eq)
	_free_node(inv)
	_free_node(inst)
	_free_node(cat)
	_free_node(reg)
	return ok


func _test_accessory_generation_data() -> bool:
	var cat = CatScr.new()
	cat.ensure_items()
	var accessory_ids: Array[StringName] = [
		&"bronze_bracelet",
		&"copper_ring",
		&"silver_necklace",
		&"gold_ring",
		&"onyx_ring",
	]
	for item_id in accessory_ids:
		var def: Resource = cat.get_definition(item_id)
		if def == null:
			_free_node(cat)
			return false
		if str(def.category) != "wearable" or str(def.item_type) != "accessory":
			_free_node(cat)
			return false
		if not str(def.display_name).contains(" "):
			_free_node(cat)
			return false
	var loot_table: Resource = LootTableConfigScr.new()
	var pool: Array = loot_table.get_pool_for_tier(4)
	var armor_weight: int = _loot_pool_weight_for_item(pool, &"leather_cap") + _loot_pool_weight_for_item(pool, &"wood_shield")
	var accessory_weight: int = _loot_pool_weight_for_item(pool, &"bronze_bracelet") + _loot_pool_weight_for_item(pool, &"copper_ring")
	var ok: bool = (
		armor_weight > accessory_weight
		and is_equal_approx(ItemInstanceScr.ACCESSORY_MAGIC_CHANCE, 0.16)
		and is_equal_approx(ItemInstanceScr.WEARABLE_MAGIC_CHANCE, 0.04)
	)
	_free_node(cat)
	return ok


func _test_item_magic_spell_chance_ladders() -> bool:
	var wearable_expected: Array[float] = [0.04, 0.10, 0.14, 0.18]
	var accessory_expected: Array[float] = [0.16, 0.21, 0.25, 0.35]
	if ItemInstanceScr.WEARABLE_MAGIC_SPELL_CHANCES.size() != ItemInstanceScr.MAX_MAGIC_SPELLS_PER_ITEM:
		return false
	if ItemInstanceScr.ACCESSORY_MAGIC_SPELL_CHANCES.size() != ItemInstanceScr.MAX_MAGIC_SPELLS_PER_ITEM:
		return false
	for i in range(ItemInstanceScr.MAX_MAGIC_SPELLS_PER_ITEM):
		if not is_equal_approx(ItemInstanceScr.WEARABLE_MAGIC_SPELL_CHANCES[i], wearable_expected[i]):
			return false
		if not is_equal_approx(ItemInstanceScr.ACCESSORY_MAGIC_SPELL_CHANCES[i], accessory_expected[i]):
			return false
	return (
		is_equal_approx(ItemInstanceScr.WEARABLE_MAGIC_CHANCE, ItemInstanceScr.WEARABLE_MAGIC_SPELL_CHANCES[0])
		and is_equal_approx(ItemInstanceScr.ACCESSORY_MAGIC_CHANCE, ItemInstanceScr.ACCESSORY_MAGIC_SPELL_CHANCES[0])
	)


func _loot_pool_weight_for_item(pool: Array, item_id: StringName) -> int:
	var total: int = 0
	for entry in pool:
		if entry is Dictionary:
			var d: Dictionary = entry as Dictionary
			if String(d.get("item_id", "")) == String(item_id):
				total += int(d.get("weight", 1))
		elif String(entry) == String(item_id):
			total += 1
	return total


func _test_death_penalty_fades_with_full_xp() -> bool:
	var balance = _balance()
	var combat_balance = CombatBalanceScr.new()
	combat_balance.death_penalty_recovery_per_xp = 0.01
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var cd = CharacterDataScr.new()
	cd.character_id = "death_u"
	cd.ensure_defaults()
	reg.register_character(cd)
	var prog = CharacterProgressionScr.new()
	prog.configure(reg, balance, combat_balance)
	prog.apply_death_penalty(&"death_u")
	var before: float = float(cd.meta.get("death_penalty_percent", 0.0))
	prog.add_total_experience(&"death_u", 2)
	var after: float = float(cd.meta.get("death_penalty_percent", 0.0))
	var ok: bool = cd.total_experience == 2 and cd.unspent_experience == 2 and before > after
	_free_node(prog)
	_free_node(reg)
	return ok


func _test_loot_tiers_and_corpse_transfer() -> bool:
	var balance = _balance()
	var inv_bal = load("res://data/default_inventory_balance.tres") as Resource
	var reg = CharacterRegistryScr.new()
	reg.configure(balance)
	var cd = CharacterDataScr.new()
	cd.character_id = "loot_u"
	cd.ensure_defaults()
	reg.register_character(cd)
	var cat = CatScr.new()
	cat.ensure_items()
	var inst = ItemInstanceScr.new()
	inst.configure(cat)
	var inv = InventoryScr.new()
	inv.configure(cat, reg, inv_bal, inst)
	var trade = TradeScr.new()
	trade.configure(inv, inv_bal)
	trade.set_character_position(&"loot_u", Vector2.ZERO)
	var corpse = CorpseScr.new()
	corpse.configure(inv, trade, inv_bal)
	var loot = LootScr.new()
	loot.configure(null, corpse, inv, inst, CombatBalanceScr.new())
	if loot.level_to_loot_tier(97) != 20:
		_free_node(loot)
		_free_node(corpse)
		_free_node(trade)
		_free_node(inv)
		_free_node(inst)
		_free_node(cat)
		_free_node(reg)
		return false
	loot.register_corpse_with_drops(&"corpse_test", Vector2(200.0, 0.0), 20)
	var bag: Array = corpse.get_corpse_bag(&"corpse_test")
	var too_far: bool = corpse.loot_bag_slot_to_character(&"loot_u", &"corpse_test", 0) == FAILED
	trade.set_character_position(&"loot_u", Vector2(200.0, 0.0))
	var ok: bool = too_far and not bag.is_empty() and corpse.loot_bag_slot_to_character(&"loot_u", &"corpse_test", 0) == OK
	ok = ok and inv.get_cell(&"loot_u", 0) != null
	_free_node(loot)
	_free_node(corpse)
	_free_node(trade)
	_free_node(inv)
	_free_node(inst)
	_free_node(cat)
	_free_node(reg)
	return ok


func _test_trade_range_gate() -> bool:
	var inv_bal = load("res://data/default_inventory_balance.tres") as Resource
	var reg = CharacterRegistryScr.new()
	reg.configure(_balance())
	var cat = CatScr.new()
	cat.ensure_items()
	var inv = InventoryScr.new()
	inv.configure(cat, reg, inv_bal)
	var trade = TradeScr.new()
	trade.configure(inv, inv_bal)
	var limit: float = float(inv_bal.trade_range)
	trade.set_character_position(&"a", Vector2.ZERO)
	trade.set_character_position(&"b", Vector2(limit + 20.0, 0.0))
	if trade.are_in_trade_range(&"a", &"b"):
		_free_node(trade)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	trade.set_character_position(&"b", Vector2(limit * 0.5, 0.0))
	var ok: bool = trade.are_in_trade_range(&"a", &"b")
	_free_node(trade)
	_free_node(inv)
	_free_node(cat)
	_free_node(reg)
	return ok


func _test_ground_item_decay() -> bool:
	var inv_bal = load("res://data/default_inventory_balance.tres") as Resource
	var reg = CharacterRegistryScr.new()
	reg.configure(_balance())
	var cat = CatScr.new()
	cat.ensure_items()
	var inv = InventoryScr.new()
	inv.configure(cat, reg, inv_bal)
	var ground = GroundScr.new()
	ground.configure(cat, inv, inv_bal)
	ground.spawn_drop(&"scrap", 1, Vector2(10, 10), 0.4)
	if ground.get_drop_count() != 1:
		_free_node(ground)
		_free_node(inv)
		_free_node(cat)
		_free_node(reg)
		return false
	ground._process(0.5)
	var ok: bool = ground.get_drop_count() == 0
	_free_node(ground)
	_free_node(inv)
	_free_node(cat)
	_free_node(reg)
	return ok
