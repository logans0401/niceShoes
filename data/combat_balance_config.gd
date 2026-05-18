class_name CombatBalanceConfig
extends Resource

const AREA_HEAD := &"head"
const AREA_SHOULDERS := &"shoulders"
const AREA_CHEST := &"chest"
const AREA_WAIST := &"waist"
const AREA_LEGS := &"legs"
const AREA_FEET := &"feet"
const AREA_HANDS := &"hands"

const BODY_AREAS: Array[StringName] = [
	AREA_HEAD,
	AREA_SHOULDERS,
	AREA_CHEST,
	AREA_WAIST,
	AREA_LEGS,
	AREA_FEET,
	AREA_HANDS,
]

@export var unarmed_attack_interval_sec: float = 5.0
@export var death_penalty_per_death: float = 0.05
@export var death_penalty_max: float = 0.35
## Each XP point reduces penalty by this percent (0.01 = one percentage point per XP).
@export var death_penalty_recovery_per_xp: float = 0.0005
@export var minimum_post_death_health: float = 1.0

## Armor mitigation: damage -= armor_level * scale + damage_type_rating * scale.
@export var armor_level_mitigation_scale: float = 0.08
@export var armor_rating_mitigation_scale: float = 0.18
@export var minimum_damage_after_mitigation: float = 0.5

## Melee hit base: weapon roll + melee_combat * scale - melee_defense * scale (see CombatSystem).
@export var melee_skill_damage_scale: float = 0.08
@export var melee_defense_damage_scale: float = 0.06
## Legacy fallback when only attack_rating / defense_rating are passed (matches CharacterBalanceConfig).
@export var legacy_attack_rating_skill_scale: float = 1.65
@export var legacy_defense_rating_skill_scale: float = 1.5


func pick_body_area() -> StringName:
	return BODY_AREAS[randi_range(0, BODY_AREAS.size() - 1)]


func level_to_loot_tier(level: int) -> int:
	return clampi(int(ceil(float(maxi(1, level)) / 5.0)), 1, 20)
