# 生成プロンプト・出典記録

## 共通情報

- 対象: Issue #12（架空商品パッケージ候補）、連携先 Issue #91（棚状態素材の商品カテゴリ表現）
- SKU / shape: `onigiri_triangle` / 昆布おにぎり
- 寸法正本: 0.105 × 0.045 × 0.095 m（W × D × H）
- ツール: OpenAI Built-in ImageGen（画像生成ツール）
- 生成日: 2026-10-24
- 指定出力: 縦長 1024 × 1536 px、背景不透明、PNG
- モデル版: ツール応答に明示されず（未記録）
- 編集: 生成後の画像加工なし。ファイルを指定名へコピーしたのみ。
- ライセンス: 生成サービスの利用条件、商用利用・リポジトリ再配布条件は未レビュー。承認待ち。
- 承認: `runtime_approved: false`。Godot実画面、UV適用後の見え方、法務/商用利用レビューは未実施。
- 文字・商標: 文字、疑似文字、実在ブランド、ロゴ、バーコード等を生成しないよう指定。目視では明確な文字・ロゴは確認されず。

## `front_art_a.png`

黒海苔色・米の生成り色・控えめな朱色。中央下部に大きなおにぎりと昆布を置き、上部に余白を残す構図。

- SHA-256: `FC1F4D4FD95CEB8E388E5EA9B5E129933C23DC2E5C3EC7AFE1CB9F5C7A19E672`

Prompt (submitted):

> Use case: product-mockup. Asset type: flat 2D front label artwork texture for a fictional Japanese convenience-store kombu onigiri; UV source for one face of a triangular wrapped rice-ball model. Primary request: portrait 1024×1536 premium Japanese commercial food-print design. Design A: dominant deep charcoal-black and warm ivory with one restrained vermilion accent. Large appetizing illustration of a triangular rice ball with dark nori and glossy kombu strands, boldly cropped in the middle/lower area; subtle rice-grain and seaweed textures; refined print hierarchy and safe margins. Scene/backdrop: flat label artwork only, edge-to-edge; no package photo or environment. Style/medium: realistic detailed food illustration embedded in sophisticated Japanese editorial packaging design, tactile paper/ink grain. Composition/framing: front-on orthographic 2D portrait graphic, 2:3; no perspective; strong centered-lower food image and calm upper area. Lighting/mood: warm soft illustrated food highlights, premium and appetizing. Color palette: charcoal black, rice ivory, muted kombu brown-green, small vermilion accent. Text: none. Constraints: absolutely no letters, words, numerals, pseudo-text, glyphs, logos, brands, barcodes, QR codes, character seals, watermarks. No real 3D product, wrapper mockup, store background, plate, hand, or photo scene. Fictional non-branded artwork only; essential motif readable small.

## `front_art_b.png`

青磁色・クリーム色・深緑・控えめな古金色。昆布の葉の流れを使った非対称な斜め構図。

- SHA-256: `A0F21B3B3B1B82672E6467F77080CF1A1398ED30CEBCCF45A9F07DA59A8A37DB`

Prompt (submitted):

> Use case: product-mockup. Asset type: flat 2D front label artwork texture for a fictional Japanese convenience-store kombu onigiri; UV source for one face of a triangular wrapped rice-ball model. Primary request: portrait 1024×1536 premium Japanese commercial food-print design. Design B, intentionally different from dark charcoal/ivory/red: pale celadon and cream base, deep forest-green and muted antique-gold accents, diagonal asymmetrical composition. A medium-scale triangular onigiri with dark nori and kombu strands sits slightly right of center; elegant flowing kombu-leaf motif and sparse rice-grain texture; polished premium print craft. Scene/backdrop: flat label artwork only, edge-to-edge; no package photo or environment. Style/medium: realistic detailed food illustration within refined contemporary Japanese editorial packaging, tactile paper/ink grain. Composition/framing: front-on orthographic 2D portrait graphic, 2:3; visibly different asymmetrical diagonal layout, generous safe margins. Lighting/mood: soft fresh highlights, calm and appetizing. Color palette: pale celadon, cream, forest green, muted gold, rice white. Text: none. Constraints: absolutely no letters, words, numerals, pseudo-text, glyphs, logos, brands, barcodes, QR codes, character seals, watermarks. No real 3D product, wrapper mockup, store background, plate, hand, or photo scene. Fictional non-branded artwork only; essential motif readable small.

## 目視・確認メモ

- 両画像を目視し、平面ラベルとしての構成、昆布おにぎりの識別性、A/Bの配色・構図差を確認。
- 本確認は候補画像の目視に限る。寸法適合、UV歪み、印刷シミュレーション、縮小ゲーム内可読性、法務/商用利用、Godot本番表示の承認を意味しない。
