# AGENTS.md — SPEED

SPEED の本番ゲームは Godot で開発する。Godot プロジェクトは [speed/project.godot](speed/project.godot)（リポジトリ内の `speed/`、ローカルでは `speed/speed/`）にある。起動方法と構成は [README.md](README.md) を参照。

- `demo/` はブラウザ版の試作と、新機能・新スキルを手早く試すための実験場。demo を作業するときは、移動前の指示を保存した [demo/AGENTS.md](demo/AGENTS.md) と [demo/README.md](demo/README.md) を読む。demo のゲーム仕様・数値は本番の確定仕様として扱わない。
- Godot の作業は `speed/` 内で行う。既存のプロジェクト設定やユーザーの作業を尊重し、`.godot/` など生成キャッシュはコミットしない。
- 会話は日本語。ユーザーの表記には GitHub ユーザー名を使い、本人の明示的な許可なく本名・フルネームを記載しない。
- 設計相談は先に議論し、ユーザーが決めてから実装する。画面は特定の解像度に固定せず、ユーザーのブラウザタブを勝手に置き換えない。
- 自動テスト・長時間の自動プレイは依頼がある場合だけ実行する。変更に応じたビルド・読み込み・画面確認で検証する。
- **武器・特性・敵の一覧管理は本番・demo共通**。[共通の運用ルール](docs/game/catalog/rules.md) に従い、関連する案・採否・実装・数値を変えた同じ作業で対象側の一覧を更新する。
- 本番の一覧は [武器](docs/game/catalog/weapons.md)・[特性](docs/game/catalog/traits.md)・[敵](docs/game/catalog/enemies.md)、demoの一覧は [demo/docs/catalog.md](demo/docs/catalog.md) から参照する。採用状態と実装状況を区別し、demoの仕様を本番の確定仕様として転記しない。同じ項目を本番に取り入れるときは管理IDと参照先を引き継ぐ。

## 文書の決まり

- 文書を作る・直す前に、必ず [文書の運用規定](docs/README.md) を読んで従う。置き場、書き方（日付・経緯・作業者の名前・文書自身についての説明を書かない、同じ内容は1か所だけ）、案の扱いはそこにある。
- 個人の作業ログ（作業・判断の履歴）は作らない。経緯は git のコミットに残す。
- コミットの前に `python3 tools/check_docs.py` が通ることを確かめる。クローンごとに1回 `git config core.hooksPath .githooks` を実行すると、コミット前に自動で走る。GitHub Actions でも同じチェックが走る。

## コミットと公開

自分の変更だけを `git add` してコミットする。`git add -A`・`git commit -a`・force push は使わない。他の人の未コミット変更には触れない。pushする前に必ずユーザーへ確認し、承認を得る。承認後、最新の `origin/main` が `HEAD` の祖先であることを確認して `git push origin HEAD:main` する。

Vercel で公開するのは demo。GitHub Actions とルートの `vercel.json` で `demo/dist/` を配信する。Godot 本番の配布方法は未設定。demo の公開を変更したときは、公開 HTML とビルド済み `demo/dist/index.html` の一致まで確認する。
