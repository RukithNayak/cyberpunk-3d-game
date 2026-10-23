# HACK-01 — Ability, eligibility and energy rules

**Status:** Accepted for Stage 1.  
**Owner:** Main Agent.  
**Dependency:** CORE-02 accepted.  
**Scope:** Five configurable ability definitions, data-only energy/cooldown state, ActiveHack record, and a validated target-service entry point. Ability numbers are tuning defaults, not approved balance.

## Changes

- Added `HackDefinition` for camera disable, door unlock, distraction, implant disruption and turret disable. Costs, cooldowns, durations, range and impact damage are editable values.
- Added `HackingState` for bounded energy regeneration and per-target/per-ability cooldown data. It contains no Node references.
- Added `HackingService.request_hack()`. It requires a live operator and target, a matching target group and canonical persistent UUID, range, line of sight, no cooldown, sufficient energy, and target approval before charging. Target adapters use `can_accept_hack()` and an all-or-nothing `apply_hack()` contract. A declined commit refunds the energy and does not start a cooldown.
- Added `ActiveHack` data fields for stable target UUID, ability ID and remaining duration.
- Registered the focused `hacking_energy` suite and included it in `all`.

## Verification

Commands ran from the repository root:

| Command/action | Exit | Result |
|---|---:|---|
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_energy` before implementation | 1 | Expected red: hacking source files were missing; suite reported one failure. |
| Same focused command with negative-start-energy regression and the implementation temporarily reverted | 1 | `28 cases, 1 failure`; negative starting energy was incorrectly treated as the “start full” default. |
| `godot --headless --path game --editor --import` | 0 | New scripts/classes imported. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_energy` | 0 | `30 cases, 0 failures`. Covers definitions, energy boundaries/regeneration, eligibility, cost rollback, cooldowns and data-only ActiveHack. |
| `git diff --check` | 0 | No whitespace errors. |
| Godot MCP `get_godot_version` | Returned `4.7.2.stable.official.ed1daf0bf` | Matches approved runtime. |

## Deferred checks

The suite injects line-of-sight results to verify both accepted and blocked cases. It does not exercise the runtime physics-ray branch in a rendered fixture. Concrete door/camera/AI/turret target adapters and gameplay effects belong to HACK-02/03/04. No visual or full-game integration acceptance is claimed. The full `all` suite was not rerun; its last recorded 523/523 result predates this task.

**Next:** HACK-02, door unlock, is dependency-eligible with HACK-01 and WORLD-03 accepted.
