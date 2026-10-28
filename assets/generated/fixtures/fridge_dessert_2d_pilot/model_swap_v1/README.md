# fridge_dessert FULL/r0 — model_swap_v1

image_genでケースとデザート商品を一体生成した2案です。入力は指定のcanonical空ケース画像1枚のみ。SKUカタログのカスタードプリン・チーズケーキ・フルーツゼリーを丸いカップ形状と色で描き分けました。

- A: `fridge_dessert_full_r0_a.png` — 棚ごとに商品カテゴリを配置。
- B: `fridge_dessert_full_r0_b.png` — 各段に3カテゴリを色のまとまりで配置。
- 同一縮尺比較: `comparison.png`（左canonical、中央A、右B。格子は比較画像のみ）。
- 原本: `a_raw.png`, `b_raw.png`; B初回の記録: `b_initial_raw.png`。
- 生成文: `prompt_a.txt`, `prompt_b_refined.txt`; 初回B: `prompt_b.txt`。
- 数値QA: `qa_metrics.json`; 目視QA: `qa_visual.json`; 輪郭比較: `qa_overlay_a.png`, `qa_overlay_b.png`。
- SKU・canonical情報: `sku_reference.json`, `canonical_contract.json`; 来歴: `generation_manifest.json`。

どちらもRGBA 442×465px、外周alpha最大値0。Hough長辺角度はcanonical -26.565°に対し、A -26.042°（差+0.523°）、B -24.790°（差+1.775°）。alpha bbox幅はcanonicalと両案で一致。bbox高さはcanonical432pxに対しA424px（-8）、B417px（-15）。A/Bとも一様縮尺だけで収まるよう配置しています。

これらの値は輪郭・線分の診断です。ケース枠、個々の棚板、ガラス扉の寸法とanchorの厳密一致を証明しません。anchorはcanonical値を記録し、画像は下端基準で配置しています。採用前に比較画像で現物の位置関係を確認してください。ゲームテストや実行時の切替は行っていません。

全生成原本・プロンプト・比較・QA値のSHA256一覧は `DELIVERY_SHA256.json` にあります。
