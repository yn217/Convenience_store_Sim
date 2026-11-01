#!/bin/bash
E=~/.local/envs/pixal3d
export PATH=$E/bin:$PATH LD_LIBRARY_PATH=$E/lib:$LD_LIBRARY_PATH
export HF_HOME=/mnt/f/WSL/Pixal3D-model-cache/huggingface HF_HUB_OFFLINE=0
export TORCH_HOME=$HOME/pixal3d-models/torch
export ATTN_BACKEND=sdpa SPARSE_ATTN_BACKEND=sdpa
cd /mnt/f/WSL/pixal3d-pilot
M=$HOME/pixal3d-models/Pixal3D
ulimit -n 65536 2>/dev/null || ulimit -n 4096; python -u scripts/run_pixal3d.py --model_path $M --out_dir out --fov 0.2 --resolution 1024 "$@"
