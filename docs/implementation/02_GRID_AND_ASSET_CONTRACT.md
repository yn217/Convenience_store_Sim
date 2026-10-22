# Grid / 2.5D / Asset Physical-Scale Contract v1.0
**最重要: すべての設備を同じ縮尺で制作するための実装規格。**
参照: [00_BASELINE](00_BASELINE_AND_DECISIONS.md), [ASSET_CATALOG](../ASSET_CATALOG.md)。旧アセット文書の「約30°」「画像サイズは例」は本書の固定値で補完する。

## A. 固定座標・縮尺
- 論理タイル1つは**世界座標1.000m×1.000m**。原点は店舗内セル(0,0)の**中心**、セル`(x,y)`中心は世界平面`(x[m], y[m])`。
- 全体の論理セル: 0<=x<16,0<=y<12。外壁は境界edgeで、壁のあるセルも床として使用可能。西側の(0,5),(0,6)edgeに入口。
- 基準描画でひし形セルの対角線は**128screen px (横) ×64screen px (縦)**。ズーム=1.0。アセットの元画像は2倍でレンダリングし**256×128 source px per tile diamond**。PNG全体サイズを全什器で統一する意味ではない。
- ゲーム用の座標投影（tile中心x,y、世界高z[m]）：
```text
screen_u = origin_u + 64*(x-y)
screen_v = origin_v + 32*(x+y) - 78.38367177*z
source_u = 2*(screen_u-origin_u) = 128*(x-y)
source_v = 2*(screen_v-origin_v) = 64*(x+y) - 156.76734354*z
```
- Blender正投影は**方位45°・仰角30°**。投影比2:1が得られるよう、正投影でレンダーの**worldの1m軸→source画面水平128px/縦64px**を校正する。ワールド垂直1mはsource画面で上へ約156.767px。Blenderのcamera quaternion軸符号は**校正画像の+X/+Y方向で検証**し、ソース画像が誤って左右反転している場合は修正。
- 数値校正はカメラの仰角30°を正式値とし、レンダーエンジンやトリミングの影響を測定して±1 source px以内。**全アセットに同一camera/scale/lighting preset ID** `iso2x_v1`を使う。

## B. 物理寸法の厳格な統一ルール
- `footprint=(w,h)`は回転0における**ゲームロジックの占有セル数**であり、モデルを1tileずつ無条件に分割するものではない。
- 什器の本体メッシュはworld X幅`w*1.0 - 0.08m`以下、world Y奥行`h*1.0 - 0.08m`以下（四辺4cm以上のクリアランス）。**どのモデルも比率変更/非等方拡大で縮尺を合わせない**。パーツの実寸を守る。
- 物理占有の境界はworld X:`[-0.5,w-0.5]`, Y:`[-0.5,h-0.5]`。モデル本体外形はX:`[-0.46,w-0.54]`、Y:`[-0.46,h-0.54]`以内。展示POPや電線等のはみ出しは別のVisualDecorationとしてゲームの移動判定には影響させないが、MVPでは什器外周から**0.10m超の突出は不可**。
- **影**は別のアルファsprite。占有外への描画は0.15mまで可（隣接タイル占有/当たり判定は増やさない）。シャドウの見た目が建築壁を突き抜ける場合はクリッピング。
- **高さは商品カテゴリによって違ってよい**。高さの一致は要求しない。高さが異なっても足元の同じ世界座標を投影することで大きさが揃う。
- 当たり判定/通路は**論理footprintを使用**。PNGの透明余白、文字ラベル、影では通行可否を決めない。
- front側アクセスは回転0でworld−Y（North）に向くことを全什器で共通化。90°回転でN→E→S→W。おでん/アイスのアクセス辺の集合のみ例外として明示。

## C. 設備10種の数値寸法マスター（v1.0のデフォルト）
|type_id|占有 w×h|本体最大 幅×奥行 (m)|高さ(m)|価格(円)|電気代(円/日)|客アクセス辺|容量unit|
|---|---|---|---:|---:|---:|---|---:|
|register_basic|1×2|0.92×1.92|1.20|90,000|50|N（客）、Sは装飾スタッフ側|—|
|shelf_general|1×2|0.92×1.92|1.50|40,000|0|N|48|
|shelf_onigiri|1×2|0.92×1.92|1.40|45,000|15|N|36|
|warmer_oden|1×1|0.92×0.92|1.10|60,000|100|N|24|
|shelf_noodle|1×2|0.92×1.92|1.70|42,000|0|N|42|
|shelf_bread|1×2|0.92×1.92|1.50|40,000|0|N|36|
|fridge_drink|1×2|0.92×1.92|2.00|120,000|200|N|60|
|shelf_snack|1×2|0.92×1.92|1.60|40,000|0|N|54|
|fridge_dessert|1×2|0.92×1.92|1.60|110,000|150|N|36|
|freezer_ice|2×2|1.92×1.92|1.00|130,000|180|N,E,S,W （上面から取る演出）|48|
上記は**ゲーム用規格寸法/バランス初期値**。全て同じ基準から数式計算するので1×2の棚より2×2のケースの足元が縮尺違いにならない。脚、把手等の本体の外形は最大内に収める。もっと実物風の小物が必要ならゲーム用サイズの範囲で再設計する。

