---
name: godot-ui-agent
description: >-
  Builds Godot 4 Control-based UI: multi-panel layouts (e.g. panels A–E),
  tabs, HUD bars, character cards, themes, and input/focus. Use when changing
  menus, overlays, or presentation—not core combat/inventory math or
  navigation AI.
---

# UI agent (Godot 4)

## Scope

- **Layout**: root `Control` with anchors; **containers** (`MarginContainer`, `VBoxContainer`, `HBoxContainer`, `GridContainer`, `TabContainer`) over manual pixel placement.
- **Panels A–E**: treat as named regions (e.g. left strip, center, right stack); use nested containers and minimum sizes so resizing behaves.
- **Tabs**: `TabContainer` or custom tab buttons + `Visibility`/child swapping—one source of truth for which panel is active.
- **HUD bars**: `ProgressBar`, `TextureProgressBar`, or custom `Control` + `_draw`; bind to gameplay signals; avoid polling every frame if signals exist.
- **Character cards**: compact stat blocks; icons optional; data from a single ViewModel-style node or direct refs to gameplay facades—no duplicate stat formulas in UI.

## Patterns

- **Theme** / theme overrides for fonts, colors, margins.
- **Input**: `mouse_filter`, focus neighbors for menus, `gui_input` where needed.
- **Scaling**: anchors + min sizes; test multiple window sizes.

## Out of scope

- Damage formulas, loot tables, XP curves → **`godot-gameplay-systems`**.
- Bot/path/portal logic → **`godot-automation-agent`**.
- Headless test harness → **`godot-qa-headless`**.

## Checklist before finishing

- [ ] No duplicated gameplay calculations (display only)
- [ ] Readable at different resolutions
- [ ] Connected to signals or documented update entry points
