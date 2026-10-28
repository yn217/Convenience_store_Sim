# fridge_drink_open_front_chatgpt_20261029_v2 — 未承認2Dアセット

- 画像の実内容：Japanese convenience store low open-front refrigerated beverage display, not dessert display
- 本来依頼された「日本のコンビニのデザートケース」とは異なるため、**飲料冷蔵設備の追加候補**として分類し、デザート棚としてゲームへ接続しない。
- `source_original.png` は生成元の1536×1024原画を非破壊保存。
- `source_fullres.webp` は画寸同一の圧縮高画質候補。
- `game_512.png`/`game_256.png` は縮小LOD版。描画解像度とゲーム内の設備グレード・売上・陳列容量は別管理。
- 背景/alpha：dark studio background is opaque (RGBA alpha 255); background removal REQUIRED before runtime
- `iso2x_v1` の角度、画面傾き、world ground anchor、設備幅・扉開き・衝突判定、昼夜の発光についてGodot画面との比較が必要。
- `runtime_approved:false`。ユーザー承認前にmainへマージしない。
