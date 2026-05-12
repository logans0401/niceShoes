---
name: godot-gameplay-systems
description: >-
  Implements Godot 4 gameplay: character data, combat, inventory, loot, XP,
  and progression using GDScript, Resources, and signals. Use when changing
  stats, damage, drops, leveling, equipment, or combat/inventory flow—not UI
  layout or navigation bots.
---

# Gameplay systems (Godot 4)

## Scope

- **Character**: `CharacterBody2D` movement and combat-relevant state; keep derived stats in one recomputation path.
- **Combat**: hitboxes/hurtboxes or ray/shape checks, i-frames, teams/layers—document collision layers in one place (constants/enum).
- **Inventory & loot**: item `Resource` defs; single API for add/remove/stack rules; emit `inventory_changed` (or project equivalent).
- **XP & progression**: pure functions for XP-to-level, stat growth—inputs from Resources or exported vars; easy to call from tests.

## Patterns

- **Signals** for `health_changed`, `level_up`, `inventory_changed`, `loot_dropped`.
- **Physics**: combat resolution in `_physics_process` where it interacts with bodies; avoid duplicating rules in UI.
- **Data**: tunable numbers in Resources or exported variables; avoid magic numbers scattered in scripts.

## Out of scope

- HUD/menus/layout → use **`godot-ui-agent`**.
- Pathfinding, task queues, portals → use **`godot-automation-agent`**.
- Running/fixing automated tests → use **`godot-qa-headless`**.

## Checklist before finishing

- [ ] No new gameplay rules hidden in UI scripts
- [ ] Balance knobs exposed (Resource or exports)
- [ ] Signals or clear APIs for UI and save/load to subscribe to
