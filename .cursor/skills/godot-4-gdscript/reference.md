# Godot 4 / GDScript — reference

Optional detail for agents; read when implementing formulas, quests, or automation.

## Formula patterns

**Damage (illustrative)**

- Order: base → additive → multiplicative → clamp.
- Keep crit and armor as separate steps so designers can disable one branch.

**Loot**

- Weighted random: table Resource with `{item_id, weight}`; roll once per drop source; use RNG instance for reproducible tests (seed in tests).

**XP / level curves**

- Prefer `Curve` on a Resource or a small set of exported keyframes; avoid hardcoding `level * 100` in multiple files.

## Quest state machine sketch

States might include: `inactive`, `available`, `active`, `completed`, `failed`, `turned_in`.

- Transitions driven by explicit methods: `accept_quest()`, `advance_objective()`, `fail_quest()`, `turn_in()`.
- Objectives: array of structs `{description_key, counter_type, target_count, current_count}` with a single `check_completion()` path.

## NavigationAgent2D + CharacterBody2D (conceptual)

- Set `NavigationAgent2D` target; in `_physics_process`, get `get_next_path_position()`, compute desired velocity, move with `move_and_slide`.
- Use agent’s `velocity_computed` signal if using avoidance (Godot 4 pattern depends on project settings—match official docs and existing project code).

## Inventory edge cases

- Partial stack pickup when container nearly full.
- Swap equipment when slot occupied.
- Drop on ground: spawn world pickup only if the game design includes it; otherwise discard with feedback.

## Test harness ideas (no engine required in skill)

- Pure static functions: test with `assert` in a `@tool` script or Gut.
- Scene tests: instance `res://tests/test_combat.tscn`, run one frame, assert state.
