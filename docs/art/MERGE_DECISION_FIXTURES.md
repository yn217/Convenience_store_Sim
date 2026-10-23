# マージ判断: 什器フィクスチャ（assets/generated/fixtures）

対象: `origin/main`（Codex の calibrated fixture + product pipeline, PR #62/#65/#66/#67）を
`feature/m6-merge-main`（UI / 性能作業）へ取り込む際の、`assets/generated/fixtures/**` の採用判断。

## 結論

**Codex 側（origin/main）のフィクスチャを採用する。** 自分側（HEAD）の生成物は使わない。
`tools/assets/**` も origin/main 側（上位互換の22ファイル構成）を採用する。

理由: Godot の presenter（`scripts/presentation/fixture_sprites.gd`）が読む契約
（`assets/generated/fixtures/<type>/<type>_a.visual.json`、レイヤー `body` / `shadow` / `glass_front`、
回転ごとの `canvas_px` / `anchor_px` / `slot_anchors_px`）は両側で **バイト単位で同一** であり、
PNG のキャンバスサイズも全ファイルで一致する。したがってアンカーはずれず、presenter の変更は不要。

## 証拠

### 1. マニフェスト（visual.json）のキー差分

- `git diff HEAD origin/main` の JSON 差分は **0 件**（`*_a.visual.json` は両側同一）。
- 両側で変わったのは PNG 16 種類（body レイヤーのみ、一部 glass_front は無変更）と `PROVENANCE.json` のみ。
- 例（`shelf_general_a.visual.json`）: 両側とも 32 スロット（`row0_item0` ... `row1_item3` 他）、回転 0 のキーは
  `canvas_px`, `anchor_px`, `layers`, `slot_anchors_px`, `selection_polygon_px`, `sorting_anchor_px`。

### 2. PNG のキャンバス寸法

衝突した body PNG 40 枚について、寸法は自側・Codex 側で **全て一致**（例: `shelf_general_0_body` 442x450、
`register_basic_0_body` 442x359、`fridge_drink_1_body` 442x528、`warmer_oden_0_body` 314x301）。

### 3. ピクセル差分（代表 4 枚）

| sprite | 寸法 | alpha の差分 | 差分ピクセル数 | 最大チャンネル差 | RGB 平均差 |
|---|---|---|---|---|---|
| shelf_general_0_body | 442x450 | bbox が一致 (38,8)-(404,414) | 98,011 | 24 / 255 | 5.25 |
| register_basic_0_body | 442x359 | 一致 (38,8)-(404,323) | 72,981 | 23 / 255 | 7.18 |
| fridge_drink_1_body | 442x528 | 一致 (38,8)-(404,492) | 130,010 | 24 / 255 | 6.71 |
| shelf_noodle_1_body | 442x481 | 一致 (38,8)-(404,445) | 105,554 | 24 / 255 | 5.06 |

輪郭（alpha）は完全一致。差分は陰影・白の階調など色味のみで、ピクセル単位の大差はない。

### 4. 並列比較画像

`docs/art/merge_fixtures_side_by_side.png`（行: shelf_general_0 / register_basic_0 / fridge_drink_1 / shelf_noodle_1、
列: 左=自側(HEAD) / 中=Codex(origin/main) / 右=差分を8倍に増幅）。
幾何・棚板位置・影は一致し、Codex 側は白の階調がやや明るく整理されている。

### 5. バリデータ出力

- `python tools/assets/validate_manifests.py --dir assets/generated/fixtures --catalog data/fixtures/mvp_v1.json`
  -> `asset check: 10 manifest(s), 0 problem(s)`
- `python tools/assets/validate_customers.py --dir assets/generated/characters`
  -> `customer check: 3 manifest(s), 0 problem(s)`
- `python tools/validation/check_catalog.py .` -> `catalog sync check: 0 mismatch(es)`
- Godot 全 suite で fixture 系（`test_fixture_sprites`, `test_fixture_card`, `test_visual_manifests` 等）は通過。

## 採用しなかった選択肢

- 自側フィクスチャを残す案: presenter は両方読めるため技術的理由がない。残すと Codex の product 側
  パイプライン（`products` の shape 生成は同じ iso2x 規約）と世代が混ざり、再生成手順と PROVENANCE が食い違う。
- `tools/assets/**` の自側版を残す案: origin/main 側が同名 11 ファイルを含み、追加 11 ファイル（検証・product・LOD）
  も必要なため、丸ごと origin/main を採用した。自側の `blueprints.py` 等は origin/main に同一内容で存在する。

## 残課題（本マージの範囲外）

- `docs/ASSET_CREDITS.md` の再配布可否は Codex 側行が「要確認」のまま。`tools/validation/check_asset_credits.py`
  はこれを不合格として扱う（11 件）。ライセンス判断はユーザー確認事項。
