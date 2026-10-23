# ASSET-01 worker report

## Task

**Status:** complete, accepted by Main Agent after reproduction and structural Godot import.

**Model / change:** Added a deterministic smoke fixture, its editable `.blend`, exported `.glb`, and asset conventions/provenance documentation. Initial sandboxed Blender processes segfaulted during Metal backend detection before Python started. The same Blender build ran successfully using the approved escalated command; the observed failure is therefore scoped to sandbox execution, not a Blender 5.2 compatibility failure.

## Files changed

- `tools/blender/check_environment.py` — creates and validates a one-meter cube with bottom-center pivot, metric units, one material and UVs, saves the `.blend`, exports GLB and checks the GLB header/chunks/mesh/material/bounds/indices/UVs.
- `art/reference/environment-smoke/environment_smoke.blend` — editable smoke scene; 96,061 bytes.
- `art/reference/environment-smoke/environment_smoke.glb` — exported fixture; 1,980 bytes.
- `art/reference/environment-smoke/README.md` — identifies this as a smoke fixture, not approved art.
- `docs/asset-pipeline.md` — units, axes, pivots, naming, texture color spaces, folders, Godot validation and binary policy.
- `docs/asset-provenance.md` — origin/license/generation/export record requirements and fixture hashes.

## Tests run

- **Passed:** `python3 -c 'import ast,pathlib; ast.parse(pathlib.Path("tools/blender/check_environment.py").read_text()); print("syntax: PASS")'` — exit 0. `python3 -m py_compile tools/blender/check_environment.py` was also attempted, but Python could not create cache under the restricted user cache path; the non-writing AST parse passed.
- **Passed:** `/Applications/Blender.app/Contents/MacOS/Blender --version` — exit 0; reports `Blender 5.2.3 LTS`, build date 2026-10-22, hash `e13b728c6880`.
- **Failed in sandbox:** `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/blender/check_environment.py` — exit 139 (SIGSEGV), before Python output.
- **Failed in sandbox:** `/Applications/Blender.app/Contents/MacOS/Blender -b --disable-autoexec --python-expr "print('HEADLESS_OK')"` — exit 139 (SIGSEGV), before Python output.
- **Failed in sandbox:** `/Applications/Blender.app/Contents/MacOS/Blender -b --gpu-backend opengl --python-expr "print('HEADLESS_OK')"` — exit 139; Blender reported `metal` as its only accepted backend and then crashed.
- **Passed with approved escalation:** `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/blender/check_environment.py` — exit 0; Blender 5.2.3 LTS saved the `.blend`, exported a 1,980-byte GLB, and the script's structural validation passed. The script reports 1 object, 1.0 × 1.0 × 1.0 m and 12 triangles.
- **Passed with approved escalation:** `/Applications/Blender.app/Contents/MacOS/Blender -b art/reference/environment-smoke/environment_smoke.blend --python-exit-code 1 --python /Users/rukithnayak/.agents/skills/blender-asset-qa/scripts/qa_check.py -- --objects SMK_Block --profile game` — JSON `pass: true`, no errors or warnings. Metrics: 8 verts, 6 faces, 12 tris, 0 ngons, 0 non-manifold/boundary edges, 1 material, 1 UV map, 0% UV out-of-bounds/overlap, ground Z 0.
- **Passed with approved escalation:** `/Applications/Blender.app/Contents/MacOS/Blender -b art/reference/environment-smoke/environment_smoke.blend --python-exit-code 1 --python /Users/rukithnayak/.agents/skills/blender-asset-qa/scripts/review_shots.py -- --objects SMK_Block --mode material --views front right top three_quarter --res 256 --out /private/tmp/asset_smoke_review.png` — exit 0; rendered four views and visually inspected the contact sheet. The cube appears intact with expected proportions and material.
- **Passed:** standard-library GLB structure validation — magic `glTF`, version 2, declared length equals actual 1,980 bytes; one mesh, one node, one material, no images; 24 position records (face-split for normals/UVs), 36 indices (12 triangles), Y-up bounds `[-0.5, 0, -0.5]` to `[0.5, 1, 0.5]`, UV coordinates present.
- **Not run:** Godot GLB import. Main agent is handling that check.

## Results

The installed executable is compatible with the Blender 5.2 target and ran the required headless scene/export successfully with approved escalation. Initial direct sandboxed invocations reproducibly failed before Python started; the same script then succeeded via escalation. This is evidence of a sandbox Metal-backend access issue rather than an incompatible or missing Blender runtime. The smoke fixture is valid at the Blender QA and structural GLB levels; Godot orientation/material import is the remaining engine-side validation.

Artifact checksums:

- `environment_smoke.blend` — 96,062 bytes; SHA-256 `82be5f33e5cb31828f15f2d8dd2a94776d4882460ddfc53ac116c03beb2878b0`.
- `environment_smoke.glb` — 1,980 bytes; SHA-256 `25493ee453231314e4fd511a154b88a2f4eae3376bef46f54c112155cfbd3f9b`.

## Risks

- Blender's successful headless execution required approved escalation; ordinary sandboxed runs currently crash during Metal backend detection.
- Godot import remains unverified; engine-side orientation, scale and material appearance are pending.
- Binary storage policy is provisional: retain small reviewed sources/exports in Git; evaluate Git LFS only if measured repository growth warrants it.
- This fixture is operational pipeline evidence only, not approved art direction or a production reference asset.

## Follow-up tasks

- Main agent: import the smoke GLB in Godot and record orientation, scale and material results.
- If routine future Blender execution is needed, use a supported execution mode that avoids the observed sandbox Metal-backend crash.
- Update shared toolchain/task status after Godot import evidence exists. This worker did not edit shared progress/configuration files.

## Main Agent integration evidence

- Reproduced final smoke export with approved escalation: exit 0, 1,980-byte GLB.
- `godot --headless --path game --script ../docs/evidence/ASSET-01-import.gd`: imported with GLTFDocument, exit 0; one mesh, bounds (-0.5, 0, -0.5), size (1, 1, 1), material M_SMK_Neutral. This is structural/material assignment verification, not in-engine visual appearance acceptance (ASSET-03).
- Main Agent inspected [four-view smoke contact sheet](../evidence/ASSET-01-review.png): intact cube, ground pivot, expected teal material.
- Worker gpt-6-luna / medium; Main Agent accepted ASSET-01 23 October 2026 (Asia/Kolkata).
