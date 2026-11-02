# 小春六花リアクション候補目視QA（2026-11-02）

対象: `assets/review/imagegen_candidates/20261031/issue30_31_32_comfyui/character_reactions_1024x1024/`

この記録は候補の見た目を確認した結果であり、`runtime_approved` を変更するものではない。生成画像に含まれる吹き出し・記号・文字は、ゲームUIの正本として扱わない。

## 確認結果

| 候補 | 確認内容 | 判定 | ランタイム対応 |
|---|---|---|---|
| `reaction_021` | 配置表は`queue_too_long`だが、実画像は双方の親指を立てたチェック反応。制服・お団子は安定し、右上に生成チェック吹き出しが残る。 | 保留・用途不一致 | 行列には接続せず、既存のGodot記号レイヤーとも重複するため未接続 |
| `reaction_022` | 配置表は`access_blocked`だが、実画像は明るい表情と両手の仕草。両手の指輪郭と右上の生成「!」風バルーンを要確認。 | 保留・用途不一致 | 手の再確認・記号除去または非表示処理が必要 |
| `reaction_026` | 表情は明るいが、左右の手の形状・指の接続が不安定。左側に生成吹き出しがある。 | 保留 | 手のInpaintなしでは未接続 |
| `reaction_029` | 片手の仕草と表情は使える可能性があるが、右上の生成アイコンがゲームUIと競合する。 | 保留 | 記号分離後に再判定 |
| `reaction_031` | 配置表は`opening_check_failed`だが、実画像は達成・喜びの表情。両手のガッツポーズとお団子を確認し、BiRefNet派生で左上の生成エフェクトを除去。 | パイロット選定・用途修正 | `story_first_sale` の喜びバストアップへ限定接続。手指・境界・権利確認は継続 |
| `reaction_042` | 配置表は`ms_first_sale`だが、実画像はぐるぐる目の混乱。髪型・衣装は維持するが、右上に生成スパイラルと星がある。 | 保留・用途不一致 | Godot側の独立記号へ置換後に再判定 |
| `reaction_043` | 配置表は`milestone_reached`。BiRefNet派生で右側の生成キャラクター入り吹き出しを除去でき、キャラクター本体・髪型・衣装の粗視認を通過。 | パイロット選定 | `story_first_profit` のクリーンなバストアップ反応へ限定接続。手指・境界・権利確認は継続 |
| `reaction_044` | 配置表は`daily_challenge_completed`だが、実画像はジト目・無表情。右側に生成ミニキャラ吹き出しがある。 | 保留・用途不一致 | `reaction_deadpan`との差分を比較してから判断 |
| `reaction_045` | 配置表は`daily_profit_positive`。喜びは強いが、上半身へ寄る強い遠近法で標準リアクション枠に不向き。BiRefNetの試験派生でも右上の生成星吹き出しが前景成分として残った。 | 保留 | 標準枠へは接続しない。記号除去と構図再評価が必要 |
| `reaction_049` | うるうる目は明確。生成のハート・疑問符吹き出しがあるため、既存の独立記号とは重複する。 | 保留 | 既存パイロット版を使用し、追加接続はしない |
| `reaction_050` | 配置表は`business_started`。成功表情は明確だが、生成された大きな「!?」文字がUI正本と競合する。 | 保留・用途不一致 | 文字を除去した派生画像なしでは未接続 |

## 実装判断

- `reaction_043` は生成吹き出しを除去した派生PNGを作成し、`reaction_milestone_calm` として `story_first_profit` に限定接続した。これはパイロット選定であり、`runtime_approved` の変更ではない。
- `reaction_031` は実画像の意味に合わせて用途を `opening_check_failed` から `story_first_sale` へ修正し、生成エフェクトを除去した `reaction_first_sale_joy` として限定接続した。これはパイロット選定であり、`runtime_approved` の変更ではない。
- `reaction_045` はBiRefNetの透過処理を試したが、生成星吹き出しがキャラクターと同じ前景成分に残ったため、派生PNG・台帳エントリを作らず保留に戻した。
- その他の上記候補は配置表の提案状態を維持し、`data/presentation/character_visuals_v1.json` へ追加しない。
- 現在の `reaction_discovery` / `reaction_deadpan` / `reaction_pleading` は、画像とGodot独立記号を分離した既存パイロットを継続利用する。
- 追加候補を実装する場合は、生成吹き出し・文字・エフェクトを除去した派生PNGを別パスへ作成し、手指とお団子を再確認してから、専用の論理IDを登録する。
- `runtime_approved=false` と `visual_match=not_yet_verified` は変更しない。

## 分離成分の除去（2026-11-02）

`reaction_discovery`、`reaction_deadpan`、`reaction_pleading` は、BiRefNet後のアルファでキャラクター本体から分離した生成吹き出し／記号成分が残ることを確認した。まず `tools/assets/prune_disconnected_alpha.py` を試したが、記号がアルファ上でキャラクターと接続している画像では除去できなかった。そのため、対象3枚の派生PNGだけに `tools/assets/clean_reaction_symbol_regions.py` の明示的な矩形マスクを適用した。元のComfyUI画像と候補画像は変更せず、Godot側の記号レイヤーを引き続き正本とする。`runtime_approved=false` は維持し、再処理後は派生PNGの連結成分検査とマスク領域の透明化検査を行う。

BiRefNetを再実行した場合は、連結成分の除去に加えて、次の明示的な後処理を再度実行する。

```powershell
python tools/assets/prune_disconnected_alpha.py `
  --input assets/runtime/character_pilot/derived_alpha/reaction_discovery.png `
          assets/runtime/character_pilot/derived_alpha/reaction_deadpan.png `
          assets/runtime/character_pilot/derived_alpha/reaction_pleading.png `
  --in-place
```

