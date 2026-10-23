# Cyberpunk UI Overhaul — Design

## Intent

Give the existing inventory screen and the planned first-person HUD one consistent, high-end sci-fi visual language, based on the two supplied Cyberpunk 2077 references. Preserve authoritative game services and inventory interactions.

## Goals

- Use one reusable project Theme resource and shared StyleBoxes: near-black charcoal surfaces, amber primary focus, cyan/white secondary information, and red warnings.
- Use monospaced bold display text and a clear hierarchy for uppercase section labels, item details, values, and status messages. Use installed system monospace fallback names; do not add fonts or dependencies.
- Arrange both screens with anchors and Godot containers, not hand-positioned layout children.
- Keep the inventory grid, inspection, equipment, loot, save/load, input locks, and cancellation behavior functional.
- Give the gameplay HUD authoritative health and weapon/ammunition values, with a crosshair and compact corner panels.
- Add restrained canvas-item scanline and terminal status effects. Do not use full-screen screen-reading chromatic aberration or effects that reduce text readability.

## Non-goals

- No minimap, objectives, map data, new combat rules, audio, pause/settings screen, or placeholder gameplay values.
- No changes to inventory, health, combat, or persistence ownership contracts except the PLAYER-04 work already required before PLAYER-05.
- No new fonts, assets, engine plugins, downloads, or Stage 2–5 work.

## Approaches

1. Restyle the inventory alone. This is the smallest change but leaves the requested gameplay reference without a matching HUD.
2. Share a Theme across the inventory and gameplay HUD. This matches both references and keeps repeated surfaces consistent. **Chosen:** the user selected inventory plus gameplay HUD. Use existing INV-05 and PLAYER-05 ownership; do not create a competing task.
3. Add viewport-wide CRT post-processing and chromatic aberration. This affects the rendered game, can impair readability, and is unnecessary for a diegetic HUD. Rejected in favor of localized, low-intensity UI shaders.

## Architecture and sequence

- INV-05 owns the existing inventory UI and fixture. Add `game/ui/cyberpunk_theme.tres` and shared HUD shader resources here, set the project custom Theme, and replace per-node style overrides with Theme types and StyleBox variations. Keep dynamic grid cells service-backed.
- PLAYER-05 owns the first-person HUD. Its task depends on PLAYER-04 and INV-04. Complete PLAYER-04 first so the HUD can read authoritative magazine, reserve, and health state. Then build a `CanvasLayer` with a full-rect `Control`, corner-anchored panels, container-based health/ammo rows, and a centered crosshair.
- Keep the HUD limited to health, active weapon/magazine/reserve, crosshair, and the existing accepted hit/damage/death feedback scope. Do not invent a minimap or objective feed without owning data.
- Attach a reusable scanline material to a decorative full-rect `ColorRect`; keep it transparent and low contrast. Attach a separate subtle flicker/glitch material only to a small warning/status element. Leave primary labels on Theme fonts without shader distortion.
- Set the project launch mode to fullscreen, as the user's only target mode. Do not spend time testing unrelated resolutions.

## Acceptance evidence

- Existing inventory interactions and PLAYER-04 authoritative state tests continue to pass.
- Project import and Godot MCP runtime launch the inventory fixture and gameplay HUD without script/shader errors.
- Inspect one fullscreen capture of each screen for contrast, clipping, focus and readable text where display capture is available. Record unavailable visual evidence honestly.

## Implementation calls

- This design uses existing task ownership and sequencing rather than adding a new task: INV-05 first, PLAYER-04 prerequisite next, PLAYER-05 HUD last.
- The actual images were present at `/Users/rukithnayak/Downloads/cyberpunk ui1.jpeg` and `/Users/rukithnayak/Downloads/cyberpunk inv1.jpeg`; review found a minimal gameplay corner HUD and a dark full-screen inventory with fine red/cyan dividers. The implementation will follow the user's requested amber/cyan/white/red palette rather than copy their exact red palette.

## User-directed visual revision — 23 October 2026

The first implementation was reviewed by the user and rejected as too plain, boxy, dark, and monotonous in typography. Keep the same INV-05 and PLAYER-05 ownership and all behavior, but update presentation to match the supplied references more closely:

- Replace monospace as the primary typeface with installed Avenir Next / Avenir Next Condensed system fonts; retain monospace only for compact telemetry where it improves scanability.
- Use brighter graphite/blue-green surfaces, stronger cyan/red dividers and luminous accents while retaining enough contrast over the game.
- Give the inventory grid more screen area, style occupied slots as equipment cards, and group readout/actions/loot into an intentional right rail. Show only values derived from the current services; do not add nonfunctional filters, invented balances, or item art claims.
- Keep the gameplay HUD restrained and anchored at the corners, with the revised type hierarchy and panel contrast.
- Add focused UI acceptance checks for the font, surface contrast and equipment card sizing; verify both actual runtime scenes and inspect fresh fullscreen captures.
