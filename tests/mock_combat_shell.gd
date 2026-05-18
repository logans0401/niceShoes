extends Node
## Minimal shell stub for headless enemy retaliation tests.

var enemy_melee_called: bool = false


func try_enemy_melee_character(_enemy: Node, _victim_id: StringName) -> bool:
	enemy_melee_called = true
	return true
