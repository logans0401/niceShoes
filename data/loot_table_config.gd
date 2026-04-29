class_name LootTableConfig
extends Resource

@export var tier_pools: Dictionary = {}


func get_pool_for_tier(tier: int) -> Array:
	var t: int = clampi(tier, 1, 20)
	if tier_pools.has(t):
		return tier_pools[t] as Array
	if tier_pools.has(str(t)):
		return tier_pools[str(t)] as Array
	var base: Array = [&"scrap", &"leather_cap", &"iron_sword", &"short_bow"]
	if t >= 4:
		base.append(&"wood_shield")
	if t >= 8:
		base.append(&"crossbow")
	if t >= 10:
		base.append(&"oak_wand")
	if t >= 14:
		base.append(&"focus_orb")
	return base
