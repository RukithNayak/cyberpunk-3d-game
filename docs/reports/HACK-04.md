# HACK-04 Verification Report

Date: 23 October 2026 (Asia/Kolkata)

Task: Distraction and implant disruption (Stage 1)

## Scope

Added runtime distraction and implant targets, connected NPC perceptions to a decoupled distraction broadcast group, and added a TacticalAgent eligibility query for implant disruption. Hacking target effects remain transient; persistence and presentation are HACK-05. The HACK-04 support scope was recorded in `docs/tasks/hacking-subsystem.md` before implementation.

## Regression-first evidence

Before production target scripts were added:

```text
godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_combat
exit 1
Expected red: missing HackableDistraction and HackableImplant scripts (2 failures).
```

## Verification

| Command | Exit | Result |
|---|---:|---|
| `godot --headless --path game --editor --import` | 0 | Import/class scan completed. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_combat` | 0 | 19 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite ai_states` | 0 | 32 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite ai_perception` | 0 | 20 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_energy` | 0 | 30 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_door` | 0 | 25 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_security` | 0 | 23 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | 790 cases, 0 failures. Shutdown reported one ObjectDB leak and one `GodotBody3D` RID leak. |

The focused combat regression constructs a guard actively attacking a live damage target before the hack, then verifies that the implant hack applies the configured 8 damage and 3-second stun, stops attack damage, rejects repeat damage while stunned, and rejects a dead target. The distraction regression verifies radius filtering and investigation of the emitter position through cover. Its open-lane combat perception fixture disables environment ray hits so it tests attack interruption rather than collision-query setup.

## Evidence limits

These are headless behavioral checks. No rendered combat scenario or human playtest is claimed; HACK-06 owns authored encounter fixtures and visual scenario review. The integrated shutdown resource warnings remain unexplained and are not claimed as fixed.
