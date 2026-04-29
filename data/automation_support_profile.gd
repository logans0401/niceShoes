class_name AutomationSupportProfile
extends Resource

## Character that runs automation and may react to ally vitals.
@export var supporter_character_id: StringName = &""
## Allies to watch (stats pulled from registry + StatsSystem).
@export var ally_character_ids: PackedStringArray = PackedStringArray()
@export var hp_below_ratio: float = 0.35
## Set to < 0 to ignore mana checks.
@export var mana_below_ratio: float = -1.0
@export var cooldown_seconds: float = 2.5
@export var support_task_sim_ticks: int = 1
@export var support_label: String = "Reactive support"
