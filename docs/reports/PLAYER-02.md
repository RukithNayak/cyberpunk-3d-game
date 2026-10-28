# PLAYER-02 — Bounded health and death events

## Task
- Status: complete, accepted by Main Agent after code review and integrated checks; Stage 1; CORE-02 accepted prerequisite.
- Owner: Main Agent / session model, branch codex/stage-0-readiness; uncommitted working tree.

## Files changed
- `game/features/player/health_state.gd`: data-only typed health service, HUD signal and explicit restore.
- `game/tests/player/test_health.gd`: 19 boundary/death/restore assertions.
- `game/tests/run_tests.gd`: focused `health` registration (Main Agent shared ownership).

## Tests run
From repository root, with approved Godot native-data access:
`godot --headless --path game --script res://tests/run_tests.gd -- --suite health`.
- Before behavior implementation (no-op service skeleton): exit 1, 19 cases, 11 expected behavioral failures.
- After implementation: exit 0, 19 cases, 0 failures; no engine errors.
- Integrated `--suite all`: exit 0, 60 cases, 0 failures (sample, registry, health).
- Not run: visual/HUD fixture, not part of this data-only task.

## Results
HP clamps safely even with int64 maximum amounts. Nonpositive damage/heal are ignored.
Healing never revives a dead actor. Repeated lethal hits emit only one death until
explicit valid living restore. Invalid restore candidates preserve both HP and maximum.
`health_changed(current, maximum)` emits on real changes; damage emits `on_death`.
Read via `current_hp`, `max_hp`, `is_dead()`; mutate only through service methods.

`restore(current: int, maximum: int) -> bool` accepts maximum > 0 and HP in
0..maximum and applies them together. Restore does not replay death callbacks,
including restoring a dead snapshot. Constructor invalid maxima fall back to
100, an engineering default, not approved gameplay balance. Positive int64 maxima
are supported using subtraction-before-addition to avoid overflow.

## Risks
Domain checkpoint integration and visual feedback remain PLAYER-04/05 and CORE-05.
No movement/combat gameplay is claimed by this data-only implementation.

## Follow-up tasks
Main Agent authored/reviewed this bounded task; no separate reviewer yet. PLAYER-01 remains
eligible; PLAYER-03 requires PLAYER-01 and PLAYER-02 acceptance.
