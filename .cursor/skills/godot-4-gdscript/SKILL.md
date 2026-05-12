---
name: godot-4-gdscript
description: >-
  Guides Godot 4 and GDScript architecture, UI layout, gameplay systems,
  data-driven balance, pathfinding and automation, quest state machines,
  inventory and equipment, and autonomous debugging with headless tests. Use
  when building or refactoring a Godot 4 project, writing GDScript, designing
  maps under res://maps/, tuning formulas, navigation or bot logic, quests,
  inventory, or when the user mentions Godot, GDScript, CharacterBody2D, or
  game prototype structure.
---

# Godot 4 / GDScript Game Prototype

## Defaults (align with project rules)

- **Engine**: Godot 4 APIs only; **GDScript** for gameplay.
- **Controllable actors**: `CharacterBody2D` (not `RigidBody2D` for player control).
- **Maps**: one scene per map under `res://maps/`.
- **Scripts**: separate files for UI, character data, automation, combat, quests, loot, transitions—avoid monolithic “god” scripts.
- **Tuning**: prefer `Resource` subclasses and/or exported variables on nodes; keep formulas readable and testable.
- **Visuals**: placeholder art is fine; prioritize systems and feel.

When unsure, read adjacent scenes and scripts in the repo and match naming, signals, and folder layout.

---

## Architecture

**Scene composition**

- Root gameplay scenes: clear ownership (who updates whom via signals or direct child refs).
- **Autoloads**: use sparingly for true singletons (audio bus, save service); avoid stuffing game state that belongs on a run/manager node.
- **Groups**: for cross-cutting queries (`add_to_group`, `get_tree().get_nodes_in_group`); document group names in one place (constants or README in repo if project has it).

**Data flow**

- **Resources** (`*.tres` / `.res`): stats, item defs, quest defs, curve-based tuning.
- **Runtime state**: dictionaries or small state objects on managers; persist via explicit save format (not raw node duplication unless prototype-only).

**File layout (typical)**

- `res://maps/` — map scenes
- `res://characters/` or `res://actors/` — player and NPC scenes
- `res://ui/` — HUD, menus
- `res://systems/` or `res://automation/` — managers, bots
- `res://data/` — resources and tables

Adjust to whatever the repo already uses.

---

## UI layout

- Prefer **Control** nodes: root with anchors preset (e.g. full rect for overlay HUD); use **containers** (`MarginContainer`, `VBoxContainer`, `HBoxContainer`, `GridContainer`) instead of manual pixel positioning when possible.
- **Theme** / theme overrides for fonts, margins, and colors—avoid hardcoding sizes in every label unless the screen is one-off.
- **Input**: `gui_input`, focus neighbors for menus, `mouse_filter` where clicks must pass through layers.
- **Scaling**: test at different window sizes; use anchors + min sizes, not fixed global coordinates for full-screen UI.

For responsive layouts: outer `MarginContainer` → inner `VBoxContainer` → rows of `HBoxContainer` or `ItemList`/`Tree` as needed.

---

## Gameplay systems

- **Signals** for decoupling (e.g. `health_changed`, `inventory_changed`, `quest_updated`).
- **Physics**: `_physics_process` for movement and collisions; `_process` for non-physics animation/UI follow if needed.
- **State**: local to the actor when possible; shared rules in Resources or static functions.
- **Layers**: document `collision_layer` / `collision_mask` in a short comment or central enum so pathfinding and combat agree.

Design vertical slices: one mechanic (e.g. dash + i-frames) playable in isolation before wiring into the full game.

---

## Balancing formulas

- Put **inputs** (base stats, level, difficulty) in Resources or exported vars; keep **pure functions** for damage/heal/loot tables where practical so they can be unit-tested headless.
- Prefer **named constants** or Resource fields over scattered literals.
- Use **Curve** / **CurveTexture** in Resources when designers need to tweak falloff without code changes.
- Document units (per second vs per frame, percentage vs flat).

See [reference.md](reference.md) for example formula shapes.

---

## Pathfinding and automation

- **Tilemaps**: `NavigationRegion2D` baked from geometry or `NavigationObstacle2D` / layers as appropriate to Godot 4 setup in the project.
- **Agents**: `NavigationAgent2D` on the body; set target in world space; call `velocity_computed` pattern with `CharacterBody2D` movement—avoid fighting the physics loop.
- **Automation**: separate script/class for “intent” (go to, interact, wait) and “execution” (apply velocity from agent). Stuck detection: timer + last position delta; backoff and retarget.
- **Performance**: throttle target updates; avoid every-frame full map queries.

---

## Quest state machines

- Model quests as **explicit states** (`enum` or string constants) with **allowed transitions** only—avoid implicit “if flag X” spaghetti across many files.
- **Quest data**: Resource id, objectives list, rewards; **runtime**: current objective index, state enum, timestamps if needed.
- **Persistence**: save stable quest ids and state; migrate carefully when changing enums.
- **UI**: subscribe to quest signals; do not poll every frame.

Patterns and a minimal state outline are in [reference.md](reference.md).

---

## Inventory and equipment

- **Item definition**: `Resource` (name, stack rules, tags, icon optional).
- **Inventory**: array or dictionary of `{item_id, count}` or structured slots; single writer API (`add`, `remove`, `can_add`) that emits `inventory_changed`.
- **Equipment**: slots map (`weapon`, `armor`, …) referencing item ids; recompute **derived stats** in one place when equipment changes.
- **Effects**: apply modifiers from equipped items in a pipeline (base stat → flat adds → multipliers) for predictable balance.

---

## Autonomous debugging and test harness

- **Run headless**: `godot --headless --path .` (adjust path); use for CI or quick script checks.
- **Assertions**: `assert()` in debug paths; for shipped builds, pair with explicit error handling where failure must be graceful.
- **Test scenes**: minimal scenes that instantiate one system and stub dependencies (mock `Player` or `EventBus`).
- **GUT or custom**: if the project uses [GUT](https://github.com/bitwes/Gut), follow existing test layout; otherwise add small `test_*.gd` run via a dedicated test scene or `--script` runner.
- **Workflow**: reproduce → minimal scene → fix → add automated check so the regression does not return.

**Debug checklist**

- [ ] Errors in Output dock and debugger stack
- [ ] Remote scene tree while running (node visibility, paused groups)
- [ ] Collision debug (`Visible Collision Shapes`) when movement feels wrong
- [ ] Navigation debug visuals when agents fail to reach targets

---

## When editing code

1. Match existing patterns in the repository first.
2. Prefer **Resources + signals** over hidden globals.
3. After substantive changes, run the project or headless test the user relies on; fix parse errors and obvious runtime errors before finishing.
4. Keep diffs focused: no unrelated refactors.

## Additional resources

- Deeper patterns and snippets: [reference.md](reference.md)
