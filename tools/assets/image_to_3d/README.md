# Local Image-to-3D evaluation (#102 / #123)

Use WSL distribution **Ubuntu-F**, registered at `F:\WSL\Ubuntu-F\rootfs`.
All source clones, environments, model caches and outputs are on F: or inside that
distribution. The user-supplied clipboard input was copied once to the experiment
input directory. Do not start the C:-backed `Ubuntu` distribution.

## Acceptance contract

Fused shelf-and-products models are allowed. Mesh separability is not a pass/fail
criterion. FULL/HALF/EMPTY must retain the same cabinet shape, shelf count and
heights, posts, dimensions, footprint and floor anchor. Products must disappear in
EMPTY and remain in natural clusters in HALF. Visual approval and runtime QA are
separate from dimensional normalization. Candidates remain `runtime_approved:false`.

Only shelf_general FULL/r0 is the production pilot. Front/back/left/right views are
diagnostic evidence, not permission to publish other stock states or rotations.
The double-sided gondola is a visual proposal; gameplay access remains an external
contract decision. Do not modify Godot Scene, Renderer, GameState or customer AI.

## Verified environment / source revisions

- RTX 3090 24576 MiB; CUDA tensor matrix multiplication succeeded.
- Python 3.10.22; PyTorch 2.6.0+cu124; CUDA Toolkit 12.4.1.
- Blender 4.5.3 Linux `67807e1800cc`; use env lib directory in LD_LIBRARY_PATH.
- Pixal3D source `f7cf38429b0bd264f1995f0f8743a88b1c728b94`.
- Pixal3D pipeline config `b0cb2e1b794cab9aa0ac38a95d794a4d9337437f`.
- TRELLIS.2 source `75fbf0183001ed9876c8dbb35de6b68552ee08bd`.

## Pixal3D observations (not inference success)

Official requirements reference current MoGe, which now requires trimesh >=4.11,
conflicting with Pixal3D's trimesh 4.10.1 pin. The CLI-only requirements here omit
MoGe; the official `--fov 0.2` option avoids camera estimation by MoGe.

CUDA extension wheel builds on `/mnt/f` failed with `Operation not permitted`.
Copy build sources into Ubuntu-F's Linux filesystem before installing extensions.
The extension build was paused after the required official DINOv3 weights could
not be retrieved: Hugging Face returned gated-repository 401; the official Meta
ViT-L/16 CDN endpoint returned 403. The GitHub code is public; pretrained weights
are separate and Meta documents requesting access. Do not use an unofficial
mirror to bypass this gate. No Pixal3D GLB has been generated.

Official references:
- https://github.com/TencentARC/Pixal3D
- https://github.com/facebookresearch/dinov3#pretrained-models
- https://huggingface.co/facebook/dinov3-vitl16-pretrain-lvd1689m

## Hunyuan3D fallback

`requirements-hunyuan-shape.txt` is a shape-only subset of upstream requirements.
Its dedicated venv inherits CUDA PyTorch from the base environment and overrides
Python package versions locally. It does not change the Pixal3D environment.

```
wsl.exe -d Ubuntu-F -u inayut -- /home/inayut/.local/envs/hunyuan3d/bin/python -u /mnt/f/WSL/Pixal3D-project/tools/assets/image_to_3d/run_hunyuan_shape.py --source /mnt/f/WSL/Hunyuan3D-2.1-upstream --image /mnt/f/WSL/Pixal3D-project/build/issue123-image-to-3d/input/prepared/shelf_gondola_input.png --out /mnt/f/WSL/Pixal3D-project/build/issue123-image-to-3d/hunyuan
```

The runner pins the official weights revision, runs the official sample before
the shelf, and records mesh counts, hashes, elapsed time and PyTorch peak GPU
memory. `raw_generated.glb` is shape-only until a separate texture stage succeeds.
Do not label it as a textured or production-approved result.

The Hunyuan3D-2.1 Community License includes territorial and output-use
restrictions. Keep generated models in local evaluation storage; do not add them
to the public GitHub repository before distribution terms have been resolved.
See https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/LICENSE .

## Blender comparison and import

`blender_gondola_comparator.py` produces a conventional procedural comparison.
`normalize_render_glb.py` imports an actual GLB, preserves its hierarchy, saves a
Blender project and diagnostic renders, and reports bounds/materials/UV/images.
Source front/up must be explicitly specified after inspecting the generated mesh.
Independent axis fitting changes proportions; a target bbox does not prove that
shelf parts, product scale, access or visual quality are correct.

Use Cycles CPU for portable headless rendering when EGL is unavailable. Preserve
the camera, world scale and anchor; make alpha-cropped previews separately.
