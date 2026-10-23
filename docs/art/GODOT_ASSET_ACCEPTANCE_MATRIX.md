# Godot asset acceptance matrix

更新日: 2026-10-23

この表は、#9/#22/#26/#61の静的アセット監査とGodot実行時受入を混同しないための引き継ぎ用マトリクスです。Godotが利用可能な統合PRで、同一店舗・同一seed・同一カメラ条件のBefore/After画像または動画を添付して判定します。

## 固定条件

|項目|条件|
|---|---|
|店舗|16×12論理グリッド、既存の入口・通路・什器配置|
|画角|`iso2x_v1`、既存カメラ原点、回転0/90/180/270|
|ズーム|0.5 / 1.0 / 2.0|
|什器|`register_basic`, `shelf_general`, `fridge_drink`（基準3種）|
|商品状態|empty / low / medium / full（在庫値から生成）|
|客位置|什器の手前、棚前、什器の裏、レジ待ち|
|出力|1280×720と1920×1080、同一seedのBefore/After|

## 判定マトリクス

|ID|確認|期待結果|静的証跡|Godot証跡|状態|
|---|---|---|---|---|---|
|G-01|基準3種×4方向|輪郭・材質・接地anchorが一貫|manifest/zoom audit|4方向スクリーンショット|未実施|
|G-02|zoom 0.5/1/2|透明端・接地・選択位置が破綻しない|120 raster checks|各zoom画像＋選択操作|未実施|
|G-03|empty→low→medium→full|商品数が在庫値に追従し、固定満棚にならない|LOD 0/2/5/8 audit|同一棚の4状態画像|未実施|
|G-04|商品＋ガラス|商品が扉の背後で読め、ガラスが前面に残る|manifest layer audit|冷蔵ケース4方向画像|未実施|
|G-05|客が什器の手前/裏|客が全体前景化せず、足元が跳ねない|customer manifest/contact sheet|移動シーンまたは録画|未実施|
|G-06|選択・配置・Undo/Redo|選択polygon、配置、復元が既存ロジックと一致|manifest footprint|操作動画＋save差分|未実施|
|G-07|画面サイズ|店舗・GUI・客・什器が隠れず読める|なし|1280×720 / 1920×1080画像|未実施|
|G-08|fallback|候補を無効化して旧visual_idへ戻せる|replacement audit|切替前後の起動確認|未実施|

## 現在の静的結果

- fixture manifest: 10件、4方向、0 problems
- zoom raster: 120 checks、0 problems
- product LOD: 4方向、0 problems
- customer manifest: 3件、0 problems
- provenance coverage: fixture 10 IDs / product 24 visual IDs、0 problems
- occlusion layer: 40回転すべてpending（現行manifestは単一opaque `body`）

G-01〜G-08の「Godot証跡」は未取得です。静的検証が通ったことだけでruntime受入へチェックを移してはいけません。
