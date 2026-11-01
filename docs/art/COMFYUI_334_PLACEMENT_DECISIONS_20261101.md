# ComfyUI追加334枚：個別実装先の決定（2026-11-01）

対象: Issue #230／`yn217/Convenience_store_Sim`／ソースブランチ `codex/comfyui-review-20261031`（`01ebc16`）。

- **[画像334枚の対応表（CSV）](COMFYUI_334_IMAGE_PLACEMENT_20261101.csv)** — Excel等で並び替え可能。1行=1画像
- **[画像334枚の対応表（JSON）](COMFYUI_334_IMAGE_PLACEMENT_20261101.json)** — 個別の画像ID、原ファイル、seed、ComfyUIプロンプト抜粋、使用画面、表示イベント、UI slot、Script、優先順位
- 今回の334枚 = No.201〜250:50、200set残り:179（emotion42 / live2d49 / product45 / service43）、機能ポーズ:50、バストアップ:50、タイトル:5。既存200set pilot21枚は今回の334に含めない。元画像マニフェスト全体511枚と混同しない

## 決定事項の意味

**すべての画像に用途と表示先を1件ずつ割り当てた**。これは本番採用の承認、表示コード変更、ライセンス確認の完了を意味しない。

- `screen_id`: 既存18画面のID（`SCR-01`〜`SCR-18`の採用済画面ID）または `FUTURE-*`。後者は**未実装の機能ができるまでは表示しない**
- `trigger`: 画面内で画像を出す条件。`SALE_COMMITTED`等のDomainイベントと、`tutorial_question`等の表示専用条件を区別。**表示専用条件はPresentation/read-model側で新設・接続する必要がある。現時点で全triggerがコード実装済みとは扱わない**
- `ui_slot`: 画面内の人物/背景の表示領域。Godotで新設するUI slotもあるため、Script列は**接続責務の予定先**（機能完成の証明ではない）
- `prompt_pose_en`: PNG埋込ComfyUIのポーズ・感情説明。**311枚の取得成功**。残り23枚はGitHub API経由で埋込プロンプトを読めなかった（うちタイトル5枚、他18枚）。これらは番号で表情を推測せず、予備/代替扱いにした
- `priority_role`: 本番採用とは別の**選択計画**。`candidate_primary_for_trigger`（同一画面+trigger+slotの第1候補135）、`candidate_alternate_for_trigger`（他の代替132）、`deferred_not_in_runtime`（未実装機能47）、`reserve_unverified_source`（生成情報未読15）、`provisional_title_primary_unreviewed`（1）、`title_alternative_review_only`（4）。未読プロンプトでも未実装機能ならdeferredに計上されるため、311/23と役割集計は異なる
- **全334枚とも`runtime_approved=false`**。内容を目視して権利監査を済ませるまでは既存画像へフォールバックする

## どこに出すか：配置と表示の具体的な契約

|UI slot|採用画面・表示領域|初期実装の寸法・制約|
|---|---|---|
|`assistant_corner`|SCR-01/06/09/10などの左下案内役（現行ProgressionControllerと統合）|現行立ち絵**300×436px相当**を上限目安にして、脚と髪を切らず画面高さで縮小。既存の会話吹き出し・HUDと衝突しない。建設パレット/ManagementWindow表示中は抑制|
|`assistant_reaction` / `tutorial_reaction_portrait`|SCR-01の重要通知、SCR-06の質問/成功、SCR-14の支払不能|**256×256px程度**のバストアップ、最大同時1件。❗❓・文字・数値は別Godotレイヤー、2.5秒目安または明示閉じる、連打・長時間占有なし|
|`management_panel_assistant`|SCR-03/07/08/17の商品・発注・補充・広告など|既存パネル内の補助イラスト。**180×260pxを上限目安**、数値・SKU・確定ボタンの領域を削らない。パネルを開いた時だけロード|
|`product_panel_assistant`|SCR-03 商品カテゴリ選択時の小春＋商品|カテゴリ一致候補のみ。実SKUの画像ではなく**販促説明用画像**として表示。未登録商品・実在商品包装が写る候補は実装保留|
|`event_assistant_portrait` / `event_reaction_portrait`|SCR-11 選択済み日替わりイベント詳細|現行`EventController`画像384×216とぶつからない独立の人物枠。CGにすでに小春がいれば人物追加を抑制|
|`achievement_assistant`|SCR-12／SCR-18 実績解除|既存達成Cueに同期した短時間の立ち絵。獲得したバッジ以外の架空報酬は表示しない|
|`dayend_assistant`|SCR-13 日末振り返り|売上・利益・廃棄等のSnapshotに従うポーズ。黒字と赤字を逆にしない|
|`title_background`|SCR-05 タイトル背景|候補`rikka_title_01`を**仮の第1候補**とし、2〜5は代替。文字・ロゴ・ボタンはGodot実UIのまま。CG内に小春がいる場合`title_rikka.png`を非表示にして二重人物を防ぐ。元画像の比率から安全な16:9 cropを実機確認|

