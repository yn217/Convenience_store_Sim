#!/bin/bash
# render_fx.sh <glb_name> <type> W D H
cd /mnt/f/WSL/pixal3d-pilot
LD_LIBRARY_PATH=$HOME/.local/envs/pixal3d/lib ~/apps/blender-4.5.3-linux-x64/blender -b -P scripts/render_fixture.py -- --glb out/$1.glb --out_dir fixture/$2 --type $2 --body $3 $4 $5 2>&1 | grep -E "^INFO|FRAGMENTS|Error|Traceback|line [0-9]" | cut -c1-900
