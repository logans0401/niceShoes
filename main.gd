extends Node

@onready var _systems: Node = $Systems
@onready var _shell: Control = $UI


func _ready() -> void:
	_bootstrap_systems()
	_seed_demo_content()
	_wire_systems_to_ui()
	_sync_all_character_vitals_from_stats()


func _bootstrap_systems() -> void:
	var balance: CharacterBalanceConfig = load("res://data/default_character_balance.tres") as CharacterBalanceConfig
	var inv_balance: InventoryBalanceConfig = load("res://data/default_inventory_balance.tres") as InventoryBalanceConfig
	var registry: CharacterRegistrySystem = _systems.get_node("CharacterRegistrySystem") as CharacterRegistrySystem
	var progression: CharacterProgressionSystem = _systems.get_node("CharacterProgressionSystem") as CharacterProgressionSystem
	var group: GroupSystem = _systems.get_node("GroupSystem") as GroupSystem
	var skills: SkillSystem = _systems.get_node("SkillSystem") as SkillSystem
	var stats: StatsSystem = _systems.get_node("StatsSystem") as StatsSystem
	var catalog: ItemCatalog = _systems.get_node("ItemCatalog") as ItemCatalog
	var item_instances: Node = _systems.get_node("ItemInstanceSystem")
	var inventory: InventorySystem = _systems.get_node("InventorySystem") as InventorySystem
	var equipment: EquipmentSystem = _systems.get_node("EquipmentSystem") as EquipmentSystem
	var trade: TradeSystem = _systems.get_node("TradeSystem") as TradeSystem
	var merchant: MerchantSystem = _systems.get_node("MerchantSystem") as MerchantSystem
	var ground: GroundItemsSystem = _systems.get_node("GroundItemsSystem") as GroundItemsSystem
	var corpse: CorpseLootSystem = _systems.get_node("CorpseLootSystem") as CorpseLootSystem
	var loot: LootSystem = _systems.get_node("LootSystem") as LootSystem
	var combat_balance: Resource = load("res://data/default_combat_balance.tres") as Resource

	registry.configure(balance)
	progression.configure(registry, balance, combat_balance)
	group.configure(registry)
	skills.configure(registry)
	stats.configure(balance)
	stats.configure_inventory_penalties(inv_balance)
	stats.configure_combat_balance(combat_balance)

	item_instances.configure(catalog)
	inventory.configure(catalog, registry, inv_balance, item_instances)
	equipment.configure(inventory, catalog, item_instances)
	inventory.attach_equipment(equipment)

	trade.configure(inventory, inv_balance)
	merchant.configure(catalog, inventory, registry, item_instances)
	ground.configure(catalog, inventory, inv_balance)
	corpse.configure(inventory, trade, inv_balance)
	loot.configure(ground, corpse, inventory, item_instances, combat_balance)
	var combat: CombatSystem = _systems.get_node("CombatSystem") as CombatSystem
	combat.configure(combat_balance)

	inventory.inventory_changed.connect(stats.invalidate)
	equipment.equipment_changed.connect(stats.invalidate)
	_wire_progression_to_stats(progression, stats)


func _seed_demo_content() -> void:
	var merchant: MerchantSystem = _systems.get_node("MerchantSystem") as MerchantSystem

	var quest: QuestSystem = _systems.get_node("QuestSystem") as QuestSystem
	if quest != null:
		quest.seed_demo_journal()

	merchant.set_merchant_stock(
		&"default_merchant",
		[
			{"item_id": "scrap", "quantity": 999},
			{"item_id": "iron_sword", "quantity": 999},
			{"item_id": "wood_shield", "quantity": 999},
			{"item_id": "leather_cap", "quantity": 999},
			{"item_id": "scroll_all_spells", "quantity": 999},
		],
	)


func _wire_progression_to_stats(progression: CharacterProgressionSystem, stats: StatsSystem) -> void:
	if progression == null or stats == null:
		return
	progression.attribute_changed.connect(func(cid, _aid, _v): stats.invalidate(cid))
	progression.skill_rank_changed.connect(func(cid, _sid, _r): stats.invalidate(cid))
	progression.level_changed.connect(func(cid, _lv): stats.invalidate(cid))


