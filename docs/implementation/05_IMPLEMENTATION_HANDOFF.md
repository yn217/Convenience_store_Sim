# Codex / Claude 実装引継ぎ・仕様チェック v1.0
この文書が**レビュー済みの実装開始指示**。ゲームの実装はまだ行っていない。

## 読む順番
1. [00_BASELINE_AND_DECISIONS](00_BASELINE_AND_DECISIONS.md)
2. [01_ENGINE_CONTRACT](01_ENGINE_CONTRACT.md)
3. [02_GRID_AND_ASSET_CONTRACT](02_GRID_AND_ASSET_CONTRACT.md)
4. [03_ECONOMY_AND_SIMULATION_CONTRACT](03_ECONOMY_AND_SIMULATION_CONTRACT.md)
5. [04_UI_SAVE_QA_CONTRACT](04_UI_SAVE_QA_CONTRACT.md)
6. [JSON Schemas](../schemas/)と既存の [GAME_DESIGN_SPEC](../GAME_DESIGN_SPEC.md)、[ASSET_CATALOG](../ASSET_CATALOG.md)、[QA_ACCEPTANCE_PLAN](../QA_ACCEPTANCE_PLAN.md)
7. [Issue task list](../IMPLEMENTATION_TASKS.md)

## ディレクトリ/実装の責任を凍結
|レーン|担当範囲|参照可能な他レーン|主なIssue|
|---|---|---|---|
|Core|domain model, catalog/schema, GameCommands, unit tests|他レーン依存は禁止|#2,#3|
|Layout/Renderer|Projection/StoreWorld, placement, interaction|Core read-only contract|#4,#5,#6,#7,#26|
|Art|Blender Python, mesh, sprite export, manifest, game textures|Core schemaとRenderer public contract|#8,#9,#12,#22,#29|
|Economy|Inventory, Product, Ledger, ads, daily close|Core contracts|#10,#11,#13,#17,#18,#19,#27|
|Customer|fixed tick, crowd, A* access, queue, checkout driver|Core+Economy API|#14,#15,#16,#23|
|UI/Save|HUD, palette, inspector, reports, save/load, tutorial|Application command/read model only|#20,#21,#24,#28|
|QA|headless contracts, scene tests, perf, evidence|全public contracts|#25|

## 必須の着手順（明確な縦断スライス）
- S0: Godot base (#2) + schema (#3) + 校正用赤/青/緑1m軸と空店舗（#4）。**アセット規格はここで契約テストを先に作る**。
- S1: 1×2棚の0/90/180/270をplace/move/remove、入口通路チェック。画面はプレースホルダーでも可（#5,#6,#7）。
- S2: Blenderで1×2棚/レジ/飲料ケースの4方向PNG・manifest出力、Godotでキャリブレーション（#8,#9,#26）。**画像ごとのscale補正禁止**。
- S3: 24SKU、仕入→バックヤード→棚補充→棚画像変化、期限（#10,#11,#12,#13）。
- S4: 客1人の入店→棚アクセス→予約→レジ→会計→退出を固定seedで確認。広告・価格・評判の調整は次に接続（#14〜#18,#27）。
- S5: 仕入/広告/会計/設備投資/廃棄を日次で締め、UIとセーブまで一貫した1日運営（#19〜#21,#28）。
- S6: 10種什器＋客キャラ＋オーバーレイ＋アセットライセンス確認＋QA（#22〜#25,#29）。

## Pull Request/Issue単位のDefinition of Done
- [ ] Contract: 対応するdocs/implementationのインターフェース/状態遷移に準拠。
- [ ] Schema: 対応するJSON Schemaがマスタ例を検証する。仕様変更なら同PRで更新。
- [ ] Domain: 不正な値・途中失敗で現金/在庫/配置が部分変更されないことをテスト。
- [ ] UI: プレイヤー操作で成功・失敗（キャンセル/資金不足/レジなし等）の両方を確認。
- [ ] Art: 同一camera preset/タイル縮尺、4方向、pivot、slot layerを検査。
- [ ] Perf: 必要な変更では条件固定の実測値、負荷プロファイル。
- [ ] Review: PRの本文に該当Issue、試験コマンド、結果、既知制約、画像（UIなら）を記載。
- [ ] 管理: Issue checklist→close、parent #1とIMPLEMENTATION_TASKSも同期。

## 実装してはいけないこと（将来の負債を防止）
- 什器ごとに画像scaleを調整してグリッドが合ったように見せかける。
- 3D PNGを都度AI生成して統一寸法を失う。外形はBlender Pythonを優先。
- 店舗Sceneの`_process`内で売上や現金計算を行う。Frame delta依存は不可。
- 設置プレビューで現金/什器/予約在庫を変更する。
- 顧客がレジ待ちの間に物理棚在庫を二重販売する。
- 営業したレイアウトをUndo/Redoして経済イベントを元に戻したように扱う。
- 保存時に不変条件を検査せずイベントを再実行する。
- FPS比較のため客数/商品表示/viewportを減らし、同条件の性能改善と報告する。

## 仕様上の残る実測・制作承認項目
1. BlenderとGodotの**画像による校正試験**はまだ未実行。camera軸符号/解像度/anchorに実機差があれば、仕様とコードを一緒に修正する。
2. ガラス透明度・文字の小ささ・色調の美観は**人間の目視承認**が必要。レンダーアルゴリズムとしての数値を規定しても完成保証ではない。
3. 売れ行き・ゲーム難易度、チュートリアル所要時間は初回プレイで実測調整する。
4. 最終的なゲーム用ソースアセットとプレイ可能なコードは**未制作**。Issueの完了判定は証拠が出てから行う。

## 最初のCodex Goal
> Repository: yn217/Convenience_store_Sim。docs/implementation/00〜05 および docs/schemas の契約を読んで、Issue #2 #3 #4から開始せよ。開発前にスキーマ/投影/固定stepの最小テストを作り、Blenderの1m校正軸の画像とGodotの配置を一致させる。モデル寸法を調整するためのsprite個別scaleは使わない。各Issueについて検証/PR/チェックリスト更新を行い、未解決仕様差は勝手に埋めず該当仕様とIssueを更新してから実装する。既存成果保護と独立ワークツリーを優先し、PRはレビュー完了までmergeしない。


## 2026-10-23 追加で必読の実装契約
- [08 営業状態とコマンド実行](08_RUNTIME_STATE_AND_COMMANDS.md)：営業と一時停止の分離、speed0でもUI command phaseを実行。
- [09 再現可能な乱数・経済・安全セーブ](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)：Godot 4.7.2、LCG32、商品選択/価格による購買率、費用/ロードの原子性。
- [10 数値の受け入れテストベクトル](10_TEST_VECTORS_AND_ACCEPTANCE.md)：回転/アセット縮尺/価格/会計/保存のGiven-When-Then。
- #2/#3では`business_state` SETUP/OPEN/CLOSING/PAYMENT_BLOCKEDと`applied_command_ids`を保存する。#15/#17では商品選択確率と会計単一commitを実装。


## 2026-10-23 関数別仕様
- [12 実装疑似コード・API](12_REFERENCE_ALGORITHMS_AND_API.md)を読む。UI/アート/Domainの担当境界、atomic transaction、tick/日次の順序を固定。
- 初回OPEN時の費用不足は**副作用ゼロの失敗**、営業中の日境界費用不足のみ未払金へ振替。これを #17/#18/#20で検証。
- 棚アクセス位置0なら配置確定を拒否。OPEN+speed0で什器変更は禁止。
