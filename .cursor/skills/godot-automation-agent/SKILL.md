---
name: godot-automation-agent
description: >-
  Implements Godot 4 automation: task queues with priorities, grouping,
  NavigationAgent2D pathing, stuck recovery, and portal/warp hooks. Use when
  building NPC/civilian logic, schedulers, or world traversal—not UI panels or
  raw combat stat rules.
---

# Automation agent (Godot 4)

## Scope

- **Task queues**: intents (`move_to`, `interact`, `wait`, `use_portal`) in a queue or state machine; **priority** via separate queues or sort key—document ordering rules.
- **Grouping**: `add_to_group` with stable names in constants; batch updates where many agents share a manager.
- **Pathing**: `NavigationAgent2D` on `CharacterBody2D`; use Godot 4 velocity pipeline (`velocity_computed` / set velocity from agent); throttle target updates.
- **Stuck detection**: compare position delta over time; backoff, replan, or nudge; avoid tight spin loops.
- **Portals**: single entry point (signal or `Area2D`) that validates transition and hands off to map/transition system—no scattered `change_scene` calls.

## Patterns

- Split **intent** (what to do next) from **execution** (apply movement this frame).
- Centralize **group names** and **navigation layers** with gameplay/collision docs.
- Performance: avoid per-agent full-tree scans every frame.

## Out of scope

- Inventory, loot, XP math → **`godot-gameplay-systems`**.
- HUD, menus → **`godot-ui-agent`**.
- CI/headless test runs → **`godot-qa-headless`**.

## Checklist before finishing

- [ ] Navigation and collision layers match project conventions
- [ ] Portal/transition path is single-purpose and testable
- [ ] Queue priority behavior is explicit and deterministic enough for debugging
