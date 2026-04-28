extends RefCounted
class_name CharacterSchema

const MAX_CHARACTERS: int = 13
const MIN_PARTY_SIZE: int = 2
const MAX_PARTY_SIZE: int = 4
const MAX_LEVEL: int = 100

const ATTRIBUTE_STRENGTH := "strength"
const ATTRIBUTE_HEARTINESS := "heartiness"
const ATTRIBUTE_ABILITY := "ability"
const ATTRIBUTE_REFLEXES := "reflexes"
const ATTRIBUTE_MIND := "mind"
const ATTRIBUTE_WISDOM := "wisdom"

const SKILL_COOKING := "cooking"
const SKILL_ALCHEMY := "alchemy"
const SKILL_FLETCHING := "fletching"
const SKILL_MELEE_COMBAT := "melee_combat"
const SKILL_MISSILE_COMBAT := "missile_combat"
const SKILL_MAGIC_COMBAT := "magic_combat"
const SKILL_MAGIC_SUPPORT := "magic_support"
const SKILL_MELEE_DEFENSE := "melee_defense"
const SKILL_MAGIC_DEFENSE := "magic_defense"
const SKILL_MISSILE_DEFENSE := "missile_defense"
const SKILL_ARCANE_CONNECTION := "arcane_connection"

## Plain literal arrays — `PackedStringArray([...])` is not a const expression in GDScript 4.6.
const ALL_ATTRIBUTES: Array[String] = ["strength", "heartiness", "ability", "reflexes", "mind", "wisdom"]

const ALL_SKILLS: Array[String] = [
	"cooking",
	"alchemy",
	"fletching",
	"melee_combat",
	"missile_combat",
	"magic_combat",
	"magic_support",
	"melee_defense",
	"magic_defense",
	"missile_defense",
	"arcane_connection",
]


static func all_attributes() -> PackedStringArray:
	return PackedStringArray(ALL_ATTRIBUTES)


static func all_skills() -> PackedStringArray:
	return PackedStringArray(ALL_SKILLS)
