# 店内2Dアセット：在庫状態・LOD・設備グレード・性能 実装詳細仕様 v1.0

更新: 2026-10-29 / 対象: 2D棚一体画像のゲーム動作、EMPTY/HALF/FULL、ガラス・人物、設備サイズ・強化、負荷とセーブ。
状態: 設計契約。**既存Domain/APIを勝手に変更しない**。新機能は別Issue/PRで実装・検証して初めてruntime採用。

## 1. 現状の技術的制約

- [ASSET_PRODUCTION_SPEC](../ASSET_PRODUCTION_SPEC.md)は「商品は棚本体に固定焼込禁止、在庫に追従して合成」を原則とする。他方、最近のAI素材は**商品＋棚を一体化したFULL画像**。この2つを明確に調停しないと、売り切れても商品が満載のままになる。
- \`docs/schemas/visual_manifest.schema.json\` の既存\`state\`は\`FULL\`のみ。これは**すでにEMPTY/HALFを正式サポートしていることを意味しない**。一体画像候補の\`EMPTY/HALF/FULL\`はreview素材として保持し、正式schemaの拡張・runtime実装より先に\`runtime_approved:true\`を付けない。
- 現行 \`scripts/presentation/visual_variants.gd\` には \`products_baked=true\` **または** \`state=="FULL"\` で商品を既に描いたとみなし商品overlayを止めるロジックがある。**FULLだけ有効化すると在庫ゼロでも満棚表示**となり得る。必ず営業・在庫状態テストを通す。
- \`scripts/presentation/fixture_sprites.gd\` は4方向manifestのbody/shadow/glassを読む。候補manifestの\`r0\`画像だけでは未対応方向は空描画/fallbackの可能性があるため、4方向完了を正式切替の必須条件とする。

## 2. 望ましい二層構造と選択規則

### A — 推奨: 固定什器ボディ + 可変2D商品

- **原画の品質は保持**したまま、\`fixture_back\`、\`products\`、\`fixture_front/glass_front\`、\`shadow\`に必要な範囲を分解する。
- 商品は単品ごとに3D化しない。生成した棚一体画像の包材・形状を**2Dレイヤー/列/段で切り出す**か、同じ2D作画の個別商品イラストで置換する。
- \`stock_slots\` は\`shelf_slots\`と同じ安定IDで紐付けし、実SKU・available数量・向き・棚位置に応じて可視商品を描く。\`EMPTY\`で表示数は厳密に0。
- 商品の背景が残りそうな場合は商品領域/棚板領域のマスクを使う。元原画のPNG本体を破壊せず、マスクや切出し条件は別JSON/画像に記録。
- 推奨理由: 24SKU×商品組合せ×4方位×在庫密度の爆発的画像生成を避け、商品変更・期限切れ・補充・会計と一致できる。

### B — 条件付き: 同一棚形状の4状態ビジュアル切替

- 演出・小型ケース等で1枚絵の質を優先する場合のみ、**EMPTY/LOW/MEDIUM/FULL × r0..r3** を同じ什器形状・同じcanvas/anchorで作成して切替可能。
- \`EMPTY\`は商品0、\`LOW\`は最大25%、\`MEDIUM\`は25～75%未満、\`FULL\`は75%以上の**視覚密度のみ**。SKUの種類が変更される棚では「単なる満杯アイコン画像」を禁止し、SKUが一致するoverlayまたはカテゴリ汎用装飾にする。
- 元の会話で作成した\`HALF\`は既存Domainの\`MEDIUM\`相当の**アート制作時名称**であり、正式状態名を混在させない。変換表\`HALF→MEDIUM\`をcandidate manifestに書き、runtimeの仕様変更は別途承認。
- Bは**ランタイム切替実装/VisualDef schemaの拡張/Godot動作検証後**のみ採用可。\`FULL\`のbaked spriteを単純に切替設定へ登録するだけの運用は不可。
- 商品が正確に見える必要がある選択UIや拡大時は、同じSKUの2Dラベル/在庫数を別レイヤー表示する。空棚で商品が見えるバグはP0。

## 3. 在庫から表示への決定規則

- 権威は\`Domain\`の在庫。表示だけの\`visual_state\`は保存しない。ゲームのFPS/LOD/アート差分で売上・品目・数量・RNGが変わってはいけない。
- 各slotについて容量\`C>0\`、物理在庫\`P>=0\`、予約\`R\`で\`0<=R<=P\`、販売可能な\`A=P-R\`と定義。画面上の実際の購入可能密度には\`A\`を使う。**予約が取消されれば復元**、会計でP/Rを同時更新しても同じAに保たれる。演出的なレジ待ち商品描画とは別。
- 表示状態は以下の整数演算で求める（浮動小数・丸めの揺れを回避）：

\`\`\`text
if C <= 0: NOT_APPLICABLE
else if A <= 0: EMPTY
else if 100*A <= 25*C: LOW
else if 100*A < 75*C: MEDIUM
else: FULL
\`\`\`

- 棚全体の状態は個別slotの実数\`ΣA/ΣC\`を同じ閾値に代入した派生値。ただし各slotの\`EMPTY\`は全体FULLでも**必ず空として表示**する。
- SKU単位在庫/期限切れ/欠品は表示対象slotとのマッピングが正しい必要がある。actual SKUや価格はUI inspectorが表示、画像に焼き込まれたAI文字や価格は**ゲームデータとして使わない**。
- \`A==0\`時には商品のpixmap/label/halo/反射も隠れること。**影やガラスのフレームは残してよい**。
- テスト: \`P,R,C\` = (0,0,4)->EMPTY, (1,0,4)->LOW, (2,0,4)->MEDIUM, (3,0,4)->FULL, (4,1,4)->FULL, (1,1,4)->EMPTY, (1,0,4)への予約取消->LOW。画面・Domain値の双方を比較。

## 4. 表示状態とガラス・人物・選択

描画の基本順:

1. 床と独立接地影（店舗照明に応じて適切にmodulate）
2. \`fixture_back\`/設備内部
3. 商品slotの可変2D商品群（奥→手前、底面のYでソート）
4. 必要に応じた人物の奥/前セグメント
5. \`fixture_front\`、透明\`glass_front\`、扉反射
6. 選択輪郭、商品カテゴリ/値札などのUI

- \`FixturePresenter\`が既にスクリーン列セグメント分割を持つため、**商品一体FULL画像**の採用時はこの仕組みと単一画像の相互遮蔽を試験する。顧客が背面を通る/正面で商品を取る/レジ列に立つケースを同一seedで撮影。
- 透明ガラスは画面合成で商品を隠さず、夜間の発光は冷ケースと常温棚で異なる。接地影を二重焼込まない。キャラクターの頭・手を不透明画像で常時覆う不具合を禁止。
- 選択/配置は\`footprint\`/アクセスtileで決定。Spriteの影/透明余白/POPで通行セルは増減しない。回転で\`access_edges\`も変わる。

## 5. 画像解像度LODと設備グレードを別概念にする

| 次元 | 説明 | ゲームロジックに影響するか |
|---|---|---|
| \`original_source\` | 1536px等、後加工用の無変更原画 | いいえ |
| \`runtime_lod\` | 256/512/原寸表示。ズームと画素負荷の都合で切替 | **いいえ** |
| \`fixture_grade\` | 標準・大型・上位など、**物理寸法と性能が異なる設備型式** | **はい**（DomainのFixtureDefで決定） |
| \`cosmetic_variant\` | 色/看板/外装などの視覚差分 | いいえ（明示した例外以外） |

- \`grade\`に画像ファイルの解像度を使わない。256pxの「高級設備」と原寸表示の「通常設備」が同時に存在しても性能定義は安定しなければならない。
- 新しい大型什器は**別\`fixture_type_id\`**を使用し、既存1×2などを壊さない。旧SAVE中の\`type_id\`は勝手に変換しない。
- 新グレードを有効にする必須データ: \`type_id\`, \`footprint(w,h)\`, \`dimensions_m\`, \`access_edges\`, \`placement_cost_yen\`, \`electricity_cost_yen_per_day\`, \`capacity_units\`, \`shelf_slots\`, \`allowed_categories\`, \`visual_id\`。容量はslot容量の和。既存 \`docs/schemas/fixture_definition.schema.json\`に合格すること。
- 大型/小型の設備性能差は購入価格/収納容量/補充頻度/電気代/維持費/販売サービス時間などの**独立した仕様値**で評価。既存schemaに無い\`maintenance_cost\`や\`checkout_speed\`はそのまま勝手に挿入せず、**新たな仕様・Domain/Schema/SaveテストのPR**を必要とする。
- 大きい設備の面積が店舗通行を妨げること自体がコストになる。価格だけ上げて「上位装備」としない。設置合法性、客動線/予約/販売アクセス、衝突、入口経路を別々に確認。
- **価格や倍率の新しい数値は未承認**。現行MVPの値を変えず、グレード別balance表はレビュー・ゲームテスト後に別Issueでユーザー確認して確定。ランダムな係数をゲームへ混ぜない。
- 設備交換の提案: \`replace_fixture(old_id,new_type_id)\`は**既存機能ではない**。追加する場合は在庫退避/返金/新占有/通路再計算/費用を原子的に処理し、失敗は完全ロールバック。実装前は新設備の個別購入・配置で対応。

## 6. LOD選択と性能検証

- sourceは2倍解像度。ズーム\`0.5, 1.0, 2.0\`で表示のピクセル密度/描画枚数/見た目を比較。既存商品用LODの例（\`zoom<0.75\`遠景、\`0.75..1.35\`中景、\`>1.35\`近景、±0.05ヒステリシス）は**参考初期値**で、什器本体のLODにそのまま強制しない。
- LOD切替は\`zoom\`と描画画素数から行い、設備の種類・容量・性能値と無関係。画素原寸縮小時に輪郭/値札/商品名を失わせない。
- 同一layout・同一seed・同一視点・同一runtime商品数でFPS/p95 frame time/memory/テクスチャ数を計測。**16×12タイル、什器20、可視客30、1920×1080**を最低共通条件とする。別途1280×720も撮影。x1/x4、昼/夜、zoom0.5/1/2、空/満、最高描画負荷を分けて記録。
- 60FPS相当（16.67ms/frame）は**目標であり測定PASS済みではない**。新アセット有無の差を同じ条件で測り、p95フレーム時間やピークメモリの悪化を報告。テスト時に顧客/棚/画質を減らした場合は別条件とする。
- マルチ区画一体画像はGPU上の大判透過テクスチャとしてVRAM負荷になる。実際に必要な解像度をプロファイルして常時原寸表示に固定しない。
- SAVE→LOAD、設置回転、撤去、補充、予約→会計、予約取消、廃棄、画面ズーム切替の前後で、**会計・在庫のゴールデン値が全く変わらないこと**。

## 7. 採用・回帰テストの具体例

| Test ID | 入力 | 合格条件 |
|---|---|---|
| AS-01 | EMPTY/LOW/MEDIUM/FULL、4向き | 什器本体の棚板/支柱/足元/前縁は完全一致。商品のみ適切に変化 |
| AS-02 | 在庫0で FULL baked 候補をoverride有効 | **本番経路では FULL表示を拒否/正常にEMPTYへ切替**。満棚表示のままならFAIL |
| AS-03 | 予約/取消/会計の一連操作 | 上記 A=P−Rに従う表示、在庫・売上数はDomain goldensと一致 |
| AS-04 | 什器0/90/180/270°回転 | 足元ずれ<=1screen px、全辺の傾き・アクセス側・選択/人物遮蔽を保持 |
| AS-05 | ガラスケースの背後/手前を客が通る | 背面/ガラス/商品/人物の描画順に矛盾なし |
| AS-06 | 2×2氷ケース/大型3区画と他什器の隣接 | 各物理footprint、アクセス、通路を破壊しない |
| AS-07 | zoom0.5/1/2、1920×1080/1280×720 | 商品判読可、フリンジ/クリップ/急なLODちらつきなし |
| AS-08 | 画質LODを変更し固定seedで1日シミュレーション | 売上/在庫/来店/費用/SAVE差分が完全一致 |
| AS-09 | 未承認manifest、破損PNG、unknown visual_id | runtimeは既存画材にfallback、クラッシュ/ドメイン状態変化なし |
| AS-10 | 大型設備/標準設備を別type_idで販売 | 価格/容量/電力の差がFixtureDefで確定し、LODのみ変更で数値が不変 |

関連 [02_GRID_AND_ASSET_CONTRACT](../implementation/02_GRID_AND_ASSET_CONTRACT.md)、[09_DETERMINISTIC_SIMULATION_AND_SAVE](../implementation/09_DETERMINISTIC_SIMULATION_AND_SAVE.md)、[2D_ASSET_PRODUCTION_AND_PROJECTION_V1](2D_ASSET_PRODUCTION_AND_PROJECTION_V1.md)、[Issue #163](https://github.com/yn217/Convenience_store_Sim/issues/163)。
