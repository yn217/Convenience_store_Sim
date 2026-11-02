# ComfyUI追加334枚の実装割り当て仕様（2026-11-01）
対象: [COMFYUI_334_IMAGE_PLACEMENT_20261101.csv](COMFYUI_334_IMAGE_PLACEMENT_20261101.csv) / [COMFYUI_334_IMAGE_PLACEMENT_20261101.json](COMFYUI_334_IMAGE_PLACEMENT_20261101.json)。参照元: `assets/review/imagegen_candidates/20261031/issue30_31_32_comfyui/generation_manifest.json`。

CSVが人間編集用の正本で、JSONは `python tools/assets/export_comfyui_334_placement.py` で再生成する。JSONの`runtime_approved`は常に`false`で、配置提案とランタイム採用承認を分離する。

## 334件のレビュー用コンタクトシート

全候補を一覧で比較するためのレビュー用画像は [COMFYUI_334_CONTACT_SHEET_20261103.png](COMFYUI_334_CONTACT_SHEET_20261103.png) である。再生成する場合は次を実行する。

```powershell
python tools/assets/build_comfyui_334_contact_sheet.py
```

この画像は視覚確認を補助するだけで、CSV/JSONの`runtime_approved`や個別候補の承認状態を変更しない。採用判断には個別PNG、埋め込みprompt、権利情報、実画面QAを引き続き用いる。

Godotの読み取り専用レビュー画面を候補IDで開く場合は、次のCLIキャプチャを使える。これは通常のMain画面やランタイム台帳を変更しない。

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 --script res://tools/capture_screen.gd -- --placement-review --placement-candidate=additional_001 build/placement_review_additional_001_1280.png
```

`--placement-candidate`を省略すると334件の一覧画面になり、指定すると該当候補だけを選択した状態になる。

Mainの店長アシスタント枠で配置を確認する場合は、`--pilot-candidate`を使う。これはデバッグ用の一時表示で、元画像・通常ランタイム台帳・承認状態を変更しない。

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 --script res://tools/capture_screen.gd -- --pilot-candidate=additional_001 --pilot-cue=opening_checklist --freeze --inspect-pilot build/pilot_candidate_additional_001_1280.png
```

`--pilot-cue`は起動時の非同期Cueに上書きされないよう、検査フレーム後と保存直前に指定値を再適用する。`--inspect-pilot`の出力とPNGが同じ立ち絵を指すことを確認する。
代表4経路を候補オーバーライドなしで確認し、`opening_checklist`→`functional_opening_checklist.png`、`low_stock_notice`→`functional_low_stock.png`、`rival_opened`→`functional_rival_store.png`、`save_complete`→`functional_save_complete.png` が左メニュー直下の同一アシスタント枠へ表示された。

候補の背景除去を比較する場合は、ComfyUIのBiRefNetレビュー処理を指定候補だけに実行できる。出力は`assets/review/derived_alpha/`に保存され、通常ランタイムには接続されない。

```powershell
.\tools\assets\apply_birefnet_review_candidate.ps1 -CandidateId additional_001
```

2026-11-03の試験では`additional_001`を`assets/review/derived_alpha/additional_001.png`へ出力し、`RGBA 1024x1536 / alpha=(0,255)`を確認した。元の候補PNGは変更していない。透過派生を`--pilot-candidate=additional_001`でMainに表示した実画面は`build/pilot_candidate_additional_001_alpha_1280.png`で、白背景は除去されたが、これはまだレビュー専用である。

同日、P1チュートリアル候補`functional_001`も同じ処理で`assets/review/derived_alpha/functional_001.png`へ出力し、Main枠での表示を`build/pilot_candidate_functional_001_alpha_1280.png`で確認した。こちらも通常採用前のレビュー専用である。

続けて`functional_002`〜`functional_008`も透過処理し、7件すべてで`RGBA 1024x1536 / alpha=(0,255)`を確認した。代表`functional_004`のMain配置確認は`build/pilot_candidate_functional_004_alpha_1280.png`である。

さらに`functional_009`〜`functional_016`の8件を処理し、同じRGBA・アルファ条件を確認した。代表`functional_012`のMain配置確認は`build/pilot_candidate_functional_012_alpha_1280.png`である。

続けて`functional_017`〜`functional_024`の8件も透過処理し、全件で同じRGBA・アルファ条件を確認した。代表`functional_024`のMain配置確認は`build/pilot_candidate_functional_024_alpha_1280.png`である。

