# Blender実装用アセットBlueprint・サイズ統一・自動検証仕様 v1.0

> **2026-10-29 2D適用範囲追補**: 本書のBlender生成工程は過去の3Dソースまたは再現可能な手続き的素材の制作例であり、新規の2D画像生成素材にBlenderを要求しない。新規2Dの[型式/投影/校正](../art/2D_ASSET_PRODUCTION_AND_PROJECTION_V1.md)・[runtime状態/設備グレード](../art/2D_ASSET_RUNTIME_AND_EQUIPMENT_V1.md)・[納品QA](../art/2D_ASSET_EXTERIOR_AND_PIPELINE_V1.md)を採用する。数値寸法は[02](02_GRID_AND_ASSET_CONTRACT.md)が正本であり、**ImageGenのプロンプトだけでは投影校正PASSにならない**。


> 目的: アセット担当者が、寸法/画像サイズ/向き/アクセス面を独自解釈せずBlender Pythonで同じ結果を作る。
> **[02_GRID_AND_ASSET_CONTRACT](02_GRID_AND_ASSET_CONTRACT.md)が物理寸法・座標系の正本。**
> まだモデルもPNGも生成していない。ここの数値は制作時の初期パラメータとして使用する。

## 1. 共通モデリング規格
- Blender世界単位: 1unit=1m、world XYが床、+Zが上、fixtureのローカルセル(0,0)中心を`(0,0,0)`とする。
- footprint w×hの床の占有矩形: X`[-0.5,w-0.5]`, Y`[-0.5,h-0.5]`、メッシュ外周は各辺0.04m以内に納める。
- 本体最大幅`w−0.08m`、最大奥行`h−0.08m`。小物や看板で0.10m以上張り出すモデルは不採用。
- 遮蔽物の高さは表の`height_m`を超えず±0.01m誤差で検証。
- **1×2什器は奥行(Y)方向に2m長く、販売アクセスfrontはEast(+X側)の長辺2m**。1×1おでんはNorth(-Y)がfront。アイス2×2は四辺。
- 共通パーツの標準厚み: 金属フレーム0.025m、棚板0.018m、透明扉0.010m、ベース0.08m、値札レール0.02m、支柱幅0.04m。部品が最大外形を越えないよう自動クリップ/配置。
- カメラ`iso2x_v1`: Blender正投影方位45°、仰角30°、sourceは1mの+X(+128,+64)px/+Y(-128,+64)px/+Z(0,-156.767)px。各バッチで校正画像を作って数値検証。色管理は**固定preset**（AgX/Standardは作業前に一方へ統一、初期値Standard・View Look Medium High Contrast・同一ライティング）。個別アセットの露出変更禁止。
- 造形パーツ材質: frame_metal、shelf_white、clear_glass、cool_white_led、dark_polymer、label_rail、product_surface の7共通material ID。明度の差・透明度は名前付きpresetを使用。
- 照明: 同一キーライト/補助ライト/環境光をscene presetから参照。商品用の発光素材は装飾passで処理し、棚本体の露出を変えない。

## 2. 什器Blueprint — 基本10種
|type_id|脚・外枠|棚板/容器分割|局所アート特性|front|
|---|---|---|---|---|
|register_basic|0.92×1.92×1.20mのカウンタ、POS端末|サービス上面高さ0.92m、端末高さ1.20以内|客側E、店員側W、queueはE面|E|
|shelf_general|0.92×1.92×1.50m、支柱4本|0.32/0.64/0.96/1.28mの4棚|商品slotはE面側の各棚へ並べる|E|
|shelf_onigiri|0.92×1.92×1.40m、傾斜陳列|0.36/0.70/1.04mの3段|三角包装が東向き正面に見える|E|
|warmer_oden|0.92×0.92×1.10mの保温台|鍋内を3×2の領域に分割|透明ふたと湯気はbodyとは別pass|N|
|shelf_noodle|0.92×1.92×1.70mの棚|0.40/0.80/1.20/1.52mの4段|カップ模型は共通円錐台|E|
|shelf_bread|0.92×1.92×1.50m、傾斜籠|0.33/0.69/1.05mの3段|袋の半透明素材とパン色|E|
|fridge_drink|0.92×1.92×2.00m、扉・LED|0.46/0.96/1.46mの3段・全60unit|body→商品→glass_front→反射の順|E|
|shelf_snack|0.92×1.92×1.60m、棚＋フック|0.30/0.64/0.98/1.32mの4段|袋物/箱物/吊り商品|E|
|fridge_dessert|0.92×1.92×1.60m、ガラス|0.37/0.77/1.17mの3段|プリン容器の透過/反射|E|
|freezer_ice|1.92×1.92×1.00m、天面透明|内槽を4×4区画|上面覗込みの透明蓋|N/E/S/W|

この表の高さは装飾含む最大高さ。「POS端末が1.20より突出」などでメッシュ高さ違反が出た場合はパーツ寸法を調整し、他の什器のpixel scaleには触らない。

