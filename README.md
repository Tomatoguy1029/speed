# SPEED

敵の大群に対して高速移動で立ち向かい、一気に吹き飛ばして圧倒する快感を楽しむ、宇宙を舞台にした2D見下ろしのサバイバーゲーム。

本番ゲームの開発を Godot へ移行しました。ブラウザ版の試作は `demo/` にまとめ、今後も新機能や新スキルを手早く試す実験場として使います。

## Godot で開発する

Godot のプロジェクトは [speed/project.godot](speed/project.godot) です。このリポジトリを `speed/` にクローンした場合、`speed/speed/project.godot` を Godot のプロジェクトマネージャーからインポートしてください。

プロジェクト設定は Godot 4.6・Forward Plus です。現在はプロジェクト設定とアイコンだけの初期状態で、ゲームシーン・スクリプト・実行用メインシーンはまだありません。

Godot の CLI が利用できる環境では、リポジトリのルートから次のコマンドでエディタを開けます。

```bash
godot --editor --path speed
```

`.godot/` は生成キャッシュとして Git 管理から除外します。Godot 本番のビルド・配布方法は、今後の開発で決めます。

## 構成

| パス | 用途 |
|---|---|
| `speed/` | Godot 本番プロジェクト |
| `demo/` | ブラウザ版の試作、新機能・新スキルの実験 |
| `docs/` | 本番の [企画書](docs/concept.md)・[仕様書](docs/spec.md)・[設計書](docs/design.md)、課題、ユーザーごとの作業記録 |
| `demo/docs/` | demo の仕様・課題・これまでの作業記録 |
| [AGENTS.md](AGENTS.md) | 本番開発と共通の作業方針 |
| [demo/AGENTS.md](demo/AGENTS.md) | 移行前の指示を保存した demo 向け作業方針 |
| `.github/workflows/vercel-deploy.yml`, `vercel.json` | demo のビルドと Vercel 公開設定 |

## 武器・特性・敵の管理

本番とdemoで同じ [一覧の運用ルール](docs/catalog.md) を使い、追加・変更・採否判断・実装の同じ作業で対象側の一覧を更新します。

| 一覧 | 本番 | demo |
|---|---|---|
| 武器 | [武器一覧](docs/weapons.md) | [demoの武器一覧](demo/docs/weapons.md) |
| 特性 | [特性一覧](docs/traits.md) | [demoの特性一覧](demo/docs/traits.md) |
| 敵 | [敵一覧](docs/enemies.md) | [demoの敵一覧](demo/docs/enemies.md) |

## demo を使う

[公開 demo](https://speed-nine-kappa.vercel.app/) は引き続きブラウザで遊べます。操作・調整方法・実験の進め方は [demo/README.md](demo/README.md) を参照してください。

ローカルでは Node.js と Python 3 を使い、リポジトリのルートから次を実行します。外部パッケージのインストールは不要です。

```bash
node demo/build.js
python3 -m http.server 8766 --bind 127.0.0.1 --directory demo/dist
```

ブラウザで [ローカル demo](http://127.0.0.1:8766/) を開きます。`demo/dist/speed.html` は単体で配布できる HTML です。

GitHub Actions は demo または公開設定の変更時に Vercel へデプロイします。`main` は公開版、それ以外のブランチはプレビューです。この公開 URL はブラウザ demo 用です。

本番の作業記録は [Tomatoguy1029](docs/wakida.md)・[ShueMaker70969](docs/shumak.md)・[keporusu](docs/keporusu.md) ごとに追記します。過去の試作記録は `demo/docs/` に保存しています。
