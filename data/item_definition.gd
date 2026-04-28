class_name ItemDefinition
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
@export var weight: float = 1.0
@export var max_stack: int = 99
## Empty string if not equippable; otherwise must match EquipmentSchema slot id.
@export var equip_slot: String = ""
## melee | missile | casting (wand/orb) | empty if not a weapon
@export var weapon_kind: String = ""
## Rolled on hit (inclusive). Ignored if both zero (legacy combat uses stats only).
@export var damage_min: int = 0
@export var damage_max: int = 0
## `DamageTypes.Id` when this weapon strikes (default slashing).
@export var damage_type: int = 0
## If set, this scroll teaches the spell id when read (consumes scroll).
@export var scroll_teaches_spell: String = ""
@export var buy_price: int = 10
@export var sell_price: int = 3
