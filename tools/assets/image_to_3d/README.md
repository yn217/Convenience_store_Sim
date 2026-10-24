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
wsl.exe -d Ubuntu-F -u inayut -- /home/inayut/.local/envs/hunyuan3d/bin/python -u /mnt/f/WSL/Pixal3D-project/tools/assets/image_to_3d/run_hunyuan_shape.py --source /mnt/f/WSL/Hunyuan3D-2.1-upstream --image /mnt/f/WSL/Pixal3D-project/build/issue123-image-to-3d/input/prepared_v3/shelf_gondola_input.png --out /mnt/f/WSL/Pixal3D-project/build/issue123-image-to-3d/hunyuan_v3
```

The runner pins the official weights revision, runs the official sample before
the shelf, and records mesh counts, hashes, elapsed time and PyTorch peak GPU
memory. `raw_generated.glb` is shape-only until a separate texture stage succeeds.
Do not label it as a textured or production-approved result.
Generate the reviewed input first with `prepare_reference.py --source <user design
sheet path> --out <experiment>/input/prepared_v3`. Review `matte_preview.png` before
inference. `--shelf-only` skips the official sample ONLY after that sample has been
successfully generated; the v3 evidence used this focused rerun option.

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

## Observed result, 2026-10-24 (not an accepted game asset)

Local shape inference and actual GLB import succeeded. Official sample: 108.33 s,
13,611,472 bytes. The corrected `prepared_v3` shelf input produced a 20,072,924-byte
GLB in 93.07 s (inference/extraction/export, excluding model load). Peak PyTorch
allocation was 8,193,657,344 bytes and reservation was 9,265,217,536 bytes.
The initial input had an incorrectly retained white background wedge; it was
rejected and preserved separately. v3 removes that wedge and retains the upright.

Source code: Hunyuan `82920d643c0dc2f7bfd7255f45f62d386edfe60c`.
Weights: `0b94677654c57bb9a6b6845cd7b704ccf551d327`.
Shelf input SHA256: `97c2573fb10d928b7736a1dec076c26b77d434ca04d85d43cfa7aebc63a34297`.
Raw GLB SHA256: `6a326d5ae420c5b12409caef76363e8f4faf3891c34b8ffbfe53e90db83271fb`.
Seed 42, 30 steps, surface extraction resolution 384. No paint inference has run.

The independent visual review is **NO-GO**: decks, upright structure, product
forms and selling faces collapse into irregular broad surfaces. Matching the
outer bbox did not fix this. Independent axis fitting has a max/min scale ratio
of 2.56, so physical layout is not certified. UV, materials and textures are absent
in this shape-only GLB. Fused meshes themselves are permitted and are not the
reason for failure. See `review_hunyuan_v3.md`.

Local evidence under ignored `build/issue123-image-to-3d/`:

- `hunyuan_v3/shelf_general_FULL/raw_generated.glb`
- `hunyuan_v3/diagnostics/normalized.glb` and `shelf_gondola.blend`
- `hunyuan_v3/diagnostics/{front,back,left,right,iso2x_r0}.png`
- `hunyuan_v3/inference_report.json` and `blender.log`
- `comparison_v3/comparison.png` and `comparison.json`

The comparison separates fitted aesthetic crops from unchanged source-pixel
scale. Zoom previews are downsampled Blender renders, **not Godot screenshots**.
Semantic product-front and exposed-deck pixel areas are UNKNOWN without masks.
No HALF/EMPTY or other production rotations are approved. Do not paint over the
failed geometry as a substitute for repairing its structure. A more precise
procedural structural pilot is the next local comparison, not a claim that
Image-to-3D has reached mockup quality.

Paint setup has compiled the two official CUDA extensions, but import is blocked
by upstream's `bpy==4.0` dependency in the Python 3.10 environment. The paint runner
and requirements are an unverified, not-yet-runnable checkpoint; do not treat
their presence as successful texture generation. Model/venv/cache and generated
Hunyuan meshes/images remain outside Git; source and textual observations only
are eligible for this PR. No Godot integration or runtime approval was performed.
