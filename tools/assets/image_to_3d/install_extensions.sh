#!/usr/bin/env bash
set -euo pipefail
export CUDA_HOME=/home/inayut/.local/envs/pixal3d
export TORCH_CUDA_ARCH_LIST=8.6
export MAX_JOBS=4
export NATTEN_CUDA_ARCH=86
export NATTEN_N_WORKERS=4
python -m pip install /home/inayut/pixal3d-build-src/FlexGEMM-upstream --no-build-isolation
python -m pip install /home/inayut/pixal3d-build-src/CuMesh-upstream --no-build-isolation
python -m pip install /home/inayut/pixal3d-build-src/TRELLIS2-upstream/o-voxel --no-build-isolation
python -m pip install /home/inayut/pixal3d-build-src/nvdiffrast-upstream --no-build-isolation
python -m pip install natten==0.21.0 --no-build-isolation
python -c 'import flex_gemm,cumesh,o_voxel,nvdiffrast.torch,natten; print("CUDA_EXTENSIONS_IMPORT_OK")'
