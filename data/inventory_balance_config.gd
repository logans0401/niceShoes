class_name InventoryBalanceConfig
extends Resource

@export_group("Bag / world")
@export var bag_slot_count: int = 24
@export var trade_range: float = 96.0
@export var ground_item_decay_seconds: float = 120.0
@export var pickup_radius: float = 48.0

@export_group("Burden penalties")
## Below this carry ratio (laden/capacity), no penalties.
@export var burden_penalty_start_ratio: float = 0.55
## At or above this ratio, penalty blend reaches full strength (t=1).
@export var burden_penalty_full_ratio: float = 1.0
## If carry ratio exceeds 1.0, penalty can keep scaling until this ratio.
@export var burden_penalty_overcap_ratio: float = 1.5
@export var movement_speed_min_mult: float = 0.55
@export var attack_speed_min_mult: float = 0.62
@export var stamina_cost_max_mult: float = 1.75
@export var defense_skill_min_mult: float = 0.72
@export var health_regen_min_mult: float = 0.55
@export var stamina_regen_min_mult: float = 0.55


func get_burden_ratio(laden: float, capacity: float) -> float:
	var cap: float = maxf(capacity, 0.001)
	return maxf(0.0, laden / cap)


func _penalty_blend_t(ratio: float) -> float:
	if ratio <= burden_penalty_start_ratio:
		return 0.0
	var span: float = maxf(0.001, burden_penalty_full_ratio - burden_penalty_start_ratio)
	var t_primary: float = clampf((ratio - burden_penalty_start_ratio) / span, 0.0, 1.0)
	if ratio <= burden_penalty_full_ratio:
		return t_primary
	var over_span: float = maxf(0.001, burden_penalty_overcap_ratio - burden_penalty_full_ratio)
	var t_over: float = clampf((ratio - burden_penalty_full_ratio) / over_span, 0.0, 1.0)
	return clampf(t_primary + t_over * 0.35, 0.0, 1.35)


## Returns multipliers. Values <= 1 mean slower/weaker except stamina_cost which rises above 1.
func get_penalty_multipliers(ratio: float) -> Dictionary:
	var t: float = clampf(_penalty_blend_t(ratio), 0.0, 1.35)
	var k: float = clampf(t, 0.0, 1.0)
	return {
		"movement_speed_multiplier": lerpf(1.0, movement_speed_min_mult, k),
		"attack_speed_multiplier": lerpf(1.0, attack_speed_min_mult, k),
		"stamina_use_multiplier": lerpf(1.0, stamina_cost_max_mult, k),
		"defense_skill_multiplier": lerpf(1.0, defense_skill_min_mult, k),
		"health_regen_multiplier": lerpf(1.0, health_regen_min_mult, k),
		"stamina_regen_multiplier": lerpf(1.0, stamina_regen_min_mult, k),
		"burden_ratio": ratio,
		"burden_penalty_t": t,
	}
