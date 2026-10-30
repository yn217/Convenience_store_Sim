# Issue #171 屋根なし棚 r0・3状態の制作候補

状態: review_only / runtime_approved:false。EMPTY形状は進行了承済み。FULLとHALF(MEDIUM)は採用前候補。

完成したローカル成果物:
- guide_structure/edges/bbox/mask.png・guide.json: 正本データと投影式から頂点を直接2D投影。
- projection_check.json: GodotのIsoProjectionと96頂点を照合、最大0.000031 source px。生成画像の四隅精度を保証するものではない。
- source_original.png / full_source_original.png / products_only_original.png: 各ImageGenの無加工原画。
- empty_corrected.png: 原画を透明ノイズ除去・等方縮小・平行移動したEMPTY。
- full_composite_candidate.png: 商品領域だけを段ごとに局所変換し、固定EMPTYへ合成。棚全体の非等方変形はしない。
- half_composite_candidate.png: 同一商品レイヤーの陳列を減らしたMEDIUM試作。厳密な在庫50%・SKU別の数量一致ではない。商品境界の独立QAは未完了。
- three_states_comparison.png: 同じ640×640、anchor(380,430)での比較。
- game_*zoom*.png: r0、EMPTY/FULL/HALF、zoom0.5/1/2。一時キャッシュ差替えで撮影。world.zoom_atで床も再描画。初期のズーム再描画不備は修正・撮り直し済み。
- *.candidate.json: 候補用Schemaで実検証。GitHub転送欄false、runtime承認false。

確認範囲: 3状態の素材が存在。保護された可視レール/支柱/台座は画素差0、HALFの商品領域外も画素差0。これは隠れた構造も含めた全画素一致・実在庫同期の合格証明ではない。
未完了: 全制御点、実物/目標参考の独立Visual QA、商品境界の確認、LOW、r1〜r3、人物遮蔽・昼夜・実在庫同期、GitHubバイナリ登録/読戻し。本編定義・保存・経済処理は変更なし。Issueは未完了。

ソース: tools/assets/generate_open_shelf_guide.py、correct_guided_empty.py、compose_guided_stock.py、build_guided_half.py、preview_guided_shelf.gd、package_guided_candidate.py。
過剰なフルテストは実施していない。制作方法: 組み込みImageGen編集＋2Dプログラム合成。プロンプト要旨と各失敗/修正はattemptログに記録。

## 撮影版と納品先の違い
撮影・生成ガイドの元コードは integration/m6-ui の23b840c3d2ca8cadf6046af38ff12e009934bbc1。納品先artブランチの仕様ファイルと同一ではない。入力原本はinput_snapshotに保存。guide.jsonのSHAはその原本を指す。登録先ブランチで再撮影したことにはしない。再生成する場合は入力差分を確認すること。
