# NiceShoes

Godot 4 prototype: party-based RPG with automation, combat, inventory, and data-driven balance.

## Requirements

- [Godot 4.6.x](https://godotengine.org/) (Forward Plus)
- Python 3.x (dev tooling only)

## Quick start

1. Open the project folder in Godot (`project.godot`).
2. Run the main scene (`res://main.tscn`).

### Dev setup (format, lint, headless tests)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap_dev_env.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_quality.ps1
```

Optional: enable the local pre-commit hook:

```powershell
git config core.hooksPath .githooks
```

## License

Original source code in this repository is licensed under the [MIT License](LICENSE).

Third-party notices: [NOTICE](NOTICE).

## Rights

Copyright (c) 2026 [logans0401](https://github.com/logans0401). All rights reserved where not explicitly granted by LICENSE.
