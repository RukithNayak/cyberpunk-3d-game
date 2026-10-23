# Cyberpunk UI Overhaul

**Status:** INV-05 presentation update accepted; PLAYER-04 accepted; PLAYER-05 visual/HUD slice implemented, task remains in progress due an approved-scope conflict.  
**Owner:** Main Agent.  
**Spec:** [Approved design](../superpowers/specs/2026-10-23-cyberpunk-ui-overhaul-design.md).  
**Plan:** [Implementation plan](../superpowers/plans/2026-10-23-cyberpunk-ui-overhaul-plan.md).

## Changes

- Added the global `game/ui/cyberpunk_theme.tres` with bold system-monospace typography, charcoal surfaces, amber highlights, cyan accents and red warning styles. Added reusable scanline/status shaders and assigned the Theme project-wide.
- Restyled the inventory through Theme variations and responsive containers. Existing inspect/drag/equip/drop/use/pickup/save/load behavior remains service-backed. The test fixture's controls are hidden by default and toggled with F2. Project startup is fullscreen.
- Added PLAYER-04 transactional weapon state and player snapshot hooks; see [PLAYER-04 report](PLAYER-04.md).
- Added `PlayerHUD` with authoritative vitals, equipped firearm, magazine/reserve, crosshair, hit/damage/death cues and an inline reduced-camera-kick control. Feedback only observes accepted actions and health events.
- Added a fullscreen combat fixture reusing the existing movement blockout.

## Verification

All commands ran from the repository root with Godot `4.7.2.stable.official.ed1daf0bf`:

| Command/action | Exit | Observed result |
|---|---:|---|
| `godot --headless --path game --editor --import` | 0 | Project/resources imported. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_ui` | 0 | `Suite inventory_ui: 43 cases, 0 failures`. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite player_controller` | 0 | `Suite player_controller: 43 cases, 0 failures`; reduced recoil regression was observed red at 1 failure before implementation. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite player_hud` | 0 | `Suite player_hud: 9 cases, 0 failures`. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite weapon_transactions` | 0 | `Suite weapon_transactions: 24 cases, 0 failures`. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | `Suite all: 523 cases, 0 failures`; shutdown logs one ObjectDB leak and one physics-body RID leak. |
| Godot MCP `run_project` on `res://tests/scenes/inventory_fixture.tscn` | Started | `get_debug_output.errors` empty. |
| Godot MCP `run_project` on `res://tests/scenes/combat_feedback.tscn` | Started | `get_debug_output.errors` empty; `stop_project.finalErrors` empty. |
| `screencapture -x docs/evidence/CYBERPUNK-UI-OVERHAUL/inventory-fullscreen.png` | 0 | Fullscreen inventory captured and visually inspected. |
| `screencapture -x docs/evidence/CYBERPUNK-UI-OVERHAUL/combat-hud-fullscreen.png` | 0 | Fullscreen gameplay HUD captured and visually inspected. |
| `git diff --check` | 0 | No whitespace errors. |

## Evidence and limits

- [Inventory fullscreen capture](../evidence/CYBERPUNK-UI-OVERHAUL/inventory-fullscreen.png)
- [Gameplay HUD fullscreen capture](../evidence/CYBERPUNK-UI-OVERHAUL/combat-hud-fullscreen.png)
- [PLAYER-04 report](PLAYER-04.md)

The approved design excludes audio and a pause/settings screen while PLAYER-05's existing acceptance asks for synchronized spatial audio and pause/settings controls. Those checks and implementation remain unresolved; PLAYER-05 is not marked complete. Reduced camera kick is implemented and tested. Human input/click-through and audio timing were not tested. The runtime fixtures are greybox; no production character/building assets are claimed.

## User-directed visual revision — 23 October 2026

The user found the initial presentation too plain, boxy, dark and monotonous. Reworked the shared Theme and the existing inventory presentation without changing service behavior:

- Replaced SF Mono as the general font with installed Avenir Next / Avenir Next Condensed system fonts. Retained a strong uppercase display hierarchy with cyan and amber data accents.
- Raised panel and item-slot contrast to brighter graphite/blue-green tones, softened the empty grid slots, and kept the outer frame asymmetric rather than repeating identical full boxes.
- Expanded the responsive grid, split item cards into glyph, name, rarity/dimensions and magazine rows, and repositioned actions/loot into a clearer right rail.
- Updated both inventory and gameplay HUD through the shared Theme. No item artwork, new game data, filters or gameplay behavior were fabricated.
- Added three focused visual assertions to `inventory_ui`: Avenir display font, brighter shared panel luminance, and readable card size.

### Revision verification

Commands run from the repository root:

| Command/action | Exit | Observed result |
|---|---:|---|
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_ui` before implementation | 1 | New font, panel luminance and cell sizing assertions failed (`46 cases, 3 failures`). Existing interaction checks passed. |
| `godot --headless --path game --editor --import` | 0 | Updated Theme and scripts imported. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_ui` | 0 | `Suite inventory_ui: 46 cases, 0 failures`. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite player_hud` | 0 | `Suite player_hud: 9 cases, 0 failures`. |
| `git diff --check` | 0 | No whitespace errors. |
| Godot MCP `run_project` on inventory fixture; `get_debug_output` | Started / no reported exit | Godot 4.7.2 Compatibility / Metal; errors empty. |
| Godot MCP `run_project` on combat HUD fixture; `get_debug_output` | Started / no reported exit | Godot 4.7.2 Compatibility / Metal; errors empty. |
| `screencapture -x docs/evidence/CYBERPUNK-UI-OVERHAUL/inventory-revised.png` | 0 | Fullscreen capture at 2940×1912 inspected; layout, contrast and card hierarchy visible. |
| `screencapture -x docs/evidence/CYBERPUNK-UI-OVERHAUL/hud-revised.png` | 0 | Fullscreen capture at 2940×1912 inspected; shared typography and brighter corner panels visible. |

Human controller/mouse click-through and alternative resolutions were not run. The inventory fixture contains only three authored sample items, so much of its 24-slot grid is correctly empty. The HUD fixture still shows the greybox environment, not finished city art. PLAYER-05 remains in progress for its unresolved audio and pause/settings acceptance conflict.

- [Revised inventory capture](../evidence/CYBERPUNK-UI-OVERHAUL/inventory-revised.png)
- [Revised gameplay HUD capture](../evidence/CYBERPUNK-UI-OVERHAUL/hud-revised.png)