## 3. 製品の標準容器サイズ（元モデルのm単位）
|形状shape_id|代表商品|幅/直径(m)|奥行(m)|高さ(m)|素材|
|---|---|---:|---:|---:|---|
|onigiri_triangle|おにぎり|0.105|0.045|0.095|包装フィルム＋ラベル|
|oden_piece|おでん|0.085|0.085|0.045|調理食品|
|cup_noodle|カップ麺|0.110|0.110|0.120|紙カップ＋蓋ラベル|
|bread_bag|パン|0.170|0.085|0.090|透明袋＋パン色|
|bottle_500|飲料|0.068|0.068|0.225|PET＋巻ラベル|
|snack_pouch|おかし|0.130|0.055|0.215|樹脂袋|
|dessert_cup|デザート|0.100|0.100|0.115|透明カップ|
|ice_bar_pack|アイス|0.080|0.025|0.175|包材|
形状はSKU間で**共通寸法テンプレート**を使う。商品によって容器が異なる場合はshape variantとしてデータ登録し、SKU固有の画像を後から非等方スケールしない。

## 4. 陳列スロット配置の生成ルール
- 什器`shelf_slots[]`はカテゴリ互換と**論理容量**を表す。見た目の容器位置と実在庫は1:1ではない。
- 1×2型3段什器の例: `row0,row1,row2`それぞれ論理容量20（合計60）。表示上は各行**最大8個の容器スプライト**を並べ、数量に応じて0/2/5/8個表示（empty/low/medium/full）。正確な数量はUI。
- 什器X=0のcenter cellからE面(+X)へ商品を向けて、段高zとY方向の長辺を使い商品を等間隔に並べる。
- レンダー元の列数=8なら`y_i = -0.35 + i*(1.70/7)`、i=0..7（m）、xは**本体mesh内部**かつ棚端+0.02m余裕の位置（例x=0.30m）。これを各回転のワールドXYへ回転してから正投影し、pixel slot anchorを生成。
- 1×2の総横幅はlocal Y軸の最大1.92m、商品の幅/奥行はshapeで決まる。隣り合う容器がかぶる場合は、**表示上の個数を減らす**（容量を減らさない）。3段以外の棚はshelf_countと段高さから位置を生成。
- 回転後は**3Dスロット位置を回転してから投影**する。0°のPNGを画像の2D回転だけで代用しない。
- `slot_anchors_px`は商品合成の**各display slot**を識別できるID（例 row0_item0〜row0_item7）を持つ仕様へ拡張する。従来のrow0のみはレガシーの説明例であり、実装では展開したdisplay slot anchorsを生成して用いる。
- 4段以上の商品やアイス/おでんは配置形状を`grid`、`rack`、`tray`として共通モジュール化し、容器を個別ハードコードしない。
- LOD: 遠景カテゴリ色のみ、中景最大4個/段、近景最大8個/段。閾値例zoom<0.75/0.75..1.35/>1.35、切替ヒステリシス±0.05。対応する描画数は必ず空=0。

## 5. メッシュと画像のサイズを揃える具体的なアルゴリズム
1. FixtureDefからw,h,heightとパーツ構成を読む。Blenderでworld寸法通りに造形し、**非等方scaleをApplyしてbounding boxを測定**。
2. Box `[-.46,w-.54]×[-.46,h-.54]`（m）の外にframe/door/handleが出ていれば**生成失敗**。
3. カメラは`iso2x_v1`の一つを参照。Red X/Green Y/Blue Zの1m校正棒をレンダリングし、source軸差分を測定。未校正なら出力禁止。
4. 向きr=0..3に対してモデルを世界Z軸まわりに90r度回転する。セル(0,0)基準が保たれるよう回転後のfootprint bbox最小セルを新originに再配置。カメラは回さない。
5. **同じrender space**にbody、shadow、glass_front、front/back、商品用アンカーを描画。レイヤーをまとめたalpha bboxにsource 8px paddingを入れ、**全レイヤー同じcrop**にする。
6. 背景透明のRGBA PNGを方向ごとに書き出す。画像全体を`fixed width×height`へ強制伸縮しない。
7. crop前の`world(0,0,0)`投影座標からcrop左上を引き`anchor_px`を算出。`slot_anchors_px`も同じ差分で決める。slot anchorに手で数値を入力しない。
8. JSON manifestを書き出し、`docs/schemas/visual_manifest.schema.json`で型/必須チェック、実画像パス・alpha・anchor・bbox・描画校正を別のsemantic validatorで検証。
9. Godotで`Sprite2D.position = world_to_screen(origin_tile)`, top-left=`position-anchor_px*zoom/2`として表示。**全モデルのper-instance scaleはzoom/2以外を許可しない**。
10. 見た目の品質は`register_basic, shelf_general, fridge_drink`の3種を基準とする。並べて縮尺、アンカー、ガラス透明、奥行き順を目視確認し、問題があればBlender generatorへ戻す。

## 6. 実装契約の自動チェック
- モデルworld mesh bbox幅/奥行/高さ、全10種のfront side、4回転後のfootprintが正しい。
- source投影X/Y差分±1px、Z差分±2px。pivotのanchorによる床位置誤差ズーム1.0で<=1 screen px。
- per-direction PNGのRGBA, canvas/anchor, per-slot位置が画像内（または明示的に画像外を許したマニフェスト）であり、参照パスが存在。
- 全レイヤーが同じcrop座標/キャンバス/anchor。PNGの画像サイズが異なること自体はエラー扱いしない。
- 1×2冷蔵庫はE面2つのアクセスtileから購入可能。2×2アイスは4方向のいずれかのアクセス辺から購入可能。
- 商品カタログ数×方向×在庫量のPNG全組合せ生成は**禁止**。商品画像はslot/layer合成する。
- 設備寸法やカメラが変わった場合は画像のみ更新するのではなく、全アセットを同一presetで再生成し、ゴールデンテストを更新。
- **現時点では校正画像・実アセットが存在しないため、自動テストがPASSしたとは主張しない**。