`functional_025`〜`functional_032`の8件も同様に処理・検査し、代表`functional_032`を`build/pilot_candidate_functional_032_alpha_1280.png`でMain表示確認した。
`functional_033`〜`functional_040`の8件も同様に処理・検査し、代表`functional_040`を`build/pilot_candidate_functional_040_alpha_1280.png`でMain表示確認した。
`functional_041`〜`functional_050`の10件も同様に処理・検査し、代表`functional_050`を`build/pilot_candidate_functional_050_alpha_1280.png`でMain表示確認した。
P1リアクション`reaction_001`〜`reaction_010`も透過処理し、全件`RGBA 1024x1024`・alpha extrema `(0,255)`を確認した。代表`reaction_001`は`build/pilot_candidate_reaction_001_alpha_1280.png`でリアクション表示スロットを確認した。
残りのP1リアクション`reaction_011`〜`reaction_018`も同様に処理・検査し、代表`reaction_013`を`build/pilot_candidate_reaction_013_alpha_1280.png`で確認した。
実ゲームイベントに直結する立ち絵`remaining_001`〜`remaining_010`も透過処理し、全件`RGBA 1024x1536`・alpha extrema `(0,255)`を確認した。代表`remaining_004`は`build/pilot_candidate_remaining_004_alpha_1280.png`でMain表示確認した。
続く`remaining_011`〜`remaining_020`も同様に処理・検査し、代表`remaining_015`を`build/pilot_candidate_remaining_015_alpha_1280.png`でMain表示確認した。
続く`remaining_021`〜`remaining_030`も同様に処理・検査し、代表`remaining_023`を`build/pilot_candidate_remaining_023_alpha_1280.png`でMain表示確認した。
続く`remaining_031`〜`remaining_040`も同様に処理・検査し、代表`remaining_037`を`build/pilot_candidate_remaining_037_alpha_1280.png`でMain表示確認した。
続く`remaining_041`〜`remaining_050`も同様に処理・検査し、代表`remaining_045`を`build/pilot_candidate_remaining_045_alpha_1280.png`でMain表示確認した。
チュートリアル候補`additional_002`〜`additional_011`も透過処理し、全件`RGBA 1024x1536`・alpha extrema `(0,255)`を確認した。代表`additional_008`は`build/pilot_candidate_additional_008_alpha_1280.png`でMain表示確認した。
続くチュートリアル候補`additional_012`〜`additional_021`も同様に処理・検査し、代表`additional_017`を`build/pilot_candidate_additional_017_alpha_1280.png`でMain表示確認した。
続く追加ポーズ候補`additional_022`〜`additional_031`も同様に処理・検査し、代表`additional_028`を`build/pilot_candidate_additional_028_alpha_1280.png`でMain表示確認した。
続く追加ポーズ候補`additional_032`〜`additional_041`も同様に処理・検査し、代表`additional_037`を`build/pilot_candidate_additional_037_alpha_1280.png`でMain表示確認した。
追加ポーズ候補の残り`additional_042`〜`additional_050`も同様に処理・検査し、代表`additional_050`を`build/pilot_candidate_additional_050_alpha_1280.png`でMain表示確認した。これで追加ポーズ50件が揃った。
実ゲームイベント用の立ち絵`remaining_051`〜`remaining_060`も透過処理し、全件`RGBA 1024x1536`・alpha extrema `(0,255)`を確認した。代表`remaining_056`は`build/pilot_candidate_remaining_056_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_061`〜`remaining_070`も同様に処理・検査し、代表`remaining_066`を`build/pilot_candidate_remaining_066_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_071`〜`remaining_080`も同様に処理・検査し、代表`remaining_076`を`build/pilot_candidate_remaining_076_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_081`〜`remaining_090`も同様に処理・検査し、代表`remaining_086`を`build/pilot_candidate_remaining_086_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_091`〜`remaining_100`も同様に処理・検査し、代表`remaining_096`を`build/pilot_candidate_remaining_096_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_101`〜`remaining_110`も同様に処理・検査し、代表`remaining_106`を`build/pilot_candidate_remaining_106_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_111`〜`remaining_120`も同様に処理・検査し、代表`remaining_116`を`build/pilot_candidate_remaining_116_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_121`〜`remaining_130`も同様に処理・検査し、代表`remaining_126`を`build/pilot_candidate_remaining_126_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_131`〜`remaining_140`も同様に処理・検査し、代表`remaining_136`を`build/pilot_candidate_remaining_136_alpha_1280.png`でMain表示確認した。
続く実ゲームイベント用の立ち絵`remaining_141`〜`remaining_179`もBiRefNetで透過処理し、39件すべて`RGBA 1024x1536`・alpha extrema `(0,255)`を確認した。代表`remaining_159`は`build/pilot_candidate_remaining_159_alpha_1280.png`で、左メニュー直下へ寄せたMain表示を確認した。これらは引き続きレビュー専用で、`runtime_approved`と通常レジストリは変更していない。
`python tests/tools/test_character_pilot_assets.py`で、runtime登録済み49件に加えて、`assets/review/derived_alpha/`の加工済み候補が334行対応表・元画像・寸法・RGBA・透明四隅へ追跡でき、`runtime_approved=false`を維持することを検査する。

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
2. `scenes/review/ComfyUIPlacementReview.tscn`の読み取り専用ギャラリーで全334件を検索・グループ別に個別レビューする。画像は選択時だけ読み込み、承認状態は変更しない。
3. 全334件からPNGのComfyUI埋め込みpromptを抽出し、実際のポーズ・目・手・表情を個別レビュー。**この未実施の工程が現状の主要な残務**。用途が合わない行は修正。
4. 最初にSCR-05背景1、SCR-06全身3、SCR-12/13バストアップ3、機能別3、イベントCG1の実画面差し替えをパイロット。表示領域の衝突、人物二重、GPUメモリ、起動速度を実測。
5. 商品のカテゴリや店員の実装有無と整合させP2/P3候補を選別。キャラを客の4方向移動スプライトに流用しない。
6. 出典・小春六花/LoRA利用条件と`runtime_approved`を確認。報告・PR承認後、商用ランタイムへ取り込む。

## 受入
CSVに334画像のファイルIDと実装先が存在することと、「334画像の実物と指定用途が一致する」ことは**別の受入ゲート**である。本ドキュメント登録では後者は未合格。
