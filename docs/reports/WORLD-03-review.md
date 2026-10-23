## Task
- WORLD-03 — bounded read-only review of persistent entity lifecycle.
- Reviewer: `world03_review`; dispatch requested gpt-6-luna / medium with a fresh context.
- Base: `f71404e`; working-tree implementation. Reviewer changed no files and ran no tests/GUI.

## Findings and resolution
- Important: retirement invoked `set_interaction_enabled(false)` before erasing old ownership. A callback could install newer bindings, then old cleanup erased those new bindings/chunk records. `_revoke_staged` had a related preparation-map hazard.
- Main Agent extended this review with activation cancellation, tombstone callback writes and retained-root re-entry: old disable loops could turn off nodes already rebound under a newer generation.
- Worker added observed failing regressions before fixes. Captured combined old-ordering replay: 51 checks, five failures, exit 1; retained-root variant: 51 checks, one failure, exit 1. Final worker check: 51/51, exit 0. See [combined red](../evidence/WORLD-03/hydrator-all-reentrancy-red.log), [retained red](../evidence/WORLD-03/hydrator-retained-red.log), [green](../evidence/WORLD-03/hydrator-reentrancy-green.log).
- Fix: revoke captured old ownership before callbacks; compare generation/root identity when removing maps; skip disabling nodes already rebound; publish activation bindings before enable callbacks so cancellation can retire them; revoke tombstone authority before callbacks can issue a second write.
- Main Agent inspected the resulting code and shared manifest/loader/registry diff, reproduced final focused/full/runtime checks, and inspected rendered captures. No remaining blocking finding or deferred minor was identified. This is regression verification of the review fixes, not a claim that the read-only reviewer independently reran tests or inspected visuals.

## Scope / risks
- Domain gameplay permissions, rewards, production NPC/door behavior, navigation and large-scene performance are later tasks. Projection callbacks are authored code required to consume copied state; they do not become a second persistence authority.
- Runtime fixture uses actual loaders, SnapshotAdapters and SaveStore with generic projections. It does not accept CORE-05 checkpoint integration or WORLD-06 performance/playtest gates.

## Follow-up
- WORLD-04 becomes eligible after Main Agent WORLD-03 acceptance. No further worker edits pending.
