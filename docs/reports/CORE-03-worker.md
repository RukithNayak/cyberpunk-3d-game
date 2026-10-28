## Task
- ID and title: CORE-03 — Implement atomic save and validated load
- Status: ready for Main Agent review
- Worker/model/reasoning: delegated worker; model/reasoning override was not exposed in this task context
- Branch/commit or working-tree change reference: shared working tree; no commit

## Files changed
- `game/persistence/save_store.gd` — versioned tagged envelope, atomic temp-file replacement, candidate validation and callback-based live commit.
- `game/tests/persistence/test_save_store.gd` — 23 focused cases using an in-memory authoritative fixture, bounded failure-injection adapter and native isolated filesystem round trip.
- `docs/state-contracts.md` — appended SaveStore envelope and callback invariants.
- `docs/reports/CORE-03-worker.md` — this evidence report.

## Tests run
- Working directory: repository root. Exact command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite save_store`. Before implementation, the registered suite ran 1 case with 1 expected failure because `res://persistence/save_store.gd` did not exist (exit 1).
- During implementation, the same command exposed a float-precision regression: 21 cases, 9 failures (exit 1). The codec was changed to store float64 values as explicit little-endian bytes; later depth-boundary checks also exposed and fixed recursive limit propagation.
- Final exact command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite save_store`; exit 0, 23 cases, 0 failures. It covered nested/null values, int64 precision and boundaries, small and high-precision floats, maximum entity-state depth, invalid/missing/truncated/future-version files, valid duplicate-UUID rejection, invalid faction values, failed write, failed atomic replacement, consumer rejection, live/disk preservation, and native filesystem create/replace/load.
- An initial non-escalated run failed only when Godot attempted to create its isolated `user://` test directory. The final run used the project-approved Godot filesystem access and passed; the native test removed only the save/temp files it created.
- Not run: full `all` suite and editor import; Main Agent integration owns those checks.

## Results
- Save/load interfaces: exact public methods `save_to_disk(slot: int) -> Error` and `load_from_disk(slot: int) -> Error` are implemented.
- Envelope: v1 JSON wrapper plus tagged tree keeps values typed; signed int64 values use decimal strings and floats use little-endian binary64 hex. A valid int64 above 2^53 and both signed boundaries round-trip exactly.
- Disk behavior: a complete sibling temp file is atomically renamed over the final slot. Injected write/replacement failures preserve prior bytes; native replacement over an existing file passed.
- Load behavior: complete decode and structural validation, canonical/unique entity UUID checks, faction range validation and pure consumer validation all finish before one apply callback. Rejected candidates leave the in-memory fixture unchanged.
- Depth compatibility: an entity state at the registry’s maximum supported nesting depth saves and loads successfully; snapshot envelope overhead is accounted for separately.
- Integration contract: registry/faction classes remain untouched. Consumer validator must be pure; apply must accept a fully prepared deep copy and commit atomically without per-record partial commits.

## Risks
- SaveStore is callback-driven and is not wired to concrete player/entity/faction/domain owners yet; that consumer adapter remains an integration responsibility.
- Native atomic replacement relies on same-directory `DirAccess.rename_absolute` behavior, verified here on the approved macOS runtime.

## Follow-up tasks
- Main Agent: reproduce the focused suite on integrated state, decide whether `save_store` belongs in the `all` suite, and coordinate the concrete snapshot/atomic-apply adapter with CORE-04 consumers.
