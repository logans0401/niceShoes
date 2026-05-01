class_name QuestSystem
extends Node

enum QuestState { INACTIVE, ACTIVE, COMPLETED, FAILED }

signal quest_state_changed(quest_id: StringName, new_state: int)

## Static catalog for journal UI (id -> title, description).
const QUEST_CATALOG: Dictionary = {
	&"demo_gate":
	{
		"title": "Secure the northern gate",
		"description": "Hold the post until relief arrives. Keep the approach clear of hostiles.",
	},
	&"demo_supplies":
	{
		"title": "Deliver supplies to camp",
		"description":
		"Carry rations to the forward camp without losing the cart to bandits or mud.",
	},
	&"demo_road":
	{
		"title": "Map the sunken road",
		"description":
		"Survey the flooded causeway and return with a marked safe route for wagons.",
	},
}

## quest_id -> state
var _states: Dictionary = {}
## quest_id -> runtime payload (objective index, timers, etc.)
var _runtime: Dictionary = {}


func get_state(quest_id: StringName) -> int:
	return int(_states.get(quest_id, QuestState.INACTIVE))


func get_quest_title(quest_id: StringName) -> String:
	var e: Variant = QUEST_CATALOG.get(quest_id)
	if e == null:
		return String(quest_id)
	return String((e as Dictionary).get("title", quest_id))


func get_quest_description(quest_id: StringName) -> String:
	var e: Variant = QUEST_CATALOG.get(quest_id)
	if e == null:
		return "No description available."
	return String((e as Dictionary).get("description", ""))


func get_journal_rows_ordered() -> Array:
	var active: Array = []
	var done: Array = []
	var failed: Array = []
	for qid in QUEST_CATALOG.keys():
		var st: int = get_state(qid)
		if st == QuestState.INACTIVE:
			continue
		var title: String = get_quest_title(qid)
		var row: Dictionary = {"id": qid, "state": st, "title": title}
		match st:
			QuestState.ACTIVE:
				active.append(row)
			QuestState.COMPLETED:
				done.append(row)
			QuestState.FAILED:
				failed.append(row)
			_:
				pass
	var out: Array = []
	out.append_array(active)
	out.append_array(done)
	out.append_array(failed)
	return out


func activate(quest_id: StringName) -> void:
	_states[quest_id] = QuestState.ACTIVE
	_runtime[quest_id] = {"objective_index": 0}
	quest_state_changed.emit(quest_id, QuestState.ACTIVE)


func complete(quest_id: StringName) -> void:
	_states[quest_id] = QuestState.COMPLETED
	_runtime.erase(quest_id)
	quest_state_changed.emit(quest_id, QuestState.COMPLETED)


func fail(quest_id: StringName) -> void:
	_states[quest_id] = QuestState.FAILED
	_runtime.erase(quest_id)
	quest_state_changed.emit(quest_id, QuestState.FAILED)


func abandon(quest_id: StringName) -> void:
	if get_state(quest_id) != QuestState.ACTIVE:
		return
	_states[quest_id] = QuestState.INACTIVE
	_runtime.erase(quest_id)
	quest_state_changed.emit(quest_id, QuestState.INACTIVE)


## Demo seed: one active, one completed, one failed (for journal UI).
func seed_demo_journal() -> void:
	_states.clear()
	_runtime.clear()
	activate(&"demo_gate")
	_states[&"demo_supplies"] = QuestState.COMPLETED
	_runtime.erase(&"demo_supplies")
	_states[&"demo_road"] = QuestState.FAILED
	_runtime.erase(&"demo_road")
