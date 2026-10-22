# UI Design Tokens & View-Layer Contract v0.1

## 色・コントラスト（SVGでのスタイル基準、Godot Themeへの移植時は更新）
|Token|Hex|用途|
|---|---|---|
|background|`#0c1724`|アプリ背景|
|panel|`#142638`|メインパネル|
|panelElevated|`#20394e`|テーブル/カード|
|border|`#42617b`|境界|
|brandBlue|`#226092`|選択ナビ/見出し|
|successGreen|`#43c67d`|配置確定/保存|
|infoCyan|`#5caefd`|予測/売上線|
|warningAmber|`#ffc873`|低在庫/費用|
|dangerCoral|`#ee8e8e`|配置不可/損失|
|textPrimary|`#edf5fb`|主要テキスト|
|textSecondary|`#adc4d5`|補助テキスト|

## サイズ・レイアウト
- **実装上の標準解像度1920×1080**。SVGモックアップは1600×900を使うため、視覚構成だけ参照しレイアウト値を直接コピーペーストしない。
- 本番画面のHUD64px、建設パレット280px、右インスペクタ320pxを初期値にする。中央ゲームビューの幅を最低640pxに保持。
- 商品/管理モーダルは中央ゲームビューの上に出し、z-indexを乱用するのでなく**Godot Controlの親子ツリーとinput mouse_filter**を使ってイベントを遮断する。
- 文字目安: HUD主要金額24px、セクション20px、本文14–16px、最小12px。Godot Themeで定義、画面倍率や日本語長文に合わせ再計算。
- 背景店舗は主体。常設UIの不透明領域を極力抑え、パン/ズーム操作がパネルから透過しないようにする。
- 画面の高解像度化はGodot Theme/Control anchors/Containersを使う。絶対座標の不可視Overlayを重ねて領域を作る実装を避ける。

## 表示とロジックの責任分担
- Screenは`read-only GameSnapshot`を描く。`GameCommands`だけが変更権限を持つ。
- 店舗ビューはユニット中心の2.5D描画。背景floor → wall → fixture parts → customer → overlaysを適正なfoot-sortと複数passで合成。
- マスタ画像とHUDアイコン/HTML-like UIモックアップは別アセット種別。商品のcontainer spriteをUIの縮小画像から作らない。
- UIパレットのfixtureカードはtype_idとfootprintを表示し、選択中の回転・アクセス面を文字と矢印で示す。
- 状態別表示: `SETUP`（編集可能）、`OPEN`（営業中）、`CLOSING`（客退店待ち）、`PAYMENT_BLOCKED`（支払不能）の4状態を混同しない。

## 画面別の実装テスト
1. 通常営業: 客30人/什器20基で店舗が操作でき、HUDは売上/現金をリアルタイム更新。
2. レイアウト: グリッド座標/ゴースト/回転時にSpriteの接地がずれない。入口閉塞は設置拒否。
3. 商品/在庫: 24SKUのデータ表示、価格変更の永続化、在庫補充時にslot layerが変化。
4. 決算: 同一台帳から金額を計算し、広告/廃棄を売上原価に二重計上しない。
5. 1920×1080/1280×720の2条件でUIサイズ、選択範囲、スクロール、文字切れを手動確認。
