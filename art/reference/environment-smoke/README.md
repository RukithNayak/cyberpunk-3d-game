# Environment smoke fixture

This directory contains a tiny Blender-to-GLB pipeline fixture, not approved art direction or a production reference asset. The fixture is one 1 m cube with a bottom-center pivot, one neutral material and a simple non-overlapping UV atlas.

The source `.blend` is 96,061 bytes and the exported `.glb` is 1,980 bytes. Blender export and game-profile asset QA passed when run with the approved escalated command. Earlier sandboxed Blender calls segfaulted during Metal backend detection before Python execution; see `docs/reports/ASSET-01-worker.md` for the distinction and exact evidence. Godot import remains pending.
