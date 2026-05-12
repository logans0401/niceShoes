---
name: godot-subagent-team
description: >-
  Routes Godot 4 GDScript work to the right specialized skill: gameplay
  (character, combat, inventory, loot, XP), UI (panels A–E, tabs, HUD, cards),
  automation (queues, pathing, portals), or QA (headless tests, regression).
  Use when the user names a subagent, asks which agent handles a topic, or
  when a task clearly fits one domain and should not mix concerns.
---

# Godot subagent team (router)

Cursor does not register custom Task-tool subagent types; these **skills** are the supported way to get “specialized agents.” Read the matching skill **before** deep work in that area.

## Pick one domain

| Domain | Skill name | Read when… |
|--------|------------|------------|
| Gameplay systems | `godot-gameplay-systems` | Character, stats, combat, inventory, loot tables, XP, progression, tuning Resources |
| UI | `godot-ui-agent` | Layout panels A–E, tabs, HUD bars, character cards, themes, input focus |
| Automation | `godot-automation-agent` | Task queues, priorities, grouping, NavigationAgent2D, portals, bot behavior |
| QA / tests | `godot-qa-headless` | Headless runs, GUT or test scenes, regression checks, fixing parse/runtime errors from tests |

## Rules

- Prefer **one primary domain** per change; hand off UI tweaks to UI skill after gameplay logic is correct, etc.
- Always align with **`godot-4-gdscript`** for project-wide defaults (Godot 4 only, `CharacterBody2D`, `res://maps/`, data-driven balance).

## User phrases

If the user says “Gameplay agent,” “UI agent,” “Automation agent,” or “QA agent,” treat that as: read the corresponding row’s skill immediately, then proceed.
