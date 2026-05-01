class_name AutomationSystem
extends Node

## Multi-runner automation: each `runner_id` (character or `group:<id>`) has its own queue,
## interrupt stack, history, and status log. `tick` / `tick_all` advance simulation steps.

signal task_enqueued(runner_id: StringName, task: Variant)
signal task_started(runner_id: StringName, task: Variant)
signal task_finished(runner_id: StringName, task: Variant, success: bool)
signal task_interrupted(runner_id: StringName, task: Variant)
signal task_resumed(runner_id: StringName, task: Variant)
signal status_logged(runner_id: StringName, message: String)
signal queue_changed
signal runner_queue_changed(runner_id: StringName)
## Emitted once per tick while a world-driven HUNT task is active (not `sim_only`). UI/world resolves
## targets and may mutate `task.data` (e.g. `kills_achieved`).
signal hunt_world_pulse(runner_id: StringName, task: Variant)
## Emitted once per tick while ASSIST_COMBAT is active; shell steers the runner's character toward
## enemies threatening `task.data["ally_character_id"]`.
signal assist_world_pulse(runner_id: StringName, task: Variant)

const PREVIOUS_TASK_CAP: int = 24
const STATUS_LOG_CAP: int = 48
const _GROUP_PREFIX := "group:"

enum TaskType {
	IDLE,
	MOVE_TO,
	INTERACT,
	WAIT,
	NAVIGATE_MAP,
	USE_PORTAL,
	HUNT,
	SEARCH_LOOT,
	COMPLETE_QUEST,
	SELL_EXCESS_LOOT,
	SHARE_LOOT_GROUP,
	SUPPORT_ALLY,
	## Move toward another logged-in character's world position (driven by UI/world each frame).
	FOLLOW_CHARACTER,
	## Fight enemies that the ally has engaged (hostile toward ally) or that threaten them nearby.
	ASSIST_COMBAT,
}


class AutomationTask:
	static var _id_seq: int = 1

	var task_id: int
	var type: int = TaskType.IDLE
	## Higher runs first; ties broken by lower task_id.
	var priority: int = 0
	var interruptible: bool = true
	var data: Dictionary = {}
	var label: String = ""
	## When true, a fresh copy of this task is enqueued after it finishes successfully.
	var continuous: bool = false

	func _init() -> void:
		task_id = _id_seq
		_id_seq += 1


class _QueueState:
	var runner_id: StringName
	var queue: Array = []
	var active: AutomationTask = null
	var suspended: Array = []
	var previous: Array = []
	var status_messages: Array = []


var _runners: Dictionary = {}
var _default_runner_id: StringName = &"default"
var _registry: Node = null
var _group_system: Node = null
## When true for a runner, queued tasks are not promoted to active (build a queue, then call set_dispatch_held(id, false)).
var _dispatch_held: Dictionary = {}
## When true, each tick may suspend an interruptible active task if the sorted queue head has higher priority (queue vs active).
@export var queue_preempts_lower_priority_active: bool = false


func configure(registry: Node = null, group_system: Node = null) -> void:
	_registry = registry
	_group_system = group_system


func set_dispatch_held(runner_id: StringName, held: bool) -> void:
	_dispatch_held[runner_id] = held


func is_dispatch_held(runner_id: StringName) -> bool:
	return bool(_dispatch_held.get(runner_id, false))


func set_default_runner(runner_id: StringName) -> void:
	_default_runner_id = runner_id
	ensure_runner(runner_id)


static func group_runner_id(group_id: StringName) -> StringName:
	return StringName(_GROUP_PREFIX + String(group_id))


func ensure_runner(runner_id: StringName) -> void:
	if _runners.has(runner_id):
		return
	var st := _QueueState.new()
	st.runner_id = runner_id
	_runners[runner_id] = st


func list_runner_ids() -> PackedStringArray:
	var keys: Array = _runners.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	var out := PackedStringArray()
	for k in keys:
		out.append(k)
	return out


func enqueue(task: AutomationTask) -> void:
	enqueue_for(_default_runner_id, task)


