# AGENTS.md — SPEED（重力圏脱出）

作業を始める前に読むファイル。作業の方針・リポジトリの構成・守るべきルールだけを書く。
**仕様・経緯・課題はここに書かず `docs/` に残す**（下の「ドキュメント」）。このファイルは方針や構成が変わったときだけ更新する。

- 2D 見下ろしのサバイバー系の **試作**。目的は作者が通しで遊んで「面白くなりそうか」を判断すること（作り込みより全要素を一通り体験できることを優先）
- 公開 URL: https://speed-nine-kappa.vercel.app ／ GitHub: https://github.com/Tomatoguy1029/speed （`main` への push で Vercel が本番デプロイ）
- 元の設計書: ユーザー（[Tomatoguy1029](https://github.com/Tomatoguy1029)）の「ゲーム設計書.md」。要点は [SPEC.md](SPEC.md) に転記済み（初期のもの。現在の仕様は `docs/spec.md`）

## ドキュメント

| ファイル | 中身 | いつ更新するか |
|---|---|---|
| [docs/spec.md](docs/spec.md) | 現在の仕様（操作・数値・画面・計測値） | 挙動や数値を変えたとき |
| [docs/weapons.md](docs/weapons.md) | 武器の候補・効果・採否・既存処理・保留枠 | 武器の追加・仕様変更・採否判断・実装時 |
| [docs/traits.md](docs/traits.md) | 特性の候補・発動条件・重ね掛け・採否・既存処理 | 特性の追加・仕様変更・採否判断・実装時 |
| [docs/enemies.md](docs/enemies.md) | 敵の種類・基礎数値・行動・出現・実装状態 | 敵の追加・数値・行動・出現条件の変更時 |
| [docs/module-plan.md](docs/module-plan.md) | 武器・特性の共通設計（装備枠・成長・入手方法） | 共通方針を変えたとき |
| [docs/catalog.md](docs/catalog.md) | 一覧の運用ルール | 管理方針を変えたとき |
| [docs/wakida.md](docs/wakida.md) | [Tomatoguy1029](https://github.com/Tomatoguy1029)の作業・判断の履歴（旧 decisions.md） | Tomatoguy1029 の作業時に末尾へ追記 |
| [docs/shumak.md](docs/shumak.md) | [ShueMaker70969](https://github.com/ShueMaker70969) の作業・判断の履歴 | ShueMaker70969 の作業時に末尾へ追記 |
| [docs/keporusu.md](docs/keporusu.md) | [keporusu](https://github.com/keporusu) の作業・判断の履歴 | keporusu の作業時に末尾へ追記 |
| [docs/backlog.md](docs/backlog.md) | 未解決の課題・次の候補・保留中の議論 | 課題が見つかった／片付いたとき |
| `tasks/plan.md`, `tasks/todo.md` | 最初の実装計画（完了済み、記録として残す） | 更新しない |

### コンテンツ一覧の更新

- 武器・特性・敵に関する作業前に [docs/catalog.md](docs/catalog.md) と該当一覧を読む。追加・変更・採否判断・実装の同じ作業で一覧も更新する。
- 個別の一覧を正本とし、候補・採用・保留・不採用と実装状況を区別する。提案を採用済みにせず、現行の類似処理と新仕様の違いを明記する。
- 武器の保留枠は通常候補と分離したまま保持する。廃止・保留した項目は理由と参照先を残す。詳細な運用は `docs/catalog.md` に従う。

### ユーザーごとの記録更新

- **Claude Code・Codex などのエージェントは、ユーザーが作業するたびに、同じ作業の中で対応する履歴ファイルを自動で更新する**。更新の依頼を毎回待たず、日付・要望・作業内容・決めたことと理由を末尾に番号付きで追記する。記録がまだないファイルでは「まだ作業記録はない。」を最初の記録に置き換える。
- 更新先は **GitHub `Tomatoguy1029`→ `docs/wakida.md`、GitHub `ShueMaker70969` → `docs/shumak.md`、GitHub `keporusu` → `docs/keporusu.md`**。会話で明示された作業ユーザーを優先し、明示がなければ認証済みの GitHub アカウントなど確認できる情報で判断する。特定できない場合は本人に確認し、別ユーザーの履歴へ推測で書かない。
- 作業前に関連するユーザーの履歴も確認する。他のユーザーの作業記録は書き換えず、番号はファイルごとに続ける。
- 現在の仕様と未解決の課題は共通で管理する。挙動・数値を変えたら `docs/spec.md`、課題が見つかった／片付いたら `docs/backlog.md` も同じ作業の中で更新する。

## ユーザーとのやりとりのルール

- ユーザーの表記は GitHub ユーザー名を使う。本人の明示的な許可なく本名・フルネームを会話やドキュメントに記載しない。
- **設計の相談（操作・面白さ・スリルなど）にはすぐ実装案や「実装しますか？」で返さない**。問題を一緒に掘り下げ、意見と質問を返す。実装はユーザーが決めてから
- 操作の方向性はユーザーと議論中（[docs/backlog.md](docs/backlog.md)）。
- フェーズ（強化期・圧力期など）は裏のレベルデザイン用。**ゲーム画面にも説明にも名前を出さない**
- 画面は機種ごとに比率が違う前提。特定の解像度に合わせない
- ユーザーのブラウザのタブを勝手に置き換えない。アプリ内ブラウザでスマホ表示を真似たタブはクリックがタッチ扱いになるので、確認が終わったら元に戻す

## 作業のしかた

```bash
node --test          # テスト（node:test、依存ゼロ）
node build.js        # src/*.js を結合して dist/speed.html と dist/index.html を生成
node tools/balance.js 3 1 god   # 自動プレイで各フェーズの数値を計測（god=無敵）。引数: 回数 シード [god]
```

- **自動テストはユーザーが依頼したときだけ**（2026-10-06の指示: イテレーションが遅くなるため、毎回のテスト実行は不要）。通常はビルドと変更箇所の画面確認で進める。長時間の自動プレイも実行しない
- **dist/ はコミットする**（`speed.html` は単体で配布できる 1 ファイル。`index.html` は Vercel 用で中身は同じ）
- **公開のしかた（Claude Code・Codex 共通）**: `main` に push すると GitHub Actions が本番をデプロイする（Vercel 側でも `node build.js` を実行する）。自動でコミット・push する仕組みはない（以前の Claude Code の Stop フックは、別のエージェントの作業途中の変更までまとめてコミットしたため廃止）。変更したらビルド・変更箇所の画面確認のあと **自分が変えたファイルだけ** を `git add` してコミットし、最新の `origin/main` が `HEAD` の祖先であることを確認して `git push origin HEAD:main`（force push しない）
- **同じフォルダで複数のエージェント（Claude Code と Codex など）が作業することがある**。`git add -A` や `git commit -a` は使わない。他の人の未コミットの変更には触れない
- **デプロイはすべて GitHub Actions**（[.github/workflows/vercel-deploy.yml](.github/workflows/vercel-deploy.yml)）: `main` への push は本番、ほかのブランチはプレビュー（ブランチごとに別 URL）。Vercel CLI とオーナーのトークンで動く。**リポジトリは公開**（Hobby プランでは、非公開リポジトリだと Vercel のチーム外の人のコミットは CLI 経由でも `BLOCKED` になり、デプロイが待ちのまま止まる。公開にしたので共同作業者のコミットも通る）。Vercel の GitHub 連携によるデプロイは `vercel.json` の `git.deploymentEnabled: false` で止めている（Hobby プランでは Vercel のチーム外の人のコミットを弾くため）。URL は Actions の実行結果（Summary）に出る。Actions 画面の「Run workflow」で手動実行もできる
- **公開の確認**: Vercel の公開 HTML が検証済みの `dist/index.html` と一致するまで確認し、ローカルコミットだけで公開反映済みと報告しない。ユーザーがローカル限定・公開保留を指定した場合はそれを優先する
- 区切りのいい変更は自分で中身の分かるメッセージでコミットする
- ユーザーのブラウザ（アプリ内プレビュー）のタブを勝手に置き換えない。確認は本番 URL を別タブで開くか、自動テストで行う

### バンドラの制約（build.js）
- ES Modules を自前で結合（import/export を剥がして 1 つの IIFE に入れる）
- **全ファイルでトップレベルの名前が重複してはいけない**（build がエラーにする）
- `export { x } from './y.js'` 形式は使わない。相互 import（循環）は関数宣言のみなら可

## ファイル構成

| ファイル | 役割 |
|---|---|
| `src/config.js` | 調整用の数値をすべて集約（`CONFIG`）。調整パネルはこれを直接書き換える |
| `src/world.js` | ゲーム状態と 1/120 秒固定ステップの更新、衝突、オファー、予測線 |
| `src/controls.js` | **操作方式**（7 種）。生入力→意図への変換と、方式ごとの操舵・照準 |
| `src/input.js` | 生入力（キー・Space・ドラッグ・カーソル位置）だけを集める |
| `src/ship.js` | 機体の基礎ステータス、ゲージ、発射速度、移動と減速 |
| `src/gravity.js` / `src/field.js` | 中心惑星・小惑星の重力、ゾーン、危険度、宇宙塵 |
| `src/combat.js` | 攻撃力（= 速度/100 × 倍率）、貫通／弾かれ、弱点クリティカル |
| `src/enemies.js` / `src/projectiles.js` | 敵 10 種の定義と行動、敵弾 |
| `src/spawner.js` | フェーズ表（時間ごとの数・強さ・構成）と出現処理 |
| `src/hits.js` | 敵へのダメージ、撃破、ドロップ、範囲攻撃 |
| `src/effects.js` | 性質を変えるモジュール効果、カプセル、出力コア |
| `src/modules.js` | 6 部位・26 種のモジュール、レア度、ステータス合成、抽選 |
| `src/progression.js` | 経験値、メタ強化（ステーション）、セーブ |
| `src/stages.js` | 速度段階（演出用） |
| `src/parts.js` | モジュール 6 部位を宇宙船のパーツとして描く（船首・エンジン・砲・レーダー・翼の装甲・リアクター）。組み上がった機体図も |
| `src/render.js` / `src/audio.js` / `src/ui.js` / `src/debug.js` | 描画・合成音・DOM 画面・調整パネル |
| `src/main.js` | 画面遷移（ステーション→ラン→リザルト）とメインループ |

## ファイル構成

| ファイル | 役割 |
|---|---|
| `src/config.js` | 調整用の数値をすべて集約（`CONFIG`）。調整パネルはこれを直接書き換える |
| `src/world.js` | ゲーム状態と 1/120 秒固定ステップの更新、衝突、オファー、予測線 |
| `src/controls.js` | **操作方式**（7 種）。生入力→意図への変換と、方式ごとの操舵・照準 |
| `src/input.js` | 生入力（キー・Space・ドラッグ・カーソル位置）だけを集める |
| `src/ship.js` | 機体の基礎ステータス、ゲージ、発射速度、移動と減速 |
| `src/gravity.js` / `src/field.js` | 中心惑星・小惑星の重力、ゾーン、危険度、宇宙塵 |
| `src/combat.js` | 攻撃力（= 速度/100 × 倍率）、貫通／弾かれ、弱点クリティカル |
| `src/enemies.js` / `src/projectiles.js` | 敵 10 種の定義と行動、敵弾 |
| `src/spawner.js` | フェーズ表（時間ごとの数・強さ・構成）と出現処理 |
| `src/hits.js` | 敵へのダメージ、撃破、ドロップ、範囲攻撃 |
| `src/effects.js` | 性質を変えるモジュール効果、カプセル、出力コア |
| `src/modules.js` | 6 部位・26 種のモジュール、レア度、ステータス合成、抽選 |
| `src/progression.js` | 経験値、メタ強化（ステーション）、セーブ |
| `src/stages.js` | 速度段階（演出用） |
| `src/parts.js` | モジュール 6 部位を宇宙船のパーツとして描く（船首・エンジン・砲・レーダー・翼の装甲・リアクター）。組み上がった機体図も |
| `src/render.js` / `src/audio.js` / `src/ui.js` / `src/debug.js` | 描画・合成音・DOM 画面・調整パネル |
| `src/main.js` | 画面遷移（ステーション→ラン→リザルト）とメインループ |
