# ComfyUI concept candidates for Issues #30, #31, #32

These PNGs are review-stage concept candidates generated in ComfyUI. They are not production Godot assets.

## Intended use

- `event_cg/`: character-included daily-event concept images at `1920x1080`, matching the project's reference viewport.
- `event_cg_1344x768/`: additional character-included event CG candidates at `1344x768`, suitable for the requested game-event review layout and later scaling/cropping tests.
- `event_cg_revision_1344x768/`: second-pass candidates with fixed staff uniform, stronger event-specific poses/backgrounds, six revisions, and two new events.
- `event_cg_revision2_1344x768/`: third-pass composition candidates focused on task-oriented gaze, POS/retail equipment, stronger event actions, and smaller environmental framing.
- `event_cg_revision4_1344x768/`: accepted focused revisions for the rival-store exterior and individually packaged bread shelf; rejected intermediate variants are not included.
- `event_cg_revision5_1344x768/`: accepted v6 candidates with explicit Japanese konbini architecture, rival-store storefront visibility, and compact flow-wrap bread packaging.
- `management_events_1344x768/`: first-pass management/event scene candidates; generated without readable management text, numbers, or UI overlays so Godot can compose those elements.
- `management_events_revision2_1344x768/`: reviewed revisions for sold-out shelves, checkout queue, word-of-mouth, autumn fair, and closing success.
- `management_events_revision3_1344x768/`: single-hero base candidates for sold-out, checkout queue, word-of-mouth, autumn fair, and closing success. Multi-person Inpaint prototypes remain outside the accepted asset folders until mask seams are resolved.
- `new_event_cg_1344x768/`: ten new event CG candidates for promotion, seasonal campaigns, store operations, and regional events (Issues #30/#32/#137/#140); the lost-customer scene uses one background customer while keeping a single Koharu Rikka.
- `character_sprites_1024x1536/`: a double-odango character sprite set: one base standing image, twelve pose candidates, four framing revisions, and three hand-quality comparison candidates. These remain solid-background review PNGs; transparent RGBA extraction is a separate production step.
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

The revision pass keeps both LoRAs at `0.8` and uses `1344x768`. It standardizes the white blouse, burgundy ribbon, and dark navy apron uniform, reserves text and numeric UI for Godot, and avoids recognizable real-world store branding.

The new event pass also uses `1344x768`, keeps both LoRAs at `0.8`, and leaves readable campaign copy, prices, and UI to Godot. The discount-sticker image is a visual work-step reference; its sticker lettering is intentionally not production text.

The character-sprite pass uses `1024x1536`, fixes both upper-side hair buns with weighted positive and negative prompts, and records every Seed. The hand comparison subset adds explicit finger, thumb, palm, and wrist constraints for open-palm, clasped-hands, and held-product poses. The A/B test uses the same Seed for the long and shortened hand prompts; the C2 candidate applies standard ComfyUI Inpaint conditioning to the B image while preserving the rest of the body. The images are not yet alpha-cut. The additional 50-pose expansion is intentionally deferred.
