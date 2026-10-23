# Night Market Test Block — Design

## Intent
Turn the existing WORLD-06 fullscreen fixture from a set of separated greybox targets into a compact, traversable cyberpunk market block where a player can comfortably test movement/look, combat, NPC dialogue and mission offer, hacking, loot/inventory, healing, streaming, and checkpoint save/restore.

## Goals
- Give the existing fixture a clear start plaza, market street, and service-alley route with recognizable landmarks and sightlines.
- Keep the existing gameplay actors and services authoritative and preserve their current automated smoke and benchmark flows.
- Use lightweight Godot-authored geometry, materials, signage, and lighting; no downloads, new dependencies, Blender asset creation, or production module changes.
- Make the scene practical for fullscreen manual playtesting, with readable route cues and walkable collision.

## Non-goals and constraints
- No full city, new districts, bulk asset production, new gameplay systems, project main-scene change, or release configuration. These remain outside this Stage 1 fixture and under deferred WORLD-07/content scope.
- Do not edit or overwrite user benchmark measurements unrelated to this work.

## Approaches considered
1. **Walkable Night Market block (selected by user):** connect existing targets through a small plaza/street/alley layout. Best balance of natural playtesting and limited implementation.
2. **Mechanics test range:** separate labeled stations; easier isolated checks but does not feel like a world to explore.

## Implementation boundary
Modify only the WORLD-06 fixture presentation/layout code and its owning task/report/tracker records. Preserve target IDs, interaction distances, chunk streaming contracts, and all smoke/benchmark semantics. Record the added fixture scope in WORLD-06 before implementation. Verify with import, WORLD-06 smoke, focused visual runtime inspection, and diff review; do not claim human playtest or art acceptance without the user's own playtest.
