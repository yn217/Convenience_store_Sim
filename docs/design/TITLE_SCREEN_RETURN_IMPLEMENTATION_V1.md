# タイトル画面とゲーム中からのタイトル復帰 — UI / アセット実装 v1

2026-10-30 / Draft / `feature/title-screen-assets-return-20261030`

## 適用範囲
- Godot `project.godot` の起動先 `res://scenes/title/Title.tscn` は従来どおり。
- 新しい`assets/ui/title/title_background.svg`は日本のコンビニ外観と夕景の**UIなしの背景**。`title_logo.svg`は別レイヤーで、ラベルはGodot実ボタン。テクスチャは画面比率に合わせてCover拡大し、クリック領域に用いない。
- ChatGPTの高詳細画像生成を使ったコンセプトシートは**確認用アート**。パネルやボタンが描き込まれた画像をそのままゲーム背景に使わない。PNG差し替え時も`TitleScreen`のイベントを維持する。
- 日本語文字の描画は、環境に応じたフォントの取り込みで確認（SVGロゴが正常表示されない場合はGodot Labelで代替）。実機で1280×720/1600×900/1920×1080を確認。

## タイトル操作
- `新規ゲーム` → `AppRoot.start_slot=""` → `Main.tscn`。既存セーブを削除・上書きしない。
- `続きから` → `SaveStore.latest_slot`。セーブ無しはdisabled。破損セーブは既存ロード失敗処理に従う。
- `設定` → 従来の効果音スイッチを保持。`終了` → ゲーム終了。
- タイトル画面に表示するボタンはGodot Controlで構成し、背景PNG/SVGへ文字を焼き込まない。

## ゲーム中 → タイトルへ戻る
- `経営管理 > 設定 > タイトルに戻る` → `ConfirmationDialog` を開く。保存なしの状態消失を明記。
- 確認中はSceneTreeをpauseする（時計・来店客・販売を止める）。`state.speed_setting` / `state.revision` を変更しない。
- `キャンセル` → pause解除、従来speed（x1/x2/x4）と状態のままゲーム続行。
- `保存して戻る` → 既存の最新セーブスロット、無い場合`slot_1`へ`AppRoot.run_command(SAVE_GAME)`。**上書きするスロット名をダイアログへ明記**。成功した場合のみscene遷移、失敗した場合はゲームに残る。
- `保存せず戻る` → 確認を経てscene遷移。既存セーブファイルは消さない。保存していないメモリ上の進行のみ失う。
- scene遷移時はSceneTree pause解除・`AppRoot.start_slot=""`、タイトルの`続きから`有効判定は保存済みスロットを再読込。UIモード・顧客選択・ループ参照が旧sceneへ残らないようControllerはMainの子。
- Escによる閉じる・OSウィンドウ閉じる・セーブエラーなどの異常終了についてもゲームpauseのまま残さない。

## 完了条件 / 未実施
- [x] 実画像とUIを別層にするタイトル画面実装
- [x] 設定タブからタイトルへ戻るボタン/確認/選択肢のコード
- [x] モーダルpauseとキャンセル時speed保持の自動テスト追加
- [ ] Godot 4.7.2のヘッドレス自動テスト **未実行**（作業環境にGodot実行体なし）
- [ ] 保存して戻る/保存失敗/保存せず戻るの実機scene切替をテスト
- [ ] 日本語SVGロゴ、背景のクロッピング、各画面解像度の見た目QA
- [ ] サウンド・操作フォーカス・キーボード/Esc、2回押下のデバウンス確認
- [ ] ユーザーのタイトル画面アート承認。Draft PR維持、main未マージ。

## テスト
`godot --headless --path . --script res://tests/run_all.gd -- --only=title`

旧 `test_title_screen.gd` と新 `test_title_return.gd` が対象。scene切替のE2Eは別途Godotの実UIで検証する。

関連: `docs/design/mockups/05_title_new_game.svg`, `docs/implementation/04_UI_SAVE_QA_CONTRACT.md`, Issue #28。