func enqueue_for(runner_id: StringName, task: AutomationTask) -> void:
	ensure_runner(runner_id)
	var st: _QueueState = _runners[runner_id]
	st.queue.append(task)
	_sort_queue(st)
	task_enqueued.emit(runner_id, task)
	_emit_queue_changed(runner_id)


func enqueue_interruptible_high_priority(runner_id: StringName, task: AutomationTask) -> void:
	## Suspend interruptible active work if present, bump priority above active/queue ceiling, enqueue, then resume backbone after this task finishes.
	ensure_runner(runner_id)
	var st: _QueueState = _runners[runner_id]
	var ceiling: int = 0
	for qt in st.queue:
		var qtt: AutomationTask = qt as AutomationTask
		ceiling = maxi(ceiling, qtt.priority)
	if st.active != null:
		ceiling = maxi(ceiling, st.active.priority)
	task.priority = ceiling + 1
	var did_interrupt: bool = interrupt_active(runner_id)
	if did_interrupt:
		task.data["resume_backbone_after"] = true
	enqueue_for(runner_id, task)


func clear_queue(runner_id: StringName = &"") -> void:
	var rid := runner_id if runner_id != &"" else _default_runner_id
	if not _runners.has(rid):
		return
	var st: _QueueState = _runners[rid]
	st.queue.clear()
	st.active = null
	_emit_queue_changed(rid)


func clear_all_runners() -> void:
	_runners.clear()
	queue_changed.emit()


func get_active_task() -> Variant:
	return get_active_task_for(_default_runner_id)


func get_active_task_for(runner_id: StringName) -> Variant:
	if not _runners.has(runner_id):
		return null
	return (_runners[runner_id] as _QueueState).active


func get_queue_snapshot() -> Array:
	return get_queue_snapshot_for(_default_runner_id)


func get_queue_snapshot_for(runner_id: StringName) -> Array:
	if not _runners.has(runner_id):
		return []
	var st: _QueueState = _runners[runner_id]
	var out: Array = []
	for t in st.queue:
		out.append(t)
	return out


func get_suspended_snapshot_for(runner_id: StringName) -> Array:
	if not _runners.has(runner_id):
		return []
	var st: _QueueState = _runners[runner_id]
	var out: Array = []
	for t in st.suspended:
		out.append(t)
	return out


func get_previous_tasks_for(runner_id: StringName) -> Array:
	if not _runners.has(runner_id):
		return []
	var st: _QueueState = _runners[runner_id]
	return st.previous.duplicate()


func get_status_messages_for(runner_id: StringName) -> PackedStringArray:
	if not _runners.has(runner_id):
		return PackedStringArray()
	var st: _QueueState = _runners[runner_id]
	var out := PackedStringArray()
	for line in st.status_messages:
		out.append(String(line))
	return out


func reorder_queue_relative(runner_id: StringName, from_index: int, to_index: int) -> void:
	if not _runners.has(runner_id):
		return
	var st: _QueueState = _runners[runner_id]
	if from_index < 0 or from_index >= st.queue.size():
		return
	to_index = clampi(to_index, 0, st.queue.size() - 1)
	var item: Variant = st.queue[from_index]
	st.queue.remove_at(from_index)
	st.queue.insert(to_index, item)
	_emit_queue_changed(runner_id)


func set_queue_task_continuous(runner_id: StringName, task_id: int, continuous: bool) -> void:
	if not _runners.has(runner_id):
		return
	var st: _QueueState = _runners[runner_id]
	for t in st.queue:
		if t.task_id == task_id:
			t.continuous = continuous
			_emit_queue_changed(runner_id)
			return


func set_task_priority(runner_id: StringName, queue_index: int, new_priority: int) -> void:
	if not _runners.has(runner_id):
		return
	var st: _QueueState = _runners[runner_id]
	if queue_index < 0 or queue_index >= st.queue.size():
		return
	(st.queue[queue_index] as AutomationTask).priority = new_priority
	_sort_queue(st)
	_emit_queue_changed(runner_id)


func set_task_priority_by_task_id(runner_id: StringName, task_id: int, new_priority: int) -> void:
	if not _runners.has(runner_id):
		return
	var st: _QueueState = _runners[runner_id]
	for t in st.queue:
		var at: AutomationTask = t as AutomationTask
		if at.task_id == task_id:
			at.priority = new_priority
			_sort_queue(st)
			_emit_queue_changed(runner_id)
			return


