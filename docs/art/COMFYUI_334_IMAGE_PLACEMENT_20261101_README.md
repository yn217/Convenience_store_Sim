# ComfyUI追加334枚の実装割り当て仕様（2026-11-01）
対象: [COMFYUI_334_IMAGE_PLACEMENT_20261101.csv](COMFYUI_334_IMAGE_PLACEMENT_20261101.csv) / [COMFYUI_334_IMAGE_PLACEMENT_20261101.json](COMFYUI_334_IMAGE_PLACEMENT_20261101.json)。参照元: `assets/review/imagegen_candidates/20261031/issue30_31_32_comfyui/generation_manifest.json`。

CSVが人間編集用の正本で、JSONは `python tools/assets/export_comfyui_334_placement.py` で再生成する。JSONの`runtime_approved`は常に`false`で、配置提案とランタイム採用承認を分離する。
## 意思決定
CSVは追加334画像を**漏れなく**対応付けた、ゲーム側の画面・状態・UI枠の実装割り当て表である。これは一括ランタイム採用承認ではない。PNGごとのポーズを示すComfyUI埋め込みpromptおよび実画像との照合は未完了であり、`visual_match=not_yet_verified` を維持する。生成番号・Seedで意味を推定しない。候補画像と用途が一致しない場合は該当行の画面・条件を修正する。誤ったポーズを無理に使わない。

## 各画像セットの採用規則
- `title`: 5枚をSCR-05の背景候補とし、1番を**第一比較候補**に指定、残り4枚は代替候補。人物が背景に描かれていれば `title_rikka.png` の二重表示を禁止。タイトルロゴと操作ボタンは現行GodotのControl。
- `functional`: チュートリアル8段、日替イベント、開店、初会計、日末、支払不能、実績、在庫警告などの明確な状態に割り当てる。実際の姿勢に合わない画像は候補入れ替え。
- `reaction`: 特定の通知・イベントに対するバストアップ差分。主役は状態説明であり、数字・❗・❓・セリフは別のUIレイヤー。出し過ぎを避ける。
- `remaining/service`: 接客・操作案内、`emotion`: 利益/実績/失敗、`product`: 商品・在庫・発注/補充、`live2d`: リグなし静止画候補。**Live2Dエンジンの自動導入は禁止**。
- `additional`: 会話・チュートリアルの差分用。状態が合うものを選び、類似素材を各イベントへ無理に表示しない。

## 表の読み方と実装仕様
- `screen_id`: 正本`docs/design/SCREEN_SPECIFICATIONS_V1.md`のSCR番号。
- `controller`: 現存する表示Controllerの責務。すべてに新Sceneを作る意味ではない。`ProgressionController`にキャラクター描画を集中、`EventController`は確定イベント状態をread-only描画。`TitleScreen`はタイトル背景用。
- `trigger_id`: **表示判定へ接続する論理識別子**。一部は提案用のvirtual ID（例 `construction_help`）でありDomain eventとして新規存在するとは限らない。既存イベントの単語と名前が違うものは`data/presentation`層で正規化・照合する。該当イベントが存在しない場合は表示しない。
- `display_policy`: tutorial/once/daily/cooldown/contextual/manual/event/startup等。表示時間は最低限にし、既存の優先順位`PAYMENT_BLOCKED > DAILY_CLOSED > MILESTONE_REACHED > EVENT > warning`とミュート/reduce_motionを尊重する。
- `implementation_priority`: P1先行、P2二次、P3予備。P1でも`runtime_approved`にはならない。
- `approval_state`: proposed/proposed_variant/proposed_static_only/alternate_not_runtime。いずれも**商用・公開ビルド採用の承認ではない**。最終的な承認には画像とプロンプトの照合、権利監査、透過処理・安全な表示QAが必要。
- `fallback`: 新候補が未承認/欠損なら現在のタイトル画像・人物画像・イベント画像へ戻す。
- 同じ表示条件に複数候補がある場合、**一度に1枚だけ選択**し、他はバリエーションプールとして保持。ランダムに複数枚を連打しない。
- タイトル以外の白背景画像は`tools/assets/cutout_rikka_stand.py`の下部フェードで足が欠けないよう、全身/バストアップで別処理を用意する。

## 実装する順番
1. CSV対応表を読み込む静的検証（334行、一意asset ID、実ファイル有無、group内件数）。
2. 全334件からPNGのComfyUI埋め込みpromptを抽出し、実際のポーズ・目・手・表情を個別レビュー。**この未実施の工程が現状の主要な残務**。用途が合わない行は修正。
3. 最初にSCR-05背景1、SCR-06全身3、SCR-12/13バストアップ3、機能別3、イベントCG1の実画面差し替えをパイロット。表示領域の衝突、人物二重、GPUメモリ、起動速度を実測。
4. 商品のカテゴリや店員の実装有無と整合させP2/P3候補を選別。キャラを客の4方向移動スプライトに流用しない。
5. 出典・小春六花/LoRA利用条件と`runtime_approved`を確認。報告・PR承認後、商用ランタイムへ取り込む。

## 受入
CSVに334画像のファイルIDと実装先が存在することと、「334画像の実物と指定用途が一致する」ことは**別の受入ゲート**である。本ドキュメント登録では後者は未合格。
