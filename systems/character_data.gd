class_name CharacterData
extends Resource

const _Schema := preload("res://scripts/character_schema.gd")

## Authoritative character sheet: identity, attributes, skills, vitals, burden.

@export var character_id: String = ""
@export var user_name: String = "New character"
@export var is_logged_in: bool = true

@export var level: int = 1
## Lifetime XP (never decreases). Drives character level only.
@export var total_experience: int = 0
## Spendable XP pool; increases when XP is awarded, decreases when buying ranks.
@export var unspent_experience: int = 0

@export var attributes: Dictionary = {}
@export var attribute_xp: Dictionary = {}
## Times each attribute was raised by spending unspent XP (not creation points).
@export var attribute_xp_purchases: Dictionary = {}
## Times each vital pool was raised by spending unspent XP (keys: health, stamina, mana).
@export var vital_xp_purchases: Dictionary = {}

@export var skill_levels: Dictionary = {}
@export var skill_xp: Dictionary = {}
## Times each skill rank was bought with unspent XP (cost tier); not buffs or other sources.
@export var skill_xp_purchases: Dictionary = {}
## Temporary bonuses (buffs). Added to base attribute/skill for display and checks; tune serialization via `version`.
@export var transient_attribute_bonus: Dictionary = {}
@export var transient_skill_bonus: Dictionary = {}
## Spell ids (string keys) learned from scrolls / training.
@export var known_spells: PackedStringArray = PackedStringArray()

@export var current_health: float = 0.0
@export var current_stamina: float = 0.0
@export var current_mana: float = 0.0
@export var laden_burden: float = 0.0
@export var gold: int = 0

@export var portrait_texture: Texture2D
@export var meta: Dictionary = {}


func _init() -> void:
	ensure_defaults()


func ensure_defaults() -> void:
	if character_id.is_empty():
		character_id = "char_%d" % Time.get_ticks_msec()
	for attr in _Schema.ALL_ATTRIBUTES:
		if not attributes.has(attr):
			attributes[attr] = 10
		if not attribute_xp.has(attr):
			attribute_xp[attr] = 0
		if not attribute_xp_purchases.has(attr):
			attribute_xp_purchases[attr] = 0
	for vk in ["health", "stamina", "mana"]:
		if not vital_xp_purchases.has(vk):
			vital_xp_purchases[vk] = 0
	for skill in _Schema.ALL_SKILLS:
		if not skill_levels.has(skill):
			skill_levels[skill] = 0
		if not skill_xp.has(skill):
			skill_xp[skill] = 0
		if not skill_xp_purchases.has(skill):
			skill_xp_purchases[skill] = 0
	if current_health <= 0.0:
		current_health = 1.0
	if current_stamina <= 0.0:
		current_stamina = 1.0
	if current_mana < 0.0:
		current_mana = 0.0


func knows_spell(spell_id: StringName) -> bool:
	return known_spells.has(String(spell_id))


func learn_spell(spell_id: StringName) -> bool:
	var s: String = String(spell_id)
	if s.is_empty() or known_spells.has(s):
		return false
	known_spells.append(s)
	return true


func get_effective_attribute(attr_id: StringName) -> int:
	return int(attributes.get(attr_id, 10)) + int(transient_attribute_bonus.get(attr_id, 0))


## Bought XP ranks plus transient buff ranks only — not the attribute-derived modifier (see StatsSystem `skill_modifiers`).
func get_effective_skill_rank(skill_id: StringName) -> int:
	return int(skill_levels.get(skill_id, 0)) + int(transient_skill_bonus.get(skill_id, 0))


func duplicate_data() -> Resource:
	var copy: Resource = duplicate(true) as Resource
	copy.ensure_defaults()
	return copy


func to_dictionary() -> Dictionary:
	return {
		"version": 7,
		"character_id": character_id,
		"user_name": user_name,
		"is_logged_in": is_logged_in,
		"level": level,
		"total_experience": total_experience,
		"unspent_experience": unspent_experience,
		"attributes": attributes.duplicate(true),
		"attribute_xp": attribute_xp.duplicate(true),
		"attribute_xp_purchases": attribute_xp_purchases.duplicate(true),
		"vital_xp_purchases": vital_xp_purchases.duplicate(true),
		"skill_levels": skill_levels.duplicate(true),
		"skill_xp": skill_xp.duplicate(true),
		"skill_xp_purchases": skill_xp_purchases.duplicate(true),
		"transient_attribute_bonus": transient_attribute_bonus.duplicate(true),
		"transient_skill_bonus": transient_skill_bonus.duplicate(true),
		"known_spells": Array(known_spells),
		"current_health": current_health,
		"current_stamina": current_stamina,
		"current_mana": current_mana,
		"laden_burden": laden_burden,
		"gold": gold,
		"meta": meta.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> Resource:
	var scr: GDScript = load("res://systems/character_data.gd") as GDScript
	var cd: Resource = scr.new()
	cd.character_id = String(data.get("character_id", ""))
	cd.user_name = String(data.get("user_name", "New character"))
	cd.is_logged_in = bool(data.get("is_logged_in", true))
	cd.level = int(data.get("level", 1))
	cd.total_experience = int(data.get("total_experience", 0))
	var ver: int = int(data.get("version", 1))
	if data.has("unspent_experience"):
		cd.unspent_experience = int(data.get("unspent_experience", 0))
	elif ver < 3:
		## Legacy: treat all earned XP as spendable; level remains from total_experience.
		cd.unspent_experience = maxi(0, cd.total_experience)
	else:
		cd.unspent_experience = 0
	cd.attributes = (data.get("attributes", {}) as Dictionary).duplicate(true)
	cd.attribute_xp = (data.get("attribute_xp", {}) as Dictionary).duplicate(true)
	if ver >= 6:
		cd.attribute_xp_purchases = (data.get("attribute_xp_purchases", {}) as Dictionary).duplicate(true)
		cd.vital_xp_purchases = (data.get("vital_xp_purchases", {}) as Dictionary).duplicate(true)
	else:
		cd.attribute_xp_purchases = {}
		cd.vital_xp_purchases = {}
	cd.skill_levels = (data.get("skill_levels", {}) as Dictionary).duplicate(true)
	cd.skill_xp = (data.get("skill_xp", {}) as Dictionary).duplicate(true)
	if ver >= 7:
		cd.skill_xp_purchases = (data.get("skill_xp_purchases", {}) as Dictionary).duplicate(true)
	elif ver >= 6:
		## Skills had no separate purchase counter; assume each rank was bought with XP.
		cd.skill_xp_purchases = {}
		for sk in _Schema.ALL_SKILLS:
			cd.skill_xp_purchases[sk] = int(cd.skill_levels.get(sk, 0))
	else:
		cd.skill_xp_purchases = {}
	if ver >= 4:
		cd.transient_attribute_bonus = (data.get("transient_attribute_bonus", {}) as Dictionary).duplicate(true)
		cd.transient_skill_bonus = (data.get("transient_skill_bonus", {}) as Dictionary).duplicate(true)
	if ver >= 5:
		cd.known_spells = PackedStringArray(data.get("known_spells", []) as Array)
	cd.current_health = float(data.get("current_health", 1.0))
	cd.current_stamina = float(data.get("current_stamina", 1.0))
	cd.current_mana = float(data.get("current_mana", 0.0))
	cd.laden_burden = float(data.get("laden_burden", 0.0))
	cd.gold = int(data.get("gold", 0))
	cd.meta = (data.get("meta", {}) as Dictionary).duplicate(true)
	cd.ensure_defaults()
	return cd
