#!/bin/bash
# render.sh <name> <height_m>
cd /mnt/f/WSL/pixal3d-pilot
LD_LIBRARY_PATH=$HOME/.local/envs/pixal3d/lib ~/apps/blender-4.5.3-linux-x64/blender -b -P scripts/render_iso.py -- --glb out/$1.glb --out_dir renders --name $1 --height $2 2>&1 2>&1 | tail -30
