# AGENTS.md — SPEED

SPEED の本番ゲームは Godot で開発する。Godot プロジェクトは [speed/project.godot](speed/project.godot)（リポジトリ内の `speed/`、ローカルでは `speed/speed/`）にある。起動方法と構成は [README.md](README.md) を参照。

- `demo/` はブラウザ版の試作と、新機能・新スキルを手早く試すための実験場。demo を作業するときは、移動前の指示を保存した [demo/AGENTS.md](demo/AGENTS.md) と [demo/README.md](demo/README.md) を読む。demo のゲーム仕様・数値は本番の確定仕様として扱わない。
- Godot の作業は `speed/` 内で行う。既存のプロジェクト設定やユーザーの作業を尊重し、`.godot/` など生成キャッシュはコミットしない。
- 会話は日本語。ユーザーの表記には GitHub ユーザー名を使い、本人の明示的な許可なく本名・フルネームを記載しない。
- 設計相談は先に議論し、ユーザーが決めてから実装する。画面は特定の解像度に固定せず、ユーザーのブラウザタブを勝手に置き換えない。
- 自動テスト・長時間の自動プレイは依頼がある場合だけ実行する。変更に応じたビルド・読み込み・画面確認で検証する。
- **武器・特性・敵の一覧管理は本番・demo共通**。[共通の運用ルール](docs/game/catalog/rules.md) に従い、関連する案・採否・実装・数値を変えた同じ作業で対象側の一覧を更新する。
- 本番の一覧は [武器](docs/game/catalog/weapons.md)・[特性](docs/game/catalog/traits.md)・[敵](docs/game/catalog/enemies.md)、demoの一覧は [demo/docs/catalog.md](demo/docs/catalog.md) から参照する。採用状態と実装状況を区別し、demoの仕様を本番の確定仕様として転記しない。同じ項目を本番に取り入れるときは管理IDと参照先を引き継ぐ。
- 本番の文書は `docs/` に置く。基盤の資料（企画書・世界観とストーリー・デザインとアートスタイル・仕様書・設計書・課題）は `docs/game/`、武器・特性・敵など量産する項目の一覧と運用ルールは `docs/game/catalog/`、作業ログ（ユーザーごとの履歴・報告書）は `docs/logs/`、画像の資料は `docs/art/`。demo の仕様と課題は `demo/docs/` に残す。作業・判断の履歴は、同じ作業の中でユーザーに対応するファイルへ自動で追記する。

| ユーザー | 本番の履歴 | demo の履歴 |
|---|---|---|
| Tomatoguy1029 | [docs/logs/wakida.md](docs/logs/wakida.md) | [demo/docs/wakida.md](demo/docs/wakida.md) |
| ShueMaker70969 | [docs/logs/shumak.md](docs/logs/shumak.md) | [demo/docs/shumak.md](demo/docs/shumak.md) |
| keporusu | [docs/logs/keporusu.md](docs/logs/keporusu.md) | [demo/docs/keporusu.md](demo/docs/keporusu.md) |

作業ユーザーは会話で明示された情報を優先する。特定できなければ確認し、別ユーザーの履歴へ推測で書かない。他のユーザーの記録は書き換えず、番号はファイルごとに続ける。

自分の変更だけを `git add` してコミットする。`git add -A`・`git commit -a`・force push は使わない。他の人の未コミット変更には触れない。最新の `origin/main` が `HEAD` の祖先であることを確認して `git push origin HEAD:main` する。

Vercel で公開するのは demo。GitHub Actions とルートの `vercel.json` で `demo/dist/` を配信する。Godot 本番の配布方法は未設定。demo の公開を変更したときは、公開 HTML とビルド済み `demo/dist/index.html` の一致まで確認する。