func set_task_interruptible_by_task_id(
	runner_id: StringName, task_id: int, interruptible: bool
) -> void:
	if not _runners.has(runner_id):
		return
	var st: _QueueState = _runners[runner_id]
	for t in st.queue:
		var at: AutomationTask = t as AutomationTask
		if at.task_id == task_id:
			at.interruptible = interruptible
			_emit_queue_changed(runner_id)
			return


func interrupt_active(runner_id: StringName) -> bool:
	if not _runners.has(runner_id):
		return false
	var st: _QueueState = _runners[runner_id]
	if st.active == null:
		return false
	var t: AutomationTask = st.active
	if not t.interruptible:
		_log(st, "Interrupt blocked (not interruptible): %s" % t.label)
		return false
	st.suspended.append(t)
	st.active = null
	task_interrupted.emit(runner_id, t)
	_log(st, "Interrupted: %s" % t.label)
	_emit_queue_changed(runner_id)
	return true


func resume_suspended(runner_id: StringName) -> bool:
	if not _runners.has(runner_id):
		return false
	var st: _QueueState = _runners[runner_id]
	if st.suspended.is_empty():
		return false
	if st.active != null:
		## Park current work back on the queue; resort by priority.
		st.queue.append(st.active)
		st.active = null
		_sort_queue(st)
	var t: AutomationTask = st.suspended.pop_back()
	st.active = t
	task_resumed.emit(runner_id, t)
	task_started.emit(runner_id, t)
	_log(st, "Resumed: %s" % t.label)
	_emit_queue_changed(runner_id)
	return true


func tick(delta: float) -> void:
	tick_all(delta)


func tick_all(delta: float) -> void:
	for k in _runners.keys():
		_tick_runner(k, delta)


func _emit_queue_changed(runner_id: StringName) -> void:
	runner_queue_changed.emit(runner_id)
	queue_changed.emit()


func _sort_queue(st: _QueueState) -> void:
	st.queue.sort_custom(
		func(a: AutomationTask, b: AutomationTask) -> bool:
			if a.priority != b.priority:
				return a.priority > b.priority
			return a.task_id < b.task_id
	)


func _log(st: _QueueState, message: String) -> void:
	st.status_messages.append("[%d] %s" % [Time.get_ticks_msec(), message])
	while st.status_messages.size() > STATUS_LOG_CAP:
		st.status_messages.remove_at(0)
	status_logged.emit(st.runner_id, message)


func _push_previous(st: _QueueState, task: AutomationTask, success: bool) -> void:
	var summary := {
		"task_id": task.task_id,
		"type": task.type,
		"label": task.label,
		"success": success,
	}
	st.previous.append(summary)
	while st.previous.size() > PREVIOUS_TASK_CAP:
		st.previous.remove_at(0)


func _tick_runner(runner_id: StringName, delta: float) -> void:
	var st: _QueueState = _runners[runner_id]
	if st.active == null and not st.queue.is_empty() and not is_dispatch_held(runner_id):
		_sort_queue(st)
		st.active = st.queue.pop_front() as AutomationTask
		task_started.emit(runner_id, st.active)
		_log(st, "Started: %s (p=%d)" % [st.active.label, st.active.priority])
		_emit_queue_changed(runner_id)
	if _try_queue_preempt_active(runner_id, st):
		return
	if st.active == null:
		return
	var done := _advance_task(st, st.active, delta)
	if done:
		_finish_active(runner_id, st, true)


func _try_queue_preempt_active(runner_id: StringName, st: _QueueState) -> bool:
	if not queue_preempts_lower_priority_active:
		return false
	if is_dispatch_held(runner_id):
		return false
	if st.active == null or st.queue.is_empty():
		return false
	_sort_queue(st)
	var head: AutomationTask = st.queue[0] as AutomationTask
	var cur: AutomationTask = st.active
	if head.priority <= cur.priority:
		return false
	if not cur.interruptible:
		_log(st, "Preempt blocked (active not interruptible): %s" % cur.label)
		return false
	st.suspended.append(cur)
	task_interrupted.emit(runner_id, cur)
	_log(st, "Preempted (queue higher priority): %s" % cur.label)
	st.active = st.queue.pop_front() as AutomationTask
	task_started.emit(runner_id, st.active)
	_log(st, "Started: %s (p=%d)" % [st.active.label, st.active.priority])
	_emit_queue_changed(runner_id)
	return true


