# Cyberpunk 3D Game

A single-player cyberpunk first-person shooter built with Godot 4.7.2 and typed GDScript. The project is developing toward a large, continuous city with distinct districts, detailed interiors, combat, hacking, inventory, tactical AI, and mission-focused NPCs.

## Project status

Stage 0/1 implementation is in progress. See [the progress tracker](docs/master-progress.md) for current task status, verification evidence, and known issues. Scope and architecture are documented in [the approved design](docs/detailed_design.md).

## Run

Open `game/project.godot` in Godot 4.7.2, or run from the repository root:

```sh
godot --path game
```

## Verification

Run the sample suite:

```sh
godot --headless --path game --script res://tests/run_tests.gd -- --suite sample
```

Run all registered suites:

```sh
godot --headless --path game --script res://tests/run_tests.gd -- --suite all
```

See [AGENTS.md](AGENTS.md) for project workflow, runtime, and scope constraints.

## Project layout

- `game/` contains the Godot project, gameplay code, scenes, and tests.
- `art/` contains editable Blender sources and asset provenance.
- `docs/` contains the design, task tracker, and implementation evidence.
