# SPEED

敵の大群に対して高速移動で立ち向かい、一気に吹き飛ばして圧倒する快感を楽しむ、宇宙を舞台にした2D見下ろしのサバイバーゲーム。

本番ゲームの開発を Godot へ移行しました。ブラウザ版の試作は `demo/` にまとめ、今後も新機能や新スキルを手早く試す実験場として使います。

## Godot で開発する

Godot のプロジェクトは [speed/project.godot](speed/project.godot) です。このリポジトリを `speed/` にクローンした場合、`speed/speed/project.godot` を Godot のプロジェクトマネージャーからインポートしてください。

プロジェクト設定は Godot 4.6・Forward Plus です。タイトル・ステージ選択・ゲーム本体を実装済みで、メインシーンは `scenes/app/main.tscn` です。Godot 4.6 でインポートし、**F5 → ゲームスタート → ステージ選択 → 任意のステージ**で遊べます。エディタからの実行とデバッグ用のビルドでは、全ステージを選べます。調整機能は [仕様書](docs/spec.md#20-調整機能) を参照してください。

開発版のメインメニューにある **敵・ルート実験場** から、敵の配置、数値編集、停止・巻き戻し、線の隔離試行、ランダム候補の比較を使えます。エディタでは上部の **▶ 実験場**（**▶ ステージ** の右隣）から直接起動できます。専用シーン `speed/gyms/enemy_lab/enemy_lab.tscn` を開いてF6でも起動できます。操作と保存・反映の流れは [仕様書の実験場](docs/spec.md#201-敵ルート実験場) を参照してください。

ピクセル炎は `speed/gyms/pixel_fire_preview.tscn` を開き、Godotの2D編集画面で動きを確認・調整できます。F6の独立した調整画面も使えます。[炎の調整・プリセット保存](speed/assets/pixel/README.md#ピクセル炎を単体で調整する)を参照してください。

ステージ制作は [制作ガイド](docs/dev/stage-production.md) から始めます。録画JSONLと感想を使うバランス調整は [試遊・分析・再比較の手順](docs/dev/stage-production.md#6-記録と感想で調整する) に沿って [分析スキル](.agents/skills/speed-balance-analysis/SKILL.md) を呼び出します。AIへの実装依頼は [AI向け資料](docs/dev/stage-production-ai.md)、ステージ4の制作要件は [個別仕様](docs/game/stages/stage-4.md) を参照してください。

敵・隕石・月・惑星・自機は、素材のある種類を透過ピクセルスプライトで、素材が未制作の敵を仮の図形で表示します。マウスへ機体が向き、左クリックで経路を描き始め、もう一度クリックするとその経路を突進します。Escでポーズ、Pで開発用調整パネルです。アート確認用の静止シーンは `tools/preview_pixel_assets.tscn`（F6で実行）。素材と再生成手順は [ピクセル素材](speed/assets/pixel/README.md) を参照してください。

Godot の CLI が利用できる環境では、リポジトリのルートから次のコマンドでエディタを開けます。

```bash
godot --editor --path speed
```

ゲーム中の名前・説明・UI 文言は [ゲーム内文言](docs/game/text.md) で編集し、記載の手順で CSV とリソース表示名へ反映します。

`.godot/` と `.content/` は生成物としてGit管理から除外します。エディター実行・タイムライン保存・exportで、編集元から実行用ステージと音源を生成します。CLIで生成するときは次を実行します。

```bash
godot --headless --path speed --script res://tools/content/build_all.gd -- --force
```

macOSのローカル確認用アプリは `godot --headless --path speed --export-release macOS /tmp/SPEED.app` で作れます。開発用ファイルの除外と製品公開の設定範囲は[設計書](docs/architecture.md#15-ビルドと配布)を参照してください。

接触・敵・英雄・仕掛け・ボス・全ステージの進行の受け入れ確認は `godot --headless --log-file /tmp/speed-acceptance.log --path speed res://tests/thrill_acceptance.tscn`。確認用のセーブと設定はメモリだけで扱い、時計や強さを調整して実行します。描画付きの画面確認は `--headless` を外し、末尾に `-- --out=/tmp/speed-captures` を足します。

全武器MAX後の成長は `godot --headless --path speed res://tests/post_max_progression.tscn`、同じ3択UIとポーズ入力は `res://tests/post_max_ui.tscn` で確認できます。描画付きの確認は `--headless` を外し、末尾に `-- --out=/tmp/speed-postmax-captures` を付けます。

敵の出現の仕組み（時間帯・強敵の群れ・出現のクリップ・攻撃の予算）の確認は `godot --headless --path speed res://tests/spawn_formations.tscn`。

短時間の性能計測は `godot --path speed --disable-vsync res://tools/profile_run.tscn -- --time=350`。セーブへ書き込まず、ゲームの進行を指定秒へ進めて6秒準備・6秒計測します。

## 構成

| パス | 用途 |
|---|---|
| `speed/` | Godot 本番プロジェクト |
| `demo/` | ブラウザ版の試作、新機能・新スキルの実験 |
| `docs/README.md` | [文書の運用規定](docs/README.md)。文書を触る前に必ず読む |
| `docs/` | ゲーム全体を定義する同じ階層の文書：[企画書](docs/treatment.md)・[仕様書](docs/spec.md)・[設計書](docs/architecture.md) |
| `docs/game/` | 個別資料：[世界観とストーリー](docs/game/world.md)・[デザインとアートスタイル](docs/game/art-style.md)・[ゲーム内文言](docs/game/text.md)・[課題](docs/game/backlog.md) |
| `docs/game/catalog/` | 武器・特性・敵・素材など量産する項目の一覧と、[一覧の運用ルール](docs/game/catalog/rules.md) |
| `docs/game/stages/` | ステージ1〜5の個別仕様（例：[ステージ4](docs/game/stages/stage-4.md)） |
| `docs/game/bosses/` | ボスの個別仕様（[うみへび座](docs/game/bosses/hydra.md)） |
| `docs/dev/` | 制作手順：[ステージ制作ガイド](docs/dev/stage-production.md)・[AI向けの制作参照](docs/dev/stage-production-ai.md) |
| `demo/docs/` | demo の仕様・課題 |
| [AGENTS.md](AGENTS.md) | 本番開発と共通の作業方針 |
| [demo/AGENTS.md](demo/AGENTS.md) | 移行前の指示を保存した demo 向け作業方針 |
| `.github/workflows/vercel-deploy.yml`, `vercel.json` | demo のビルドと Vercel 公開設定 |

## 武器・特性・敵の管理

本番とdemoで同じ [一覧の運用ルール](docs/game/catalog/rules.md) を使い、追加・変更・採否判断・実装の同じ作業で対象側の一覧を更新します。

| 一覧 | 本番 | demo |
|---|---|---|
| 武器 | [武器一覧](docs/game/catalog/weapons.md) | [demoの武器一覧](demo/docs/weapons.md) |
| 特性 | [特性一覧](docs/game/catalog/traits.md) | [demoの特性一覧](demo/docs/traits.md) |
| 敵 | [敵一覧](docs/game/catalog/enemies.md) | [demoの敵一覧](demo/docs/enemies.md) |

## demo を使う

[公開 demo](https://speed-nine-kappa.vercel.app/) は引き続きブラウザで遊べます。操作・調整方法・実験の進め方は [demo/README.md](demo/README.md) を参照してください。

ローカルでは Node.js と Python 3 を使い、リポジトリのルートから次を実行します。外部パッケージのインストールは不要です。

```bash
node demo/build.js
python3 -m http.server 8766 --bind 127.0.0.1 --directory demo/dist
```

ブラウザで [ローカル demo](http://127.0.0.1:8766/) を開きます。`demo/dist/speed.html` は単体で配布できる HTML です。

GitHub Actions は demo または公開設定の変更時に Vercel へデプロイします。`main` は公開版、それ以外のブランチはプレビューです。この公開 URL はブラウザ demo 用です。

個人の作業ログは作りません。経緯は git のコミットに残します。過去の試作記録は `demo/docs/` に保存しています。