func _finish_active(runner_id: StringName, st: _QueueState, success: bool) -> void:
	if st.active == null:
		return
	var finished: AutomationTask = st.active
	st.active = null
	_push_previous(st, finished, success)
	task_finished.emit(runner_id, finished, success)
	_log(st, "Finished: %s (%s)" % [finished.label, "ok" if success else "fail"])
	if success and finished.continuous:
		var again: AutomationTask = _duplicate_task_for_repeat(finished)
		st.queue.append(again)
		_sort_queue(st)
		_log(st, "Continuous: re-queued %s" % again.label)
	var resume_backbone: bool = bool(finished.data.get("resume_backbone_after", false))
	if resume_backbone and success and not st.suspended.is_empty():
		finished.data.erase("resume_backbone_after")
		if resume_suspended(runner_id):
			_log(st, "Resumed backbone after reactive task: %s" % finished.label)
	if (
		success
		and st.active == null
		and st.queue.is_empty()
		and not st.suspended.is_empty()
		and not is_dispatch_held(runner_id)
	):
		resume_suspended(runner_id)
	_emit_queue_changed(runner_id)


func _duplicate_task_for_repeat(source: AutomationTask) -> AutomationTask:
	var t := AutomationTask.new()
	t.type = source.type
	t.priority = source.priority
	t.interruptible = source.interruptible
	t.continuous = source.continuous
	t.label = source.label
	t.data = source.data.duplicate(true)
	_scrub_task_runtime_state(t)
	return t


func _scrub_task_runtime_state(t: AutomationTask) -> void:
	var wipe: Array = [
		"_sim_step",
		"kills_achieved",
		"hunt_last_strike_ms",
		"hunt_lock_instance_id",
		"assist_last_strike_ms",
		"assist_lock_instance_id",
		"follow_caught_up",
		"resume_backbone_after",
		"external_done",
	]
	for k in wipe:
		t.data.erase(k)
	var del_announce: Array = []
	for k in t.data.keys():
		if String(k).begins_with("announce_"):
			del_announce.append(k)
	for k in del_announce:
		t.data.erase(k)


func _default_sim_ticks(task: AutomationTask) -> int:
	match task.type:
		TaskType.IDLE:
			return 1
		TaskType.WAIT:
			return int(task.data.get("sim_ticks", 2))
		TaskType.MOVE_TO, TaskType.NAVIGATE_MAP, TaskType.USE_PORTAL:
			return int(task.data.get("sim_ticks", 3))
		TaskType.INTERACT:
			return int(task.data.get("sim_ticks", 2))
		TaskType.HUNT:
			return int(task.data.get("sim_ticks", 4))
		TaskType.SEARCH_LOOT:
			return int(task.data.get("sim_ticks", 3))
		TaskType.COMPLETE_QUEST:
			return int(task.data.get("sim_ticks", 5))
		TaskType.SELL_EXCESS_LOOT:
			return int(task.data.get("sim_ticks", 3))
		TaskType.SHARE_LOOT_GROUP:
			return int(task.data.get("sim_ticks", 4))
		TaskType.SUPPORT_ALLY:
			return int(task.data.get("sim_ticks", 3))
		TaskType.FOLLOW_CHARACTER:
			return 999999
		TaskType.ASSIST_COMBAT:
			return 999999
		_:
			return int(task.data.get("sim_ticks", 2))