func _sync_all_character_vitals_from_stats() -> void:
	## Demo / loaded characters never run the creation dialog — align pools to derived maxima once systems exist.
	var registry: CharacterRegistrySystem = _systems.get_node("CharacterRegistrySystem") as CharacterRegistrySystem
	var stats: StatsSystem = _systems.get_node("StatsSystem") as StatsSystem
	var equipment: EquipmentSystem = _systems.get_node("EquipmentSystem") as EquipmentSystem
	if registry == null or stats == null or equipment == null:
		return
	for cid in registry.list_character_ids():
		var data: Resource = registry.get_character(cid)
		if data == null:
			continue
		var st: Dictionary = stats.get_effective_stats(cid, data, equipment)
		data.current_health = float(st.get("max_health", data.current_health))
		data.current_stamina = float(st.get("max_stamina", data.current_stamina))
		data.current_mana = float(st.get("max_mana", data.current_mana))
		stats.invalidate(cid)


func _wire_systems_to_ui() -> void:
	var automation: AutomationSystem = _systems.get_node_or_null("AutomationSystem") as AutomationSystem
	var registry: CharacterRegistrySystem = _systems.get_node("CharacterRegistrySystem") as CharacterRegistrySystem
	var group: GroupSystem = _systems.get_node("GroupSystem") as GroupSystem
	var progression: CharacterProgressionSystem = _systems.get_node("CharacterProgressionSystem") as CharacterProgressionSystem
	if automation != null:
		automation.configure(registry, group)
	if automation != null and _shell.has_method("bind_automation_system"):
		_shell.bind_automation_system(automation, registry, group)

	var balance: CharacterBalanceConfig = load("res://data/default_character_balance.tres") as CharacterBalanceConfig
	var inv_balance: InventoryBalanceConfig = load("res://data/default_inventory_balance.tres") as InventoryBalanceConfig
	var inventory: InventorySystem = _systems.get_node("InventorySystem") as InventorySystem
	var equipment: EquipmentSystem = _systems.get_node("EquipmentSystem") as EquipmentSystem
	var catalog: ItemCatalog = _systems.get_node("ItemCatalog") as ItemCatalog
	var stats: StatsSystem = _systems.get_node("StatsSystem") as StatsSystem
	var item_instances: Node = _systems.get_node("ItemInstanceSystem")
	var corpse: CorpseLootSystem = _systems.get_node("CorpseLootSystem") as CorpseLootSystem
	var loot: LootSystem = _systems.get_node("LootSystem") as LootSystem

	if _shell.has_method("bind_progression_system"):
		_shell.bind_progression_system(progression, balance)

	var quest: QuestSystem = _systems.get_node("QuestSystem") as QuestSystem
	if _shell.has_method("bind_quest_system"):
		_shell.bind_quest_system(quest)

	if not _shell.has_method(&"bind_inventory_ui"):
		push_error("Main: UI root is missing bind_inventory_ui — is res://ui/main_shell.gd attached?")
	else:
		var ids: PackedStringArray = registry.list_character_ids()
		var focus: StringName = &""
		if ids.size() > 0:
			focus = ids[0]
		_shell.bind_inventory_ui(registry, inventory, equipment, catalog, stats, balance, inv_balance, focus, item_instances)
	if _shell.has_method("bind_combat_system"):
		var combat: CombatSystem = _systems.get_node("CombatSystem") as CombatSystem
		_shell.bind_combat_system(combat)

	var merchant_bind: MerchantSystem = _systems.get_node("MerchantSystem") as MerchantSystem
	if merchant_bind != null and _shell.has_method("bind_merchant_system"):
		_shell.bind_merchant_system(merchant_bind)
	var trade_bind: TradeSystem = _systems.get_node("TradeSystem") as TradeSystem
	if trade_bind != null and _shell.has_method("bind_trade_system"):
		_shell.bind_trade_system(trade_bind)
	if _shell.has_method("bind_loot_systems"):
		_shell.bind_loot_systems(loot, corpse)
