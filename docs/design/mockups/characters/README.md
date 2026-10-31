# Issue #32 character UI mockup

This directory contains one visual proposal for the Issue #32 screen where a
store-manager assistant helps the player read daily challenges and growth
achievements.

## Scope

- `issue32_assistant_growth_rikka.png` is a static design reference for the
  assistant / achievement / daily-challenge screen.
- The character is Koharu Rikka, used here as a visual guide beside the
  progression panels.
- The intended information architecture is: daily challenges, achievement
  milestones, completion history, and badge-only rewards.
- This asset does not implement the screen, progression rules, event IDs,
  save/load behavior, notification deduplication, or reward accounting.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