func _advance_task(st: _QueueState, task: AutomationTask, _delta: float) -> bool:
	match task.type:
		TaskType.IDLE:
			return true
		TaskType.FOLLOW_CHARACTER:
			if task.data.get("announce_follow", true):
				task.data["announce_follow"] = false
				var tid: String = str(task.data.get("target_character_id", "?"))
				_log(st, "Following character %s" % tid)
			## World layer moves the body; task stays active until interrupt or queue advances.
			return false
		TaskType.ASSIST_COMBAT:
			if task.data.get("announce_assist", true):
				task.data["announce_assist"] = false
				var aid: String = str(task.data.get("ally_character_id", "?"))
				_log(st, "Assist combat for ally %s" % aid)
			assist_world_pulse.emit(st.runner_id, task)
			return false
		TaskType.SEARCH_LOOT:
			## Optional filter keys: item_id, min_rarity, tags — logged for Panel E.
			if task.data.get("announce_filter", true):
				task.data["announce_filter"] = false
				var f: String = str(task.data.get("loot_filter", {}))
				_log(st, "Loot filter: %s" % f)
		TaskType.SHARE_LOOT_GROUP:
			if task.data.get("announce_roster", true):
				task.data["announce_roster"] = false
				var n := _resolve_group_roster_size(task)
				_log(st, "Share loot: roster size %d" % n)
		TaskType.SUPPORT_ALLY:
			var ally: String = str(task.data.get("ally_id", "?"))
			if task.data.get("announce_ally", true):
				task.data["announce_ally"] = false
				_log(st, "Supporting ally %s" % ally)
		TaskType.COMPLETE_QUEST:
			var qid: String = str(task.data.get("quest_id", ""))
			if qid != "" and task.data.get("announce_quest", true):
				task.data["announce_quest"] = false
				_log(st, "Quest: %s" % qid)
		TaskType.NAVIGATE_MAP, TaskType.USE_PORTAL:
			var map_name: String = str(task.data.get("map_id", task.data.get("target_map", "")))
			var portal: String = str(task.data.get("portal_id", ""))
			if task.data.get("announce_nav", true):
				task.data["announce_nav"] = false
				_log(st, "Navigate map=%s portal=%s" % [map_name, portal])
		TaskType.HUNT:
			if task.data.get("announce_hunt", true):
				task.data["announce_hunt"] = false
				_log(st, "Hunting (filter=%s)" % str(task.data.get("enemy_filter", {})))
			if task.data.get("sim_only", false):
				var need_s: int = int(task.data.get("sim_ticks", 4))
				var cur_s: int = int(task.data.get("_sim_step", 0))
				cur_s += 1
				task.data["_sim_step"] = cur_s
				return cur_s >= need_s
			hunt_world_pulse.emit(st.runner_id, task)
			var tgt_k: int = maxi(1, int(task.data.get("hunt_kills_target", 1)))
			return int(task.data.get("kills_achieved", 0)) >= tgt_k
		TaskType.SELL_EXCESS_LOOT:
			if task.data.get("announce_sell", true):
				task.data["announce_sell"] = false
				_log(
					st,
					"Selling excess (merchant=%s)" % str(task.data.get("merchant_id", "default"))
				)
		_:
			pass

	## Shell sets `external_done` when quest completes, loot matches, merchants trade, etc.
	if bool(task.data.get("use_external_completion", false)):
		match task.type:
			TaskType.COMPLETE_QUEST, TaskType.SEARCH_LOOT, TaskType.SELL_EXCESS_LOOT, TaskType.INTERACT:
				return bool(task.data.get("external_done", false))
			_:
				pass

	var need: int = _default_sim_ticks(task)
	var cur: int = int(task.data.get("_sim_step", 0))
	cur += 1
	task.data["_sim_step"] = cur
	return cur >= need


func _resolve_group_roster_size(task: AutomationTask) -> int:
	var gid: StringName = task.data.get("group_id", &"default")
	if _group_system != null and _group_system.has_method("get_roster"):
		return (_group_system.call("get_roster", gid) as PackedStringArray).size()
	return int(task.data.get("fallback_roster_size", 0))


## --- Simulation helpers for tests ---


func simulation_reset_runner(runner_id: StringName) -> void:
	if not _runners.has(runner_id):
		return
	var st: _QueueState = _runners[runner_id]
	st.queue.clear()
	st.active = null
	st.suspended.clear()
	st.previous.clear()
	st.status_messages.clear()
	_emit_queue_changed(runner_id)
