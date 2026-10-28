# INV-01 — Stable item instances and reproducible loot

**Status:** Accepted, Stage 1.  
**Owner:** Main Agent.  
**Dependency:** CORE-02 accepted.

## Changes

- `ItemDefinition` holds stable item/weapon identity, dimensions, family, magazine capacity and numeric base stats, with validation.
- `ItemInstance` holds a generated RFC-style v4 UUID, grid position, dimensions, rarity, rolled stats, magazine count and data-only equipment state. JSON-shaped serialization validates before replacing state and preserves saved rolls on load.
- `LootTable` performs seeded weighted item and rarity selection with configurable per-tier multiplier bounds. UUID generation uses independent cryptographic randomness so equal seeds reproduce item definitions and stats without duplicating identity.
- Added focused `inventory_items` coverage and registered it in `all`.

Weights, tier names, and stat multipliers have no default balance values. Technical validation caps are documented in the task file; they do not establish approved content or balance. `AmmoPouch` remains INV-03 work.

## Verification

| Command / check | Exit / result |
|---|---|
| Pre-implementation `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_items` | 1; 3 expected failures because the three owned resources were absent. |
| `godot --headless --path game --editor --import` | 0 |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_items` | 0; 24 cases, 0 failures |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0; 351 cases, 0 failures. Godot printed one ObjectDB and one physics RID teardown warning at shutdown. |
| `python3 /Users/rukithnayak/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py game` | 0; 99 files, 0 errors, 0 warnings |
| `git diff --check` | 0 |
| Godot MCP version/project-info calls | Godot 4.7.2; project resolved at the intended `game` directory, 38 scripts. |

No visual or resolution test was required for this data-only task. The all-suite teardown warning is outside inventory code and did not fail the runner.