生成記号がキャラクター本体とアルファ上で接続している場合は、次の3枚だけを対象に明示マスクを適用する。元画像は上書きせず、ランタイム派生PNGのみを更新する。

```powershell
python tools/assets/clean_reaction_symbol_regions.py `
  --input assets/runtime/character_pilot/derived_alpha/reaction_discovery.png `
          assets/runtime/character_pilot/derived_alpha/reaction_deadpan.png `
          assets/runtime/character_pilot/derived_alpha/reaction_pleading.png `
  --in-place
```

マスク領域は `reaction_discovery=(760,0)-(1024,240)`、`reaction_deadpan=(740,0)-(1024,220)`、
`reaction_pleading=(800,0)-(1024,340)`。いずれも髪・お団子・肩・手を避ける範囲に限定している。
元画像の存在確認と派生PNGの対象領域アルファ0検査は `tests/tools/test_character_pilot_assets.py` で行う。

## `reaction_043` パイロット接続確認

BiRefNetで生成吹き出しを除去した派生画像を `assets/runtime/character_pilot/derived_alpha/reaction_milestone_calm.png`
として保存し、`story_first_profit` の専用バストアップ枠へ接続した。1280×720のCLIキャプチャ
`build/character_pilot_first_profit_reaction_1280.png` では、全身立ち絵を非表示にした状態で本リアクションだけが表示され、
既存のセリフ・左メニュー・下部UIを覆わないことを確認した。生成画像内の記号を使わず、Godotの独立記号レイヤーも空のままにしている。

focused test `test_character_visual_pilot.gd`: 4 tests / 291 assertions / 0 failures。これはパイロット接続確認であり、
`runtime_approved:false` と権利確認ゲートは維持する。

## 最新の表示経路確認（2026-11-02）

生成記号の明示マスク適用後、表示経路を再実行した。`character_visual_pilot` は4 tests / 351 assertions / 0 failures、
`event_ui` は4 tests / 51 assertions / 0 failures。メイン画面では全身PNGを上側のバストアップ表示枠へ表示時だけクロップし、
元の1024×1536画像は変更しない。左メニュー右側のアシスタント枠、下寄せした吹き出し、イベント画面のfullbody/reaction分離、
旧アシスタントとの二重表示抑止も維持している。今回の記号除去は `f3474360` で派生PNG3枚だけに適用し、
`runtime_approved:false` と未承認候補のレビュー待ち状態は変更していない。

1920×1080のCLI実画面でも `--pilot-cue=low_stock_notice` を確認した。ログ上は
`pilot_texture=res://assets/runtime/character_pilot/derived_alpha/functional_low_stock.png`、
`pilot_size=(1024,1536)`、`legacy_visible=false`。保存画像は
`build/standing_impl_low_stock_1920_latest.png` にあり、表示時クロップ後の立ち絵が左メニューの右側、
吹き出しがその右側・下寄せに収まり、下部操作UIを覆わないことを目視確認した。

選定済み50件（機能30・イベント11・リアクション5・汎用全身3・タイトル背景1）の確認用一覧は
`build/character_pilot_runtime_contact_20261102.png`。再生成は
`python tools/assets/build_character_pilot_contact_sheet.py` で行える。これは承認状態を変更しないレビュー用出力である。

334候補の読み取り専用レビュー経路も非headless CLIで確認した。`additional_001` は派生透過の全身候補、
`reaction_001` はバストアップ候補として、候補ID・Seed・group・screen/slot・trigger・承認状態を表示した。
確認画像は `build/placement_review_additional_001_alpha_1280_latest.png` と
`build/placement_review_reaction_001_alpha_1280_latest.png`。この経路は `runtime_approved` を変更せず、
候補画像を通常の `Main` ランタイムへ常駐ロードしない。

候補指定による `Main` 実画面確認では、親のアシスタントステージが通常のstory/cue状態に依存して非表示になる不具合を修正した（`a4187673`）。
レビュー候補を指定したときだけステージを表示し、解除時は通常の表示計算へ戻す。`test_character_visual_pilot.gd` は
4 tests / 354 assertions / 0 failures。確認画像は `build/pilot_candidate_additional_001_main_1280_fixed.png` で、
候補の全身元画像は表示時クロップされ、旧アシスタントは非表示、既存UI操作領域は維持される。

同じ `Main` 経路でバストアップ候補 `reaction_001` も確認した。非headless CLIのログは
`stage_visible=true`、`pilot_visible=false`、`pilot_reaction visible=true`、
`texture=res://assets/review/derived_alpha/reaction_001.png`、`size=(1024,1024)`、
`legacy_visible=false` で、リアクション専用レイヤーが表示され、旧アシスタントは非表示だった。
確認画像は `build/pilot_candidate_reaction_001_main_1280_latest.png`。候補は引き続きレビュー専用であり、
生成画像内の吹き出し・記号はゲームUIの正本として扱わず、`runtime_approved:false` も維持する。

## 追加候補の実画像確認（2026-11-02）

334枚コンタクトシートのリアクション候補から、`reaction_004`、`reaction_014`、`reaction_016`、
`reaction_017`、`reaction_020`、`reaction_023`、`reaction_024`、`reaction_027` を派生透過PNGで個別確認した。
いずれもキャラクター本体・お団子・制服は確認できる一方、生成された疑問符・怒り記号・ミニキャラ・
吹き出しが画像内に残っている。手の形状もゲームUIで独立記号を重ねる前提の品質確認を通過していないため、
今回の候補は追加ランタイム接続しない。既存の5リアクションだけをGodot独立記号レイヤーと組み合わせて使用し、
未接続候補と元画像は変更せず、`runtime_approved:false` を維持する。
