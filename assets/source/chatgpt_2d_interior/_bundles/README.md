# ChatGPT店内アセット ZIP（2026-10-29）

各ZIPはゲーム用の**配布用コンパクトパック**です。元の1536×1024 PNG原画は、各アセットのGitHubソースフォルダに**別途保管済み**です。元画像を削除・上書きしていません。

ZIP内には縮小PNG、manifest.json、README.mdを含みます。サンドイッチ・おにぎり・デザートのZIPにはさらに高解像度WebPが含まれます。**弁当にはWebPがなく、原寸PNGはソースフォルダから取得**してください。

GitHub APIの大容量アップロード制約に対処するため、既存の各数MBのZIPそのものではなく、素材から再梱包したZIP（STORE形式）をコミットしています。内容は用途別に揃え、サイズ違いの画像と正規原画を混同しません。

| ZIP | ファイルサイズ | 元の高解像度PNG |
| --- | ---: | --- |
| [sandwich_case_compact_20261029.zip](sandwich_case_compact_20261029.zip) | 1.25 MB | [source_original.png](../fridge_sandwich_chatgpt_20261029_v1/source_original.png) |
| [bento_case_compact_20261029.zip](bento_case_compact_20261029.zip) | 0.43 MB | [source_original.png](../shelf_bento_refrigerated_chatgpt_20261029_v1/source_original.png) |
| [onigiri_case_compact_20261029.zip](onigiri_case_compact_20261029.zip) | 1.27 MB | [source_original.png](../shelf_onigiri_chatgpt_20261028_v1/source_original.png) |
| [dessert_case_compact_20261029.zip](dessert_case_compact_20261029.zip) | 1.31 MB | [source_original.png](../shelf_dessert_chatgpt_20261029_v1/source_original.png) |

**品質と採用条件**：画像は2D原画候補です。ゲームの `iso2x_v1`・r0正面・world anchor・footprint・alpha輪郭をCodexが実画面で確認するまで `runtime_approved:false` とします。解像度512/256は表示用LODであり、ゲーム内の設備グレード・性能値を意味しません。

## 完全版ZIP（原寸PNGを同梱）

compact ZIPを上書きせず、原寸原画と各アセットフォルダのLOD・manifest・READMEを含む完全版を別途保管します。存在する場合のみ原寸WebPも収録します。PNG/WebPの中身は元ファイルから無変換でコピーしています。

| ZIP | サイズ | 収録内容 |
| --- | ---: | --- |
| [bento_case_full_20261029.zip](full/bento_case_full_20261029.zip) | 3,261,025 bytes | source PNG、preview 512/256、manifest、README |
| [onigiri_case_full_20261029.zip](full/onigiri_case_full_20261029.zip) | 4,371,026 bytes | source PNG、WebP、game 512/256、manifest、README |
| [sandwich_case_full_20261029.zip](full/sandwich_case_full_20261029.zip) | 4,203,160 bytes | source PNG、WebP、game 512/256、manifest、README |
| [dessert_case_full_20261029.zip](full/dessert_case_full_20261029.zip) | 4,404,801 bytes | source PNG、WebP、game 512/256、manifest、README |

各ZIPは`ZipFile.testzip()`で整合を確認し、同梱全ファイルの展開後SHA-256がアセットフォルダ内の元ファイルと一致することを検証しました。完全版ZIPの登録も画像の視覚承認やruntime採用を意味しません。

対象：Draft PR #164 / Issue #163。
