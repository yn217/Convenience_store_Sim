# サンドイッチ用冷蔵ケース FULL / 画像バイナリ未登録

2026-10-29、ホットスナック用加温ケースを生成しようとしたところ、画像生成ツールが**サンドイッチ・惣菜パン用の開放型冷蔵ケース**を生成。誤分類しないよう、実際の画像に基づく候補として記録。

**重要：このコミットに画像本体のPNG/WebPは入っていない。** 原画PNG 1536×1024のSHA256プレフィックス`de206b8efcb37f6f`、縮小512px `234e2c5ec3519abb`、256px `8bb582fd74ca304e`。これらのファイル本体はChatGPTの会話内ZIP `sandwich_chilled_case_20261029.zip`にあり、GitHubへの画像バイナリアップロードが未完了。表示確認していない画像へのGitHubリンクを作らないこと。

## Codex への受け入れ条件
- [ ] 元画像 `source_original.png`をハッシュ一致で登録し、512px/256pxと原寸WebPを**同じフォルダ**に格納。SVGの代替画像を元ImageGen原画と偽らない。
- [ ] GitHub上で画像バイナリを再取得し、寸法・SHA256検証後に`github_binary_registered:true`へ変更。
- [ ] 透過背景のフリンジを除去し、ゲーム`iso2x_v1`、`r0`販売面方向、world ground anchorとfootprintを実Godot画像と比較。
- [ ] この素材はホットスナックではなくサンドイッチケースとして扱い、正式採用前は`runtime_approved:false`。
- [ ] 原画・表示LODとゲーム設備の機能/グレードを分離する。

関連 Issue #163、Draft PR #164。