これらの値は1920×1080の基準レイアウトに対する**実装目標**。1600×900と1280×720では実際のUI/立ち絵を縮小・配置変更する。クリックを塞ぐ透明なフルスクリーンControlを新設しない（`MOUSE_FILTER_IGNORE`、モーダル専用層を尊重）。

## 画像群別の決定例（全行はCSV参照）

|画像ID|画面|トリガー|割り当て内容|
|---|---|---|---|
|`rikka_fun_001`|SCR-06|`tut_01`|初回コンビニ経営のご案内|
|`rikka_fun_002`|SCR-06|`tut_02`|レジ設置の説明|
|`rikka_fun_004`|SCR-07|`tut_04`|仕入れ発注を教える|
|`rikka_fun_006`|SCR-08|`tut_05`|棚補充を説明|
|`rikka_fun_008`|SCR-01|`BUSINESS_STARTED`|開店のカットイン|
|`rikka_fun_009`|SCR-12|`ms_first_sale`|初売上の喜び|
|`rikka_fun_023`|SCR-01|`STOCK_LOW`|在庫不足への注意|
|`rikka_fun_026`|SCR-01|`QUEUE_TOO_LONG`|行列への不安|
|`rikka_fun_033`|SCR-18|`challenge_sales_3_completed`|当日3件売上達成|
|`rikka_fun_035`|SCR-18|`challenge_no_waste_completed`|廃棄ゼロ達成|
|`rikka_fun_050`|FUTURE-MAP|`map_location_selection`|新規出店候補の案内（機能確認まで保留）|
|`rikka_pose_229`|SCR-10|`CLOSING`|鍵を持つ閉店演出|
|`rikka_pose_234`|SCR-12|`customers_milestone`|来客記録の喜び|
|`rikka_react_002`|SCR-06|`tutorial_question`|❓の質問リアクション|
|`rikka_react_023`|SCR-01|`STOCK_LOW`|在庫警告リアクション|
|`rikka_react_027`|SCR-04|`daily_profit_negative`|赤字を示す下降矢印|
|`rikka_react_029`|SCR-12|`MILESTONE_REACHED`|実績の達成|
|`rikka_service_26`|FUTURE-SERVICE|`receipt_handover`|レシート受け渡し用。現状は予備|
|`rikka_product_02`|SCR-03|`product_category_selected:rice_ball`|おにぎり商品紹介|
|`rikka_product_49`|FUTURE-CAPSULE|`capsule_toy_panel_open`|カプセルトイ紹介用、実装確認待ち|
|`rikka_live2d_01`|SCR-01|`assistant_idle`|正面待機姿勢の**静止画**。Live2Dの動作素材完成を意味しない|
|`rikka_title_01`|SCR-05|`title_scene_ready`|昼間のタイトル背景・仮第1候補|

### まず採用確認するパイロット
`rikka_fun_001/008/009`、`rikka_pose_201/229/234`、`rikka_react_001/002/029`、`rikka_title_01` の**今回334枚から10枚**。加えて既存レビューセットのイベントCG1枚（今回334には数えない）を使い、既存Issue #230の11画像受入チェックを実施する。

## Codex/Claudeへの実装順序とリリースゲート
1. **原本は保持**し、候補のプレビューと派生PNGを作成。数値ボタン・実績ID・販売価格・文字はGodot UIから描画。製品画像は実SKUと一致する場合だけ採用
2. 全身PNGは白背景を綺麗にRGBA化。旧`cutout_rikka_stand.py`の**下部フェード処理をそのまま適用しない**。足元・お団子・指先と接地を保持
3. `data/presentation/character_visuals_v1.json`等に**承認済み**の `trigger → asset_id → transformed path` を少数から導入。業務ロジック・経済状態・既存セーブ形式は変更しない
4. 通知優先順位：支払不能 > 日末/実績 > イベント > 在庫/行列 > 通常会話。複数同時立ち絵・tickごと変化・連続ポップアップ禁止。x1/x2/x4やモーダル表示でも読みやすく
5. PNGプロンプト未読23件は、**ローカル原画像/PNG metadataの読み取りと目視検査で補完する**。タイトル5枚は画像比較して本採用1枚を選び直してよいが、その時は対応表に理由を記す
6. `ASSET_CREDITS.md`/#29のライセンス・小春六花の利用条件・LoRAモデル元・再配布・商標チェック、画面3解像度QA、メモリ/ロード/フレーム実測、既存テスト。**本番採用はユーザー承認後**。未承認画像は通常ビルドに混ぜない

現時点では**全334枚が割り当て済み（計画）／本番採用0枚／視覚QA未完**。元画像を334枚いっせいにロード・実装する指示ではない。
