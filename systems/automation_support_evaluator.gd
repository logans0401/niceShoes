class_name AutomationSupportEvaluator
extends RefCounted


## Scans threshold profiles and injects short SUPPORT_ALLY tasks via enqueue_interruptible_high_priority.
static func tick(
	automation: AutomationSystem,
	registry: Node,
	stats: Node,
	equipment: Node,
	profiles: Array,
	cooldowns: Dictionary,
	resolve_runner_to_character: Callable,
) -> void:
	if automation == null or registry == null or stats == null or equipment == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	for profile in profiles:
		if not profile is AutomationSupportProfile:
			continue
		var p: AutomationSupportProfile = profile as AutomationSupportProfile
		if p.supporter_character_id == &"":
			continue
		for rid in automation.list_runner_ids():
			var sup_cid: StringName = resolve_runner_to_character.call(rid) as StringName
			if sup_cid != p.supporter_character_id:
				continue
			for ally_id in p.ally_character_ids:
				var a_cid: StringName = ally_id as StringName
				if a_cid == &"" or a_cid == sup_cid:
					continue
				var key: String = "%s|%s" % [String(sup_cid), String(a_cid)]
				var last_ms: int = int(cooldowns.get(key, 0))
				if float(now_ms - last_ms) < p.cooldown_seconds * 1000.0:
					continue
				var ally_data: Resource = registry.get_character(a_cid)
				if ally_data == null:
					continue
				var eff: Dictionary = stats.get_effective_stats(a_cid, ally_data, equipment)
				var hp_max: float = maxf(float(eff.get("max_health", 1.0)), 1.0)
				var hp: float = float(ally_data.current_health)
				var breach: bool = (hp / hp_max) <= p.hp_below_ratio
				if not breach and p.mana_below_ratio >= 0.0:
					var mn_max: float = maxf(float(eff.get("max_mana", 1.0)), 1.0)
					var mn: float = float(ally_data.current_mana)
					breach = (mn / mn_max) <= p.mana_below_ratio
				if not breach:
					continue
				var t := AutomationSystem.AutomationTask.new()
				t.type = AutomationSystem.TaskType.SUPPORT_ALLY
				t.interruptible = true
				t.label = p.support_label
				t.data["ally_id"] = String(a_cid)
				t.data["sim_ticks"] = p.support_task_sim_ticks
				automation.enqueue_interruptible_high_priority(rid, t)
				cooldowns[key] = now_ms