## D. 設置・回転・アクセスタイル
- 向き`r=0/1/2/3`で時計回りに90°ずつ。ローカルセル`(u,v)`の回転は
```text
r0:(u,v), dims(w,h)
r1:(h-1-v,u), dims(h,w)
r2:(w-1-u,h-1-v), dims(w,h)
r3:(v,w-1-u), dims(h,w)
```
- 配置インスタンスの`origin_tile`は**回転後占有矩形の最小x/minyセル**。モデル側のローカル世界座標も回転/平行移動され、同じアンカーを新矩形のセル(0,0)中心に合わせる。
- r0 1×2 => cells {(x,y),(x,y+1)}。r1 => 2×1。r0 front(N) のアクセスは y-1 の向きの辺の前方に隣接するwalking cellの集合。
- frontの「面全長」で顧客がアクセスできる範囲を求める。例えば2×2でNorth面は`(x,y-1)`,`(x+1,y-1)`。アクセス面が壁/設備/構造でふさがる場所を除外。
- 経路通行は4近傍、斜めすり抜けを禁止。入口tileから棚アクセスtile/レジqueue service cellへの連結をチェック。
- 什器配置のサニティ条件は、out-of-bounds/overlap/構造不可/入口塞ぎ/予算不足。レジ無し時も合法什器は設置可能（営業開始だけ不可）。
- ストアレジ1台のqueueセルは、N面の正面1〜3タイルを候補として外向きに列挙し、到達できるものだけ使う。狭い/他の什器により列が短い場合は1タイルqueueを許容、0なら営業不可。

## E. 原画像サイズ、crop、anchor統一規則
- **スプライトPNGのキャンバス幅/高さはアセットごと・向きごとに異なってよい。** 共通にすべきは正投影倍率、足元基準、明るさ/質感、cell占有、レイヤー順。
- Blenderでオブジェクトと床マーカーを共通のrender-spaceに描画。RGBA透明で書き出し。render-spaceはアセットの全レイヤーで同じ基準。
- 4方位それぞれのbody/shadow/overlayに対し、まず全レイヤーを含むalpha bounding boxを計算し、左右上下**8 source pixel以上の共通padding**を加え、**同方向の全レイヤーは同一crop rectangle**を使う。anchor_pxはcrop前のworld(0,0,0)位置からcrop_left/topを引いて計算。
- 各レイヤーは同じcanvas_px、同じanchor_px、同じslot_anchors_px。ズームでanchorは単純に倍率を掛ける。**8 source pxの余白と見た目の幅を合わせるためのPNG自動ストレッチは禁止**。
- 派生画像に`source_px_per_tile=[256,128]`, `projection_id="iso2x_v1"`, `world_units_per_tile=1.0`, `footprint`, `origin_pivot`, `anchor_px`, `canvas_px`, `layers`, `slots`を付ける。
- sprite position = world_to_screen(instance origin tile center), image top-left=position − anchor_px * (game_zoom/2)。源画像x2をゲームに1/2縮小で表示。
- 透明マージンの画面外切れを避けるためviewport外周ではclip/boundsを再計算。PNGの上下左右はanchorより小さくてはならない、という条件は**要求しない**（ピボットが画像外にある影などを許す場合はmanifestで明示）。

## F. 並び順とヒットテスト
1. Floor、Wall background、Fixture back、Product slots、Customer、Fixture front（扉/前面）、UI overlayのレイヤー順を役割単位で区別。
2. 什器の背面にいる客と前面の客が同じ1枚絵に隠される場合、什器をfront/back segmentに分割。単純y-sortだけに頼らない。店内の上下全体の順序も「足元のスクリーンY」でソートする。
3. 選択判定は**world→tile逆変換→占有マップ上のinstance_id**を優先。重なったスプライトのpixel alphaだけで当たり判定を決定しない。
4. Sprite visualの絵柄は物理通行/販売アクセスを変更しない。表示ズレがあればモデル/manifestを修正し、**ゲーム側で什器ごとscale係数を変更しない**。

## G. 自動ゲートとゴールデンテスト
- **カメラ校正**: worldのX=1mはsourceスクリーン差分(+128,+64)px、Y=1mは(−128,+64)px、高さZ=1mは(0,−156.767)px。許容値X/Y ±1.0 source px、Z ±2.0 source px。画像出力に対する校正は各バッチの最初に実施。
- **寸法**: 10タイプ全てfootprint整数、width/depth <= (w,h)−0.08m、world heightはマスタと±0.01m以内。単位はメートル、無宣言のスケール変更は禁止。
- **manifest**: rotations 0/1/2/3の全画像を検出、PNG alpha付き、canvas・anchor・slotsに不正座標なし。安全のためファイルパスはasset root配下のみ。
- **重ね合わせ**: 4方向それぞれ、同じworld pivot位置にレンダーした床輪郭と什器footprintを重ね、接地点ずれ<=1 screen px（ズーム1.0）。
- **統合**: 1×2棚の4方向配置、2×2アイス、背高飲料ケース、客が前後通過、棚空/満のslot overlayをGodot実画面で確認。
- **画像寸法**: すべて同一PNGサイズを要求する検証は禁止（物理サイズ統一と矛盾する）。
- 初期ファイルの試験データは`docs/examples/fridge_drink.visual.json`、型の正本は`docs/schemas/visual_manifest.schema.json`。
