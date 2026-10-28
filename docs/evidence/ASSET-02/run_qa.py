#!/usr/bin/env python3
"""Run Blender Asset QA for the current ASSET-02 source scene.

Example (from the repository root):
  Blender -b art/reference/wall_doorway.blend --python-exit-code 1 \
    --python docs/evidence/ASSET-02/run_qa.py -- --role render \
    --out docs/evidence/ASSET-02/wall_qa.json
"""
import argparse
import json
from pathlib import Path
import sys
import bpy

QA_SCRIPTS = Path("/Users/rukithnayak/.agents/skills/blender-asset-qa/scripts")
sys.path.insert(0, str(QA_SCRIPTS))
import qa_check

parser = argparse.ArgumentParser()
parser.add_argument("--role", choices=("render", "collision"), required=True)
parser.add_argument("--out", required=True)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
objects = [o.name for o in bpy.context.scene.objects
           if o.type == "MESH" and o.get("asset_role") == args.role]
result = qa_check.run(objects=objects, profile="game", eps=0.005, tol=0.002)
out = Path(args.out)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"pass": result["pass"], "errors": result["errors"],
                  "warnings": result["warnings"], "floating": result["floating"],
                  "zfighting": result["zfighting"], "object_count": len(result["objects"]),
                  "triangles": sum(m["tris"] for m in result["objects"].values()),
                  "report": str(out)}, sort_keys=True))
if not result["pass"]:
    raise SystemExit(1)
