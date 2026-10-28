# デザート冷蔵ケース（FULL）/ ChatGPTで生成した2D原画 — 未承認

**実画像を生成**：日本のコンビニのプリン、シュークリーム、ロールケーキ、ショートケーキ、パフェ、ヨーグルトを並べた低型冷蔵ショーケース。カップ麺や飲料ではない。

## このPRへの登録範囲
このコミットでは**仕様JSONと引継ぎREADMEのみ**を登録。ChatGPT上には原画1536×1024 RGBA PNG（3,110,856B, SHA-256 prefix `819cdf41da617dd1`）、原寸WebP、512px/256px PNGがあるが、**PNG/WebPのGitHubバイナリ登録は未完了**。メタデータ登録だけで画像登録済みと報告しないこと。

## Codexへの必須作業
1. ユーザーから`dessert_case_full_small_json_20261029.zip`を受領し、このディレクトリへ`source_original.png`, `source_fullres.webp`, `game_512.png`, `game_256.png`を原寸・無破壊で追加。`sha256sum`で原画が`819cdf41da617dd1`から始まることを検証。`git add/commit/push`、PR #164でGitHubバイナリ実在を確認。
2. 既存Godot`iso2x_v1`、r0販売面+X、長辺斜面−0.5、world footprint/ground pivotに実Gameで校正。**非等方伸縮/文字を反転させた鏡像修正禁止**。
3. 背景の半透明黒フリンジ、透明マスク、低ズーム/1.0/1.6の画質、棚と商品のスケールを実測。修正は原画を残して別ファイルへ。
4. 食品がプリン・ケーキ等だけであることを独立QAし、EMPTY/HALFはFULLの**同一本体形状**に基づいて制作。
5. ユーザー承認まで`runtime_approved:false`, PR Draftのまま、mainへマージしない。

関連 #157 #163 #123。
