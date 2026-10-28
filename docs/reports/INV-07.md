# INV-07 — Mara market stock and conversation polish

**Status:** Implementation and automated checks complete; full-screen visual inspection remains outstanding, so INV-07 stays in progress.

## Delivered

- Added an authored Mara stock panel with three Street Medkits at 40 CR each.
- Purchases validate merchant ownership, fixed offer ID, stock, current credits and free grid space before committing. Successful purchases debit MissionDirector credits, insert a data-only ItemInstance, decrement stock and cache the transaction result to prevent replay.
- Mission snapshots now allow a net credit balance below starting funds plus completed authored rewards after spending, while still rejecting balances above that bound. Merchant stock and transaction IDs are runtime-only.
- Model instructions request concise, natural spoken dialogue. The authored fallback is conversational. Literal `\\n` sequences become line breaks, real line breaks remain intact, and untrusted text is escaped for RichTextLabel BBCode.
- Unauthorized trade responses are now in character and do not say that the vendor lacks a panel.
- Night Market starts with 100 authored credits. The mission snapshot accepts a balance up to configured starting credits plus completed authored rewards, and still rejects credit creation above that bound.
- Typing direct requests such as “Could I get a medkit?” purchases from the authored stock without requiring the market button. The purchase uses the same stock/funds/capacity/owner checks and replies in the transcript. Other dialogue still goes to Ollama.

## Verification

Regression-first check, before implementation:

- `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_ui` — exit **1**, expected regressions: literal newline rendering and missing Mara stock panel (15 other cases passed).

After implementation:

- `godot --headless --path game --editor --import` — exit **0**.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_ui` — exit **0**, 24 cases, 0 failures. Includes button-opened panel, purchase, replay, wrong owner, sold-out stock, full inventory, insufficient credits, and saved remaining balance.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_actions` — exit **0**, 41 cases, 0 failures; includes stale-stock rejection and duplicate trade response.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite missions` — exit **0**, 46 cases, 0 failures.
- `git diff --check` — exit **0**.
- Godot MCP `run_project` — launch succeeded; output included `NIGHT_MARKET_READY controls=E_talk,LMB_fire,R_reload,Tab_inventory model=llama3:willowbrook`. MCP debug output showed no runtime errors and three pre-existing GDScript warnings (`dialogue_orchestrator.gd:131`, `perception.gd:70`, `tactical_agent.gd:316`).
- The dialogue fixture prints a pre-existing shutdown warning for two ObjectDB instances; assertions still passed. No integrated `all` suite was run for this bounded prototype update.

## Follow-up: text purchases and starting credits

Regression-first checks, before implementation:

- `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_ui` — exit **1**; text purchase confirmation and item transfer were missing (also exposed a pending mock response in the old flow).
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite missions` — exit **0**, but the attempted five-argument configure call emitted a runtime error (“Method expected 4 argument(s), but called with 5”). The runner did not count this as a failed assertion; treat it as diagnostic evidence, not a passing regression test.

After implementation:

- `godot --headless --path game --editor --import` — exit **0**.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite dialogue_ui` — exit **0**, 26 cases, 0 failures; typed “Could I get a medkit?” grants the item, charges 40 CR and returns Mara’s confirmation without opening the stock panel.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite missions` — exit **0**, 49 cases, 0 failures; covers the 100 CR initial balance, snapshot round-trip, and rejection of a forged increase.

## Remaining evidence

The configured Godot MCP tools expose launch and debug output but no screenshot/capture operation, and the Godot app was not available as a desktop window for CUA. Therefore the full-screen visual review is explicitly unrun. Automated fixture evidence is in [test_ui.gd](../../game/tests/dialogue/test_ui.gd); no screenshot is claimed.
