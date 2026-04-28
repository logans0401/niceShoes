extends CharacterBody2D
class_name CombatTestEnemy
## Placeholder enemy for combat testing. Hostile AI strikes on its own cadence once provoked.

@export var max_health: float = 42.0
@export var attack_rating: float = 7.0
@export var defense_rating: float = 3.5
## Secret weapon profile for damage rolls (not shown to player unless you document it on the scene).
@export var hidden_damage_min: int = 1
@export var hidden_damage_max: int = 3
@export var hidden_damage_type: int = 0
## Seconds between enemy melee attempts (when in range and hostile).
@export var attack_interval_sec: float = 1.35
## Must match player melee reach for fair exchanges.
@export var melee_range_px: float = 56.0
@export var xp_reward: int = 18

var current_health: float = 0.0
## character_id -> true when this enemy will fight that character (typically after being hit by them).
var _hostile_to: Dictionary = {}
## character_id -> true only after that character has landed a damaging hit on this enemy (retaliation gate).
var _landed_hit_from: Dictionary = {}
## character_id -> true after this enemy has dealt melee damage to that character (keeps aggro for assist / AI).
var _aggressed_against: Dictionary = {}
var _attack_cd: float = 0.0

@onready var _glyph: Polygon2D = $Glyph


func _ready() -> void:
	add_to_group(&"combat_enemies")
	current_health = max_health
	_refresh_glyph()


func get_combat_stats() -> Dictionary:
	return {
		"attack_rating": attack_rating,
		"defense_rating": defense_rating,
		"weapon_damage_min": hidden_damage_min,
		"weapon_damage_max": hidden_damage_max,
		"damage_type": hidden_damage_type,
	}


func set_hostile_toward(character_id: StringName, hostile: bool = true) -> void:
	if character_id == &"":
		return
	_hostile_to[character_id] = hostile
	if not hostile:
		_hostile_to.erase(character_id)


func is_hostile_toward(character_id: StringName) -> bool:
	return bool(_hostile_to.get(character_id, false))


func has_landed_hit_from(character_id: StringName) -> bool:
	return bool(_landed_hit_from.get(character_id, false))


func register_aggro_against(character_id: StringName) -> void:
	if character_id == &"":
		return
	_aggressed_against[character_id] = true
	set_hostile_toward(character_id, true)


func is_engaged_with(character_id: StringName) -> bool:
	if character_id == &"":
		return false
	if bool(_aggressed_against.get(character_id, false)):
		return true
	if is_hostile_toward(character_id):
		return true
	if has_landed_hit_from(character_id):
		return true
	return false


## Hook for future reputation / faction rules.
func can_attack_target(_character_id: StringName) -> bool:
	return true


func take_damage(amount: float, attacker_id: StringName = &"") -> bool:
	if amount <= 0.0:
		return current_health > 0.0
	current_health = maxf(0.0, current_health - amount)
	if attacker_id != &"":
		_landed_hit_from[attacker_id] = true
		set_hostile_toward(attacker_id, true)
	_flash_glyph()
	_refresh_glyph()
	if current_health <= 0.0:
		queue_free()
		return false
	return true


func tick_hostile_combat(delta: float, shell: Node) -> void:
	if shell == null:
		return
	## Drop hostility toward characters who never landed a damaging hit (no retaliation without provocation).
	var drop: Array = []
	for cid_key in _hostile_to.keys():
		var cid0: StringName = cid_key as StringName
		if not bool(_hostile_to[cid_key]):
			continue
		if not has_landed_hit_from(cid0) and not bool(_aggressed_against.get(cid0, false)):
			drop.append(cid0)
	for cid_drop_v in drop:
		var cid_drop: StringName = cid_drop_v as StringName
		set_hostile_toward(cid_drop, false)
	if _hostile_to.is_empty():
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _attack_cd > 0.0:
		return
	for cid_key in _hostile_to.keys():
		if not bool(_hostile_to[cid_key]):
			continue
		var cid: StringName = cid_key as StringName
		if not has_landed_hit_from(cid):
			continue
		if not can_attack_target(cid):
			continue
		if not shell.has_method("try_enemy_melee_character"):
			return
		if not bool(shell.call("try_enemy_melee_character", self, cid)):
			continue
		_attack_cd = attack_interval_sec
		return


func _flash_glyph() -> void:
	if _glyph == null:
		return
	var t := create_tween()
	_glyph.modulate = Color(1.5, 1.5, 1.5, 1.0)
	t.tween_property(_glyph, "modulate", Color.WHITE, 0.12)


func _refresh_glyph() -> void:
	if _glyph == null:
		return
	var t: float = clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	_glyph.color = Color(0.35 + 0.4 * t, 0.12, 0.15 + 0.25 * t, 1.0)
