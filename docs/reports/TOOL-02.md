# TOOL-02 — Faster prototype workflow and model preference

23 October 2026; Main Agent. Repository workflow complete; live model switch
requires the Codex model picker (`/model`), followed by `/status` to verify.

Changed AGENTS.md, docs/prompt.md, the eight module task execution policies and
master-progress.md. Prefer GPT-6 Luna/medium; use focused tests and quick gameplay
checks, optional red-first/review, short reports and milestone full-suite runs.
Minor bugs/deferred checks may be recorded without blocking working features.
Save corruption, crashes, progression blockers and unauthorized model actions
remain blocking. Stage 0/1 scope and existing implementation are preserved.

Verification: `git diff --check` exit 0. Python 3.12 TOML/policy assertion block
exit 0: saved default model is `gpt-6-luna`, reasoning `medium`, configuration
parses, and all eight module policies no longer mandate red-first testing.
No Codex configuration edit was needed. No gameplay tests run: documentation only.
Next development task: WORLD-04. No implementation worker spawned.
