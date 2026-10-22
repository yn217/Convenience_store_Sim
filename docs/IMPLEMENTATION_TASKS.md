# Convenience_store_Sim — 実装タスクリスト

> 作成日: 2026-10-22 / 状態: 計画済み（未着手）
>
> 正本: [詳細ゲーム仕様書](GAME_DESIGN_SPEC.md) / [MVP親Issue #1](https://github.com/yn217/Convenience_store_Sim/issues/1)
>
> **注意**: チェックボックスは着手前の初期値。進捗はGitHub Issueのopen/closed・PR証跡を優先し、本表は定期同期する。Issueが完了するまでチェックしない。

## 着手順と並列化ルール

1. **最初は #2 → #3 → #4** を進める。画面表示とモデルのデータ契約を先に確定する。
2. **#8（Blenderパイプライン）と #10（SKUデータ）** は #3 が終われば、#4/#5 の店舗表示実装と並行できる。
3. 設置操作 #6 と見た目 #9、経営処理 #11 はデータ契約と参照/更新APIで接続。共通ファイルの無断並行編集を避ける。
4. 顧客行動 #15 と会計 #17 は境界を分離し、販売成立イベント/予約解放を先に取り決める。
5. #20 の保存設計は早期にスキーマを合意し、結合は M4。#25 のQAは最後に一括着手せず各Issueごとにテストを実施。

## 依存関係と担当レーン

レーン: core=データ基盤、view=配置・画面、art=アセット、economy=商品・会計、sim=顧客、qa=品質。独立ワークツリーは可能だが同一スキーマの同時無調整変更は禁止。

### M0 — 開発基盤・店舗表示

- [ ] **M0-01** [#2 Godot 4基盤/ローカルテスト](https://github.com/yn217/Convenience_store_Sim/issues/2) — 依存: なし / lane: core
- [ ] **M0-02** [#3 スキーマ/入力検証](https://github.com/yn217/Convenience_store_Sim/issues/3) — 依存: #2 / lane: core
- [ ] **M0-03** [#4 アイソメトリック投影](https://github.com/yn217/Convenience_store_Sim/issues/4) — 依存: #2, #3 / lane: view
- [ ] **M0-04** [#5 店舗シェル/操作/HUD](https://github.com/yn217/Convenience_store_Sim/issues/5) — 依存: #4 / lane: view

### M1 — 店舗配置・基本3D→2Dアート

- [ ] **M1-01** [#6 什器配置/回転/撤去/Undo](https://github.com/yn217/Convenience_store_Sim/issues/6) — 依存: #3, #4, #5 / lane: view
- [ ] **M1-02** [#7 アクセス面/到達経路](https://github.com/yn217/Convenience_store_Sim/issues/7) — 依存: #6 / lane: core
- [ ] **M1-03** [#8 Blenderスプライト生成](https://github.com/yn217/Convenience_store_Sim/issues/8) — 依存: #3 / lane: art
- [ ] **M1-04** [#9 基準什器3種](https://github.com/yn217/Convenience_store_Sim/issues/9) — 依存: #6, #8 / lane: art

- [ ] **M1-05** [#26 什器/商品/ガラスの描画合成と重なり順](https://github.com/yn217/Convenience_store_Sim/issues/26) — 依存: #4, #8, #9, #12 / lane: view

### M2 — 商品・在庫・パッケージ

- [ ] **M2-01** [#10 8カテゴリ×3SKU/値付け](https://github.com/yn217/Convenience_store_Sim/issues/10) — 依存: #3 / lane: economy
- [ ] **M2-02** [#11 仕入/バックヤード/補充](https://github.com/yn217/Convenience_store_Sim/issues/11) — 依存: #6, #10 / lane: economy
- [ ] **M2-03** [#12 架空商品画像/在庫LOD](https://github.com/yn217/Convenience_store_Sim/issues/12) — 依存: #8, #9, #10, #11 / lane: art
- [ ] **M2-04** [#13 期限/廃棄](https://github.com/yn217/Convenience_store_Sim/issues/13) — 依存: #11 / lane: economy

### M3 — 顧客行動・会計

- [ ] **M3-01** [#14 ゲーム時計/来店生成](https://github.com/yn217/Convenience_store_Sim/issues/14) — 依存: #2, #10 / lane: sim
- [ ] **M3-02** [#15 客の行動/買物/経路](https://github.com/yn217/Convenience_store_Sim/issues/15) — 依存: #7, #11, #14 / lane: sim
- [ ] **M3-03** [#16 レジ行列/離脱](https://github.com/yn217/Convenience_store_Sim/issues/16) — 依存: #7, #15 / lane: sim
- [ ] **M3-04** [#17 売上/原価/現金台帳](https://github.com/yn217/Convenience_store_Sim/issues/17) — 依存: #11, #16 / lane: economy

- [ ] **M3-05** [#27 価格弾力性・品揃え・評判による購買需要](https://github.com/yn217/Convenience_store_Sim/issues/27) — 依存: #10, #14, #15, #17 / lane: sim

### M4 — 経営UI・広告・保存

- [ ] **M4-01** [#18 広告費/来店倍率](https://github.com/yn217/Convenience_store_Sim/issues/18) — 依存: #14, #17 / lane: economy
- [ ] **M4-02** [#19 日次レポート/経営画面](https://github.com/yn217/Convenience_store_Sim/issues/19) — 依存: #13, #17, #18 / lane: economy
- [ ] **M4-03** [#20 セーブ/ロード](https://github.com/yn217/Convenience_store_Sim/issues/20) — 依存: #3, #6, #11, #17, #18 / lane: core
- [ ] **M4-04** [#21 建設/仕入/インスペクタ/HUD](https://github.com/yn217/Convenience_store_Sim/issues/21) — 依存: #6, #11, #14, #19 / lane: view

- [ ] **M4-05** [#28 初回プレイ導線・営業開始条件・経営目標](https://github.com/yn217/Convenience_store_Sim/issues/28) — 依存: #6, #7, #11, #14, #17, #21 / lane: view

- [ ] **M4-06** [#32 店長アシスタント・成長実績・日替わりチャレンジ](https://github.com/yn217/Convenience_store_Sim/issues/32) — 依存: #17,#19,#20,#21,#28 / lane: view/domain

### M5 — コンテンツ拡張・QA

- [ ] **M5-01** [#22 10種什器アセット](https://github.com/yn217/Convenience_store_Sim/issues/22) — 依存: #8, #9, #12 / lane: art
- [ ] **M5-02** [#23 客4方向アニメ](https://github.com/yn217/Convenience_store_Sim/issues/23) — 依存: #8, #15 / lane: art
- [ ] **M5-03** [#24 情報表示/遮蔽物選択](https://github.com/yn217/Convenience_store_Sim/issues/24) — 依存: #7, #19, #22 / lane: view
- [ ] **M5-04** [#25 統合テスト/性能/配布](https://github.com/yn217/Convenience_store_Sim/issues/25) — 依存: 主要機能 / lane: qa

- [ ] **M5-05** [#29 AI生成素材・Blenderアセットの出典と再配布監査](https://github.com/yn217/Convenience_store_Sim/issues/29) — 依存: #8, #12, #22 / lane: art

- [ ] **M5-06** [#30 リアクション・アニメ・効果音・通知](https://github.com/yn217/Convenience_store_Sim/issues/30) — 依存: #15,#17,#21,#23,#26 / lane: art/view
- [ ] **M5-07** [#31 日替わりイベントディレクター](https://github.com/yn217/Convenience_store_Sim/issues/31) — 依存: #3,#14,#15,#20,#27 / lane: domain

## MVP確認ゲート

- [ ] **G0 表示可能**: 初期店舗がロードされ、投影・パン・ズーム・クリックの整合が確認できる（#2–#5）。
- [ ] **G1 売場が作れる**: 什器3種の配置、回転、重複防止、入口・レジ動線チェックが使える（#6–#9）。
- [ ] **G2 仕入れができる**: 8カテゴリ24SKU、棚補充、在庫容量、廃棄、商品表示が一致（#10–#13）。
- [ ] **G3 売上が立つ**: 来店客が選択/会計/退店し、売上・原価・現金が一致（#14–#17, #27）。
- [ ] **G4 経営できる**: 広告による集客変動、日次損益、セーブ/ロード、操作UIが動く（#18–#21, #28）。
- [ ] **G5 プレイ可能**: 什器10種、客の見た目、オーバーレイ、統合シナリオと配布（#22–#26, #29）。

## テスト・レビューの共通ルール

- 各Issueは完了条件を満たすテストとその実行証跡を残す。実装の内部ロジックをそのまま写すだけのテストで終えず、境界値・不正入力・他機能との統合を確認。
- インタラクションのIssueでは操作シナリオまたは短い動画/スクリーンショット等の証拠を残す。
- 在庫/会計/来店の乱数は固定seedで比較可能にする。負在庫や二重会計を回帰検知。
- 固定ベンチ条件は原則16×12、什器20、客30（正式確定時に仕様更新）。測定環境、実測値、失敗条件を記録。
- GitHub Actionsは使わない。ローカルでUnit/headless/重要画面の手動試験を実施。
- 仕様変更はまず詳細仕様書の差分レビュー→Issue更新→実装。既存の未完了タスクを勝手にclosedにしない。

## マイルストーン横断の設計確認

- [ ] **商品と什器互換性**: 8カテゴリをどの什器で販売できるかが明確
- [ ] **画面と会計分離**: 在庫・現金に書くのはdomain/applicationコマンドのみ
- [ ] **色以外のフィードバック**: 設置不可理由や低在庫を文字/アイコンで表示
- [ ] **4方向アート規格**: 投影・接地・アンカー・影が統一
- [ ] **保存の将来互換**: versionとstable IDを持つ
- [ ] **MVP範囲固定**: 過剰なコンテンツ制作より1日の経営ループを完成


## 仕様レビュー追加（2026-10-22）

- レビュー結果と修正済みの詳細仕様: [SPEC_REVIEW_2026-10-22](SPEC_REVIEW_2026-10-22.md)
- 追加子Issue: #26（2.5D描画合成）、#27（購買需要）、#28（初回プレイ/営業）、#29（素材出典監査）
- **2026-10-22にレビュー済みなのは仕様とIssueのみ**。コード/アセットの品質試験・実装テストは未着手。


## 実装契約 v1.0 とデータ規格

- [実装ベースラインと優先順位](implementation/00_BASELINE_AND_DECISIONS.md)
- [Godot/クラス/API](implementation/01_ENGINE_CONTRACT.md)
- [1tile/画像pixel/アセットサイズの確定規則](implementation/02_GRID_AND_ASSET_CONTRACT.md)
- [経済・顧客・在庫のアルゴリズム](implementation/03_ECONOMY_AND_SIMULATION_CONTRACT.md)
- [画面操作・セーブ・実機QA](implementation/04_UI_SAVE_QA_CONTRACT.md)
- [Codex/Claude向け実装順](implementation/05_IMPLEMENTATION_HANDOFF.md)
- [什器Blueprint/素材規格](implementation/06_ASSET_BLUEPRINTS_AND_VALIDATION.md)
- [JSON Schemaと初期マスタ・校正例](examples/README.md)

### 残りの検証ゲート（ゲーム実装が必要）
- [ ] #3 fixture/product/visual/balance/saveのJSON Schemaと参照・semantic validatorを実装し、seedデータで合格する。
- [ ] #8/9 Blenderの1m校正画像を**実際にレンダリング**してsource X(+128,+64),Y(−128,+64),Z(0,−156.767)の許容誤差を確認。
- [ ] #6/7 1×2 E長辺の2セルアクセス、回転後S側アクセス、アイス四面アクセスをGodotで検証。
- [ ] #22 10種の什器mesh bboxと4方向PNG＋原点anchorの一致を確認。
- [ ] #25 画面シナリオと性能を固定条件で測定。校正・実画像・実測が無い状態でIssueをcloseしない。

仕様段階の静的整合とゲーム実装/実機品質の合格は区別する。**仮画像パスとsample visual manifestは完了アセットではない**。


- [07 実装準備レビュー・未検証項目](implementation/07_SPEC_REVIEW_READINESS.md)


## 2026-10-23 最終契約レビュー
- [08 Runtime State / CommandBus](implementation/08_RUNTIME_STATE_AND_COMMANDS.md) — 営業/時計pause/建設可否、speed0でのコマンド処理。
- [09 Deterministic Simulation / Save](implementation/09_DETERMINISTIC_SIMULATION_AND_SAVE.md) — Godot 4.7.2、固定RNG、価格の購買率効果、セーブ冪等性。
- [10 Test Vectors](implementation/10_TEST_VECTORS_AND_ACCEPTANCE.md) — 具体的入力/期待値。
- [ ] **Review-1**: OPEN+speed0で建設禁止、SETUP+speed0で建設可能。
- [ ] **Review-2**: SAVE→LOAD後も`applied_command_ids`で同じ発注を重複しない。
- [ ] **Review-3**: 価格を上げるとSKU選択だけでなく購買確率が低下する。
- [ ] **Review-4**: 仕様の契約とテストベクトルが実装で一致することを証拠付きで確認。


- [11 2026-10-23 最終レビュー記録](implementation/11_REVIEW_2026_10_23.md)：08〜10の矛盾解消と37件のサンプル構造検証。


## 2026-10-23 再レビューで追加した実装契約
- [12 公開APIと疑似コード](implementation/12_REFERENCE_ALGORITHMS_AND_API.md) — Function別入力/出力、コマンドのatomic commit、配置判定、tick/日次、参照整合。
- [ ] **Gate: atomic OPEN** — 初回開店要求で費用不足なら現金/状態/台帳を変更せず拒否、営業中に次の日付の経費不足ならPAYMENT_BLOCKEDと未払額へ記録。
- [ ] **Gate: build access** — 1×2 E長辺を回転変換し、販売アクセスタイル0の棚配置は拒否。
- [ ] **Gate: deterministic replay** — 固定seedと同tickで在庫/顧客/売上が一致。


## UIモックアップ・ディレクトリ設計（2026-10-23）

- **作成済み**: [通常営業](design/mockups/01_store_overview.svg)、[配置](design/mockups/02_layout_editor.svg)、[商品・在庫](design/mockups/03_inventory_management.svg)、[日次決算](design/mockups/04_daily_report.svg) のSVGモックアップ。
- **作成済み**: [実装ディレクトリ設計](design/PROJECT_DIRECTORY_STRUCTURE.md)、[UI設計ルール](design/UI_DESIGN_TOKENS.md)、[モックアップ運用](design/mockups/README.md)。実装ファイルは未生成。
- [ ] #5/#21: SVG構図をGodot SceneTree/Containersへ翻訳し、1920×1080/1280×720で入力の漏れ・被さり・文字切れを検証。
- [ ] #6/#7: レイアウトモックアップのゴースト・占有・front accessをDomainグリッド検証と一致させる。
- [ ] #10/#11/#21: 24SKUの正本マスタに接続し、棚/バックヤード/売価の情報を正しく表示。
- [ ] #19: レポート画面のデータを会計台帳と連動させ、現金/粗利/経費を混同しない。
- [ ] #8/#9/#22: 什器アセットの実PNGはBlenderで同一縮尺・4方向・接地アンカー校正を通すまで仮画像扱い。


## ゲーム演出・日替わりイベント仕様（2026-10-23）

**設計・データのみ登録完了**。ゲーム実装や演出素材は未制作。

- [13 EventDirector / GameplayEvent 12件](implementation/13_EVENT_DIRECTOR_AND_GAMEPLAY_EVENTS.md)
- [14 Animation / Audio / VFX / PresentationCue 15件](implementation/14_ANIMATION_AUDIO_VFX_CONTRACT.md)
- [15 Tutorial / Story / Milestone 12件 / 日次目標3種](implementation/15_PROGRESSION_STORY_AND_SCENARIOS.md)
- [16 イベント・演出・進行の受入テストと素材一覧](implementation/16_EVENT_QA_AND_ASSET_CHECKLIST.md)
- [日替わりイベントJSON](examples/mvp_v1.gameplay_events.json) / [演出Cue JSON](examples/mvp_v1.presentation_cues.json) / [実績JSON](examples/mvp_v1.milestones.json)
- [ ] #31 DAY1以降一日1回イベント抽選、倍率/カテゴリ効果、セーブ・ロード、独立LCG32を実装。
- [ ] #30 来店/販売/売切れ/行列/廃棄/日次/称号の演出、BGM/SFX、控えめなVFXを作成・接続。
- [ ] #32 tut_01〜08、12実績、3種のデイリーチャレンジとゲーム内案内を実装。
- [ ] #3/#20 JSON Schemaと保存状態の新規必須フィールドをランタイムで検証。
- [ ] #25 [EV-01〜EV-24](implementation/16_EVENT_QA_AND_ASSET_CHECKLIST.md)を実行し、イベント中/通常時のFPS・プレイ体験を報告。
