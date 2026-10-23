# Project instructions

Read `docs/prompt.md`, `docs/master-progress.md`, the approved design at
`docs/detailed_design.md`, and the owning task before implementation.
Only Stage 0/1 is approved. Record added scope as a task before implementation.

## Ownership

- `game/persistence/`: authoritative records, save envelopes and adapters.
- `game/world/`: streaming, scene transitions and runtime entity lifecycle.
- `game/features/`: player/combat, inventory, AI, hacking, dialogue and missions.
- `game/ui/`: presentation consuming authoritative services.
- `game/tests/`: headless suites and in-engine fixtures.
- `tools/blender/`, `art/`: offline assets, editable sources and provenance.
- Main Agent owns tracker, task acceptance, shared contracts/configuration and integration.
  Each worker owns one task and explicitly assigned files; coordinate shared edits.

Persistent state must contain data only, never Nodes. Model output is untrusted;
gameplay code validates authority and preconditions before deterministic commits.
Preserve existing changes. Do not install dependencies, download models, publish,
or expand into Stage 2–5 implicitly.

## Verification

Approved runtime: Godot 4.7.2, typed GDScript; asset target Blender 5.2.
From the repository root:

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/run_tests.gd -- --suite sample
godot --headless --path game --script res://tests/run_tests.gd -- --suite all
```

`deliberate_failure` intentionally exits 1 and is excluded from `all`.
Unknown suites and malformed arguments must exit nonzero. Register new suites in
the runner with Main Agent coordination. Logic changes require observed failing
regressions before implementation. Record exact commands, exits and evidence.
Headless success does not establish visual quality, performance or playtest acceptance.
