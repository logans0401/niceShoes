---
name: godot-qa-headless
description: >-
  Runs and maintains Godot 4 automated tests: headless Godot invocations,
  regression checks, minimal test scenes, and fixing parse/runtime errors
  exposed by tests. Use when adding tests, debugging CI, or stabilizing
  refactors—not for feature UI polish unless tests fail.
---

# QA / headless test agent (Godot 4)

## Scope

- **Headless runs**: `godot --headless --path <project>` (adjust for install); use for CI and quick checks.
- **Test layout**: follow repo convention (GUT, `test/` scenes, or `--script` runners); keep tests **fast** and **isolated**.
- **Regression**: add a test when fixing a bug; assert the failure mode explicitly.
- **Debugging**: read Godot stderr; fix **parse errors first**, then runtime; re-run until green.

## Patterns

- **Pure functions** (gameplay math) callable from tests without full scene tree.
- **Minimal scenes** that stub dependencies (mock player, fake bus).
- **Assertions**: `assert()` in debug paths; for shipped code use explicit handling where required.

## Out of scope

- Designing HUD layout → **`godot-ui-agent`** (unless fixing a test-only UI harness).
- New combat features without tests → implement in **`godot-gameplay-systems`**, then add tests here.

## Checklist before finishing

- [ ] Tests run headless or documented one-command local run
- [ ] Failure output points to a specific file/line or assertion
- [ ] No flaky timing: prefer signals or `await` with caps over naked `Timer` races
