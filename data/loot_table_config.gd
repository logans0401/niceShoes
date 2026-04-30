class_name LootTableConfig
extends Resource

@export var tier_pools: Dictionary = {}


func get_pool_for_tier(tier: int) -> Array:
	var t: int = clampi(tier, 1, 20)
	if tier_pools.has(t):
		return tier_pools[t] as Array
	if tier_pools.has(str(t)):
		return tier_pools[str(t)] as Array
	var base: Array = [
		{"item_id": &"scrap", "weight": 8},
		{"item_id": &"leather_cap", "weight": 5},
		{"item_id": &"iron_sword", "weight": 4},
		{"item_id": &"short_bow", "weight": 4},
		{"item_id": &"bronze_bracelet", "weight": 2},
		{"item_id": &"copper_ring", "weight": 2},
	]
	if t >= 4:
		base.append({"item_id": &"wood_shield", "weight": 5})
	if t >= 8:
		base.append({"item_id": &"crossbow", "weight": 4})
		base.append({"item_id": &"silver_necklace", "weight": 2})
	if t >= 10:
		base.append({"item_id": &"oak_wand", "weight": 4})
		base.append({"item_id": &"gold_ring", "weight": 1})
	if t >= 14:
		base.append({"item_id": &"focus_orb", "weight": 4})
		base.append({"item_id": &"onyx_ring", "weight": 1})
	return base
