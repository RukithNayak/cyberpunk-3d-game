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

## Fast prototype workflow (user decision, 23 October 2026)

Prefer GPT-6 Luna with medium reasoning for the Main Agent and bounded workers.
The live session model is selected in Codex; repository instructions cannot switch it.
Prioritize a playable prototype. Minor bugs and polish issues may be deferred with a
short note. This policy supersedes older red-first, exhaustive testing, mandatory
review and long-report process instructions in task files and workflow skills.
Read the tracker and owning task; consult only relevant design/dependency sections.
Use subagents only when their bounded work is likely to save time.

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
the runner with Main Agent coordination.

- Run one relevant focused suite for logic changes, and a quick in-engine check
  when gameplay or visuals change. Import when scripts/resources/imports change.
- Add tests for meaningful failure risks; test-first/red-first is optional for
  routine features. Protect save integrity, one-time rewards and model authority
  with targeted regressions when changing those paths.
- Run `all` at integration milestones, before pushing gameplay changes, or when
  changing shared persistence/contracts; do not rerun it after every small edit.
- Inspect the diff once. No routine independent reviewer or duplicate verification.
- Keep reports short: changed files, exact checks/exits, observed behavior, known
  bugs and next task. Record unrun checks honestly; do not label them passed.
- A working task may be accepted with documented minor bugs and deferred edge
  cases. Crashes, save corruption, blocked progression and unauthorized model
  mutations remain blockers. Record deferred checks/issues explicitly rather than
  marking their test/evidence checkboxes passed.
- Asset changes need basic geometry/export and engine appearance checks. Reserve
  exhaustive asset/performance QA for reference or integration milestones.

Headless success does not establish visual quality, performance or playtest acceptance.
