# 実装着手判定 — 仕様レビュー最終チェック（2026-10-22）

## 結論
**設計資料としては実装に着手可能（Specification Ready）**。開発中に決めるべき重大な**未定義インターフェース・寸法・在庫/会計の処理順**はMVP分について規格化した。
ただし**Implement/Asset Readyではない**。コード、Blenderモデル、PNG、Godotでの画角/接地の実測、ゲームバランスのプレイテスト、性能SLOの実測はまだ存在しない。

## 1. レビュー対象と追加成果物
- 既存: GAME_DESIGN_SPEC、ASSET_PRODUCTION_SPEC、ASSET_CATALOG、SIMULATION_ECONOMY_SPEC、GAMEPLAY_UX_SPEC、QA_ACCEPTANCE_PLAN、Issue #1〜#29。
- 新規実装正本: 00 BASELINE、01 ENGINE、02 GRID&ASSET、03 ECONOMY&SIM、04 UI/SAVE/QA、05 HANDOFF、06 BLUEPRINT。
- マシンチェック用: fixture/product/visual/save/balanceのJSON Schema 5種、什器10種＋24SKU＋balance＋空店舗save＋冷蔵ケースdisplay manifestのサンプル。
- 旧仕様との整合は実装正本優先を明記。重要Issueへ受入条件を追加。

## 2. 重要レビュー指摘への対応
|ID|従来の不足/危険|新規規格/解消方法|状態|
|---|---|---|---|
|R-01|1tile実寸はあるがPNG寸法が不統一|1tile=1m、display128×64、source256×128を固定|設計確定|
|R-02|Blenderカメラの「約30°」が曖昧|方位45°・仰角30°、X/Y/Zのsource画素差分と許容誤差|設計確定・実画像未検証|
|R-03|1×2の「前面」が短辺になる|1×2什器すべてE面（長辺2m）を客側、回転90°→S面|設計確定|
|R-04|画像を全部同じpxへ伸縮して揃える懸念|世界寸法・同一camera・crop後pivot一致。PNG canvas可変|設計確定|
|R-05|棚/商品の合成と透明ガラス|什器本体/slot sprite/ガラス/影を分離、4方向anchor|設計確定・実画像未検証|
|R-06|製品の形状/サイズが未定|商品8形状のm単位寸法、10設備のbbox/段数/価格/容量を確定|設計確定|
|R-07|仕入・廃棄・予約・会計の二重更新|FEFO segment/予約/原子会計/idempotent event/順序|設計確定|
|R-08|レジ無しでも配置可能か曖昧|新規店はレジ0で建設可、営業開始だけ拒否|設計確定|
|R-09|広告や日付境界が曖昧|翌日予算適用・一日一回請求・固定step・固定seed|設計確定|
|R-10|UI/保存/Undo/Redoが曖昧|exclusive input mode、savegame v1 schema、配置Undoを補償台帳で処理|設計確定|
|R-11|初期24SKU/10什器の手入力リスク|JSON seedファイルで凍結、参照ID/容量整合チェック|設計確定|
|R-12|QAの合否がコード有無依存|数値golden・シーン・画像投影校正・固定ベンチを区分|計画確定・未実施|

## 3. 現時点で実施した静的レビュー
- JSON Schema 5種のサンプル構造検査で、単体fixture、SKU、visual、balance、空店舗saveにエラーなし（2026-10-22）。
- 什器10種のcapacity_units = sum(shelf_slots容量)、footprint−0.08m以内のサイズ、1×2のfront=E、24 SKU=8カテゴリ×3、単体サンプルとマスタ例のID一致を確認。
- 4方向sample visualに各24個のdisplay slot anchorがあること、coordinateがcanvas内であることを確認。
- **これらはJSONの静的検査でありGodot/Blender実行による検証ではない**。画像ファイル名はplaceholder。

## 4. 実装開始前のチェック（仕様ではなくコード/制作作業）
- [ ] Godotの実プロジェクトを作成、runtime Catalog validator/Save loaderを実装する。
- [ ] JSON Schemaのvalidatorとsemantic validatorを実行し、未知カテゴリ・画像欠落・オーバー容量・不正IDで失敗することを確認。
- [ ] Blender generatorを作り、1m校正棒のsource投影 X(+128,+64)、Y(−128,+64)、Z(0,−156.767)と一致させる。
- [ ] 3基準什器4方向PNGのphysical bbox/pivot/edge accessをGodotで比較。**モデル毎scale調整は禁止**。
- [ ] 顧客の予約/会計/商品在庫の原子性、撤去Undoの補償台帳とsave/loadを実機/単体テスト。
- [ ] 全10什器と24商品画像を生成し、利用条件・商標・見た目を目視レビューする。
- [ ] 16×12/什器20/客30/1920×1080を固定して性能を測る。
- [ ] 初回プレイから一日決算までUI操作のみで完走する。

## 5. 残る承認が必要なもの
- アートの見た目: ガラス表現、ラベル判読性、リアル寄りの程度は基準画像3種が出た時点で目視で最終決定。
- バランス: 売れやすさ、広告効果、初期予算、ゲーム時間は **v1.0の数値でまず実装**、プレイテスト後に変更Issue化。設計不足を理由に実装着手を止めない。
- 性能: 60FPSは目標であり未達/達成の事実は未計測。
- OS/エンジンminor version: プロジェクト初回コミット時にGodot 4系の使用minor/patch版を固定し、READMEで記録。エンジン版差分を無断混在させない。

## 6. 実装引継ぎ
- Start: Issue #2, #3, #4。その後 #8（アセット自動生成）と #6（配置）を並列化できる。
- 質問/仕様差が発生した場合は[05_IMPLEMENTATION_HANDOFF](05_IMPLEMENTATION_HANDOFF.md)の順に規格を参照する。
- GitHub Actionsは使わずローカルで単体/画面/実機測定を実施。
- **この文書があることだけで子Issueをcloseしない。** 各Issueのチェックを実装とテストで満たす。
