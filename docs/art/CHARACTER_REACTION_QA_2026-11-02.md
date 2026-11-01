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
| `reaction_045` | 配置表は`daily_profit_positive`。喜びは強いが、上半身へ寄る強い遠近法で標準リアクション枠に不向き。 | 保留 | 標準枠へは接続しない |
| `reaction_049` | うるうる目は明確。生成のハート・疑問符吹き出しがあるため、既存の独立記号とは重複する。 | 保留 | 既存パイロット版を使用し、追加接続はしない |
| `reaction_050` | 配置表は`business_started`。成功表情は明確だが、生成された大きな「!?」文字がUI正本と競合する。 | 保留・用途不一致 | 文字を除去した派生画像なしでは未接続 |

## 実装判断

- `reaction_043` は生成吹き出しを除去した派生PNGを作成し、`reaction_milestone_calm` として `story_first_profit` に限定接続した。これはパイロット選定であり、`runtime_approved` の変更ではない。
- `reaction_031` は実画像の意味に合わせて用途を `opening_check_failed` から `story_first_sale` へ修正し、生成エフェクトを除去した `reaction_first_sale_joy` として限定接続した。これはパイロット選定であり、`runtime_approved` の変更ではない。
- その他の上記候補は配置表の提案状態を維持し、`data/presentation/character_visuals_v1.json` へ追加しない。
- 現在の `reaction_discovery` / `reaction_deadpan` / `reaction_pleading` は、画像とGodot独立記号を分離した既存パイロットを継続利用する。
- 追加候補を実装する場合は、生成吹き出し・文字・エフェクトを除去した派生PNGを別パスへ作成し、手指とお団子を再確認してから、専用の論理IDを登録する。
- `runtime_approved=false` と `visual_match=not_yet_verified` は変更しない。

## `reaction_043` パイロット接続確認

BiRefNetで生成吹き出しを除去した派生画像を `assets/runtime/character_pilot/derived_alpha/reaction_milestone_calm.png`
として保存し、`story_first_profit` の専用バストアップ枠へ接続した。1280×720のCLIキャプチャ
`build/character_pilot_first_profit_reaction_1280.png` では、全身立ち絵を非表示にした状態で本リアクションだけが表示され、
既存のセリフ・左メニュー・下部UIを覆わないことを確認した。生成画像内の記号を使わず、Godotの独立記号レイヤーも空のままにしている。

focused test `test_character_visual_pilot.gd`: 4 tests / 291 assertions / 0 failures。これはパイロット接続確認であり、
`runtime_approved:false` と権利確認ゲートは維持する。
