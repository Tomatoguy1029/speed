# AGENTS.md — SPEED

SPEED の本番ゲームは Godot で開発する。Godot プロジェクトは [speed/project.godot](speed/project.godot)（リポジトリ内の `speed/`、ローカルでは `speed/speed/`）にある。起動方法と構成は [README.md](README.md) を参照。

- `demo/` はブラウザ版の試作と、新機能・新スキルを手早く試すための実験場。demo を作業するときは、移動前の指示を保存した [demo/AGENTS.md](demo/AGENTS.md) と [demo/README.md](demo/README.md) を読む。demo のゲーム仕様・数値は本番の確定仕様として扱わない。
- Godot の作業は `speed/` 内で行う。既存のプロジェクト設定やユーザーの作業を尊重し、`.godot/` など生成キャッシュはコミットしない。
- 会話は日本語。ユーザーの表記には GitHub ユーザー名を使い、本人の明示的な許可なく本名・フルネームを記載しない。
- 設計相談は先に議論し、ユーザーが決めてから実装する。画面は特定の解像度に固定せず、ユーザーのブラウザタブを勝手に置き換えない。
- 自動テスト・長時間の自動プレイは依頼がある場合だけ実行する。変更に応じたビルド・読み込み・画面確認で検証する。
- 本番の仕様と課題は `docs/`、demo の仕様と課題は `demo/docs/` に残す。作業・判断の履歴は、同じ作業の中でユーザーに対応するファイルへ自動で追記する。

| ユーザー | 本番の履歴 | demo の履歴 |
|---|---|---|
| Tomatoguy1029 | [docs/wakida.md](docs/wakida.md) | [demo/docs/wakida.md](demo/docs/wakida.md) |
| ShueMaker70969 | [docs/shumak.md](docs/shumak.md) | [demo/docs/shumak.md](demo/docs/shumak.md) |
| keporusu | [docs/keporusu.md](docs/keporusu.md) | [demo/docs/keporusu.md](demo/docs/keporusu.md) |

作業ユーザーは会話で明示された情報を優先する。特定できなければ確認し、別ユーザーの履歴へ推測で書かない。他のユーザーの記録は書き換えず、番号はファイルごとに続ける。

自分の変更だけを `git add` してコミットする。`git add -A`・`git commit -a`・force push は使わない。他の人の未コミット変更には触れない。最新の `origin/main` が `HEAD` の祖先であることを確認して `git push origin HEAD:main` する。

Vercel で公開するのは demo。GitHub Actions とルートの `vercel.json` で `demo/dist/` を配信する。Godot 本番の配布方法は未設定。demo の公開を変更したときは、公開 HTML とビルド済み `demo/dist/index.html` の一致まで確認する。
