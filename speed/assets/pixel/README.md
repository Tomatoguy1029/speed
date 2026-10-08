# ピクセル素材（2026-10-08）

ユーザー提供の敵のコンセプト画像を参照し、組み込みimagegenで透過アトラス `source-atlas.png` を制作した。素材は試遊用に採用。敵のステータス・半径・行動は既存 `.tres` のまま。

アトラスから `tools/prepare_pixel_assets.gd` で透過範囲を切り出し、Nearestで小さなPNGに整えている。生成画像の3段目は均等セルを越えるため、スクリプトに実際の切り出し境界を記録した。ランタイムは個別PNGを通常のTexture2Dとして読む。元アトラスのファイル読み込みは準備ツールだけで使う。

| 1段目 | 2段目 | 3段目 | 4段目 |
|---|---|---|---|
| drifter | splitter | missile | meteor_1 |
| swarm | splitling | battleship | moon |
| darter | leech | titan | planet |
| armored | gunner | meteor_0 | airship |

各列はアトラスの段を表し、上から左→右の順。敵と自機は下向き。描画時にゲーム内の向きへ回転する。敵の長辺は半径の2倍で、透明な余白によって種類間のサイズ比が変わらない。月と惑星は障害物の直径へ合わせる。背面弱点・HP・予告・エリート表示は素材と別に重ねる。個別アニメーションはまだない。

```powershell
godot --headless --path speed --script res://tools/prepare_pixel_assets.gd
godot --headless --path speed --editor --import --quit
godot --path speed res://tools/preview_pixel_assets.tscn
```

最後のコマンドへ `-- --capture` を付けると、数フレームの静止描画後に `speed/.godot/pixel-preview.png` を保存して終了する。自動プレイではなく、実Rendererで全素材・被弾フラッシュ・弱点とHPを確認するシーン。

通常のF5実行に設定変更は不要。Godot 4.6のこの環境のDirect3D 12では既存GPU火花のパイプライン生成が失敗するため、D3D12では既存CPU火花を使う。Vulkanの経路は変更しない。

生成プロンプト全文は [generation-prompt.txt](generation-prompt.txt)。
