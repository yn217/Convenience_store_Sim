# 日本のコンビニ用おでん3連保温ショーケース（ImageGen原画 / 未承認）

2026-10-29 ChatGPTで日本式おでん具材・仕切り・湯気・値札のある**大型3連ガラスケース**を画像生成した。**最初に要求された小型卓上おでん鍋とは寸法・形式が違うため、別設備候補とする**。既存のパン・冷蔵ケースをおでんとして誤登録しない。

## 画像とZIPの登録状態
原寸1536×1024 PNG、透過補正版PNG、原寸WebP、512px/256px PNG、完全版ZIPは**ChatGPT作業領域内で生成済み**。ただし現在、**GitHubに登録されたのはこの仕様書とREADMEだけ**。実画像バイナリとZIPは未登録なので、「全画像登録完了」と報告してはならない。バイナリの元データが引き渡された段階でアップロードし、manifestのGit blob SHAと厳密照合する。

## Codexへの残作業
1. 画像原画は上書きせず`source_original.png`に登録、cleaned`sprite_fullres.png`を別ファイルで登録。WebP/512/256も個別保存。
2. 6.49MBの完全版ZIPを`assets/source/chatgpt_2d_interior/_bundles/oden_large_3bay_full_bundle_20261029.zip`に登録。
3. `manifest.json`に記載された**実ファイルGit blob SHA**をGitHub上で照合し、GitHubの画像リンクを実際に開く。サイズ検査も行う。
4. 日本の実店舗の角度・商品カテゴリーを確認。3連ショーケースは1×2tileに無理矢理縮小せず、実World投影（`iso2x_v1`）とr0の長辺傾斜・ground anchorからfootprint決定。
5. 商品の価格札は生成された架空の表現として扱い、ゲーム内の正式な価格データに転用しない。
6. 設備の大型グレード（容量/販売力/電力/維持費）は画像LODとは分離して仕様決定。試作の間は`runtime_approved:false`。
7. 別途「**小型おでん鍋1台**」の正規仕様を作成する。大型候補で代替して完了扱いにしない。

関連: #163 #157, Draft PR #164。GitHub `main`未マージ。