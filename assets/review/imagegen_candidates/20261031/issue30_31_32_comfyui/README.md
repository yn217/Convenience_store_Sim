# ComfyUI concept candidates for Issues #30, #31, #32

These PNGs are review-stage concept candidates generated in ComfyUI. They are not production Godot assets.

## Intended use

- `event_cg/`: character-included daily-event concept images at `1920x1080`, matching the project's reference viewport.
- `event_cg_1344x768/`: additional character-included event CG candidates at `1344x768`, suitable for the requested game-event review layout and later scaling/cropping tests.
- `assistant/`: Issue #32 manager-assistant expression references at `512x512`; display target is approximately `256-300px` in the 340px inspector panel.
- `event_icons/`: Issue #31 daily-event POP/HUD icon references at `512x512`; display target is approximately `64-96px`.
- `vfx_icons/`: Issue #30 presentation/VFX icon references at `512x512`; display target is approximately `64-128px`.

## Generation setup

- ComfyUI: local `127.0.0.1:8188`
- Workflow basis: `anima_style_character_random.json`
- UNET: `Anima-Base-v1.0.safetensors`
- CLIP: `qwen_3_06b_base.safetensors` (`qwen_image`)
- VAE: `qwen_image_vae.safetensors`
- LoRA: `Koharu-Koharu-epoch100.safetensors` at `0.8`
- Style LoRA: `anima-style-epoch35-lr5e5.safetensors` at `0.8`
- Sampler: Euler / simple / 24 steps / CFG 4.5

## ComfyUI error recovery note

The attached Node 70 error (`mat1 and mat2 shapes cannot be multiplied (181x5120 and 1024x2048)`) was caused by mixing incompatible model families: `qwen3vl_32b_minimax_h3...` with `lumina2` and `minimax_h3_video_vae` was connected to an Anima graph. The compatible Anima setup used for the assets in this folder is `qwen_3_06b_base.safetensors` with type `qwen_image`, `qwen_image_vae.safetensors`, and `Anima-Base-v1.0.safetensors`.

## Acceptance note

The images have white backgrounds and are not alpha-cut. Production use still requires rights/provenance review, transparent extraction where needed, Godot integration, and the project's `iso2x_v1` scale/anchor checks. The full-screen images are presentation references, not replacements for 4-direction Blender/Godot character sprites.
