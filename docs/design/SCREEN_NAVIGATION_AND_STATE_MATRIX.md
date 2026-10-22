# 画面遷移・UI状態・入力契約 v1.0
2026-10-23。対象: [全18画面一覧](SCREEN_SPECIFICATIONS_V1.md)。

## 1. UI階層とライフサイクル
```text
TitleScene (SCR-05)
  ├─ NewGame → MainScene / business_state=SETUP, speed0 → tutorial overlay SCR-06
  ├─ Continue → SaveLoadModal SCR-16 → validated GameState → MainScene
  └─ Settings → SettingsTab SCR-16 → TitleScene

MainScene (SCR-01)
  ├─ Build (SETUP only) → SCR-02 → selection/rotation/place → MainScene
  ├─ Inventory → SCR-03 → row/price edit → MainScene
  ├─ Order → SCR-07 Modal → stock purchase → SCR-01
  ├─ Selected Fixture → SCR-08 Modal (SETUP) → restock → MainScene
  ├─ Open (SETUP) → SCR-09 check → START_BUSINESS → OPEN
  ├─ Close (OPEN) → REQUEST_CLOSE → SCR-10 → wait for zero active customers → SETUP
  ├─ Event STARTED (DAY1+) → SCR-11 Banner, optional detail Modal
  ├─ SALE_COMMITTED milestone → SCR-12 cue overlay, optional achievements SCR-18
  ├─ DAILY_CLOSED → SCR-13 notification / report panel SCR-04
  ├─ PAYMENT_BLOCKED → SCR-14 full-screen modal → Load / Title / New
  ├─ Overlay toggle → SCR-15
  ├─ Save/settings → SCR-16
  ├─ Ad budget → SCR-17
  └─ Milestones → SCR-18
```

## 2. ビジネス状態の操作可否
|操作|SETUP|OPEN (speed0でも同じ)|CLOSING|PAYMENT_BLOCKED|
|---|---|---|---|---|
|Build/Move/Remove|可能|不可|不可|不可|
|Order Stock|可能|可能|可能|不可|
|Restock|可能|不可|不可|不可|
|Set Price|可能|可能|可能|不可|
|Set Next Day Ad|可能|可能|可能|不可|
|Start Business|事前検査後可能|不可|不可|不可|
|Request Close|不要|可能|待機表示のみ|不可|
|View Inventory/Reports/Event|可能|可能|可能|履歴参照のみ|
|Save|可能|可能|可能|可能（整合検証後）|
|Load|確認後可能|確認後可能|確認後可能|復旧目的で可能|
|P=Clock Pause|SETUPの0を維持|0/直前の非ゼロ速度|0/直前の非ゼロ速度|0固定|

SETUPではゲーム時計が進まず、注文や棚補充はCommandBusの独立command phaseで処理する。CLOSINGでは**新規来店無し**、客の既存会計は時計に従い進行する。

## 3. modal/cue/inputの優先度
- `TitleScene` > `FullScreenBlockingModal` > `ActionModal` > `ShellPanels` > `StoreViewport`。これはUIの**入力所有権**であって、無闇なz_indexスタックで不可視壁を作る意図ではない。
- ActionModalを開く前にstore selection/drag gestureをキャンセルし、背後StoreViewportへのpointer/kbdイベント伝播を止める。
- 重要通知: PAYMENT_BLOCKED > DAILY_CLOSED > MILESTONE_REACHED > EVENT_STARTED/ENDED > STOCK_LOW/QUEUE警告。通知は同時3件まで、低優先は抑制/履歴へ格納。Domainイベント自体は捨てない。
- TitleのContinueには保存がなければdisabled、GameState無しでMainSceneへ入れない。
- ESC: モーダル→閉じる/編集差分破棄、建設プレビュー→取消、通常画面→休止メニュー。Escape自体で保存/会計/予約を巻き戻さない。
- 補充中にOPENへ移行する競合はmain thread serial CommandBusの最新revisionで再検査して拒否。値段や広告のdraft値も同様。
- 上書きセーブ/ロード/新規ゲーム選択時は必ず未保存進捗破棄を確認する。ただし「保存」ではMVPは3slotのみ。

## 4. 不正状態/空状態
|Screen|状態|見せるテキストと動作|
|---|---|---|
|SCR-05|セーブ無し|「続きから」を無効化、初回新規ゲーム可能|
|SCR-07|資金不足|「所持金が不足しています」、発注コマンドを送らず/失敗を表示|
|SCR-08|棚容量0|「この棚にはこれ以上補充できません」、数量0は確定不可|
|SCR-08|OPEN/CLOSING|「補充には営業終了が必要です」|
|SCR-09|レジ無し|「レジが必要です」、Buildへ誘導|
|SCR-09|棚未補充|「販売できる商品を1点以上陳列してください」|
|SCR-10|最後の客が退出|SETUP/speed0へ確実に遷移|
|SCR-11|イベント無し/期限切れ|通知無し、一覧は「本日はイベント無し」と表示|
|SCR-14|復旧用セーブ無し|ロード選択はdisabled、「新規ゲーム/タイトル」のみ|
|SCR-16|3slot満杯|保存は可能だが上書き確認|
|SCR-16|旧版/破損セーブ|「読み込めません」、元ゲーム不変|
|SCR-17|ティア選択無し|確定disabled、現予算を明示|
|SCR-18|実績未達|未達条件を数値で表示、報酬プレビューはbadge_only|

## 5. 実装分割
- Godot Scenes/Controls: `scenes/main/TitleScreen.tscn`, `scenes/main/Main.tscn`, `scenes/ui/{TutorialOverlay,OrderModal,RestockModal,OpeningChecklist,ClosingStatus,EventBanner,AchievementToast,DailySummary,PaymentBlockedModal,StoreHeatmap,SaveDialog,SettingsPanel,AdvertisingBudgetPanel,MilestonePanel}.tscn`。
- Application: `scripts/application/ui_router.gd` manages one root modal, existing screen, focus restoration, and transition after CommandResult.
- View-model: `scripts/presentation/screen_read_models.gd` maps immutable GameSnapshot to displayed quantities; formatting of yen and dates stays separate from Business logic.
- Tests: `tests/scene/ui_navigation/` at 1920×1080 and 1280×720; `tests/scenario/first_day_flow/`, `tests/scenario/save_recovery/`, `tests/scenario/day1_event/`.
- Do not generate placeholder images that look like finished production fixtures. All runtime visual assets use Blender calibrated `iso2x_v1`.
