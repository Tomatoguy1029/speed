# SPEC：SPEED ステージ4・ヒュドラの実装

**状態：初回実装・検証完了。正式格子5配置と試遊後の調整は別作業。** 本書は、ヒュドラ再設計を実装するための目的、検証方法、作業境界を定義する。

## 1. 目的と対象ユーザー

Godot本番のステージ4ボスを、合体形態から分離形態、羅針盤の解放まで一戦通して遊べる状態にする。高速移動と線を描く攻撃に、多頭の形状と首ごとの特性をかみ合わせる。

直接の利用者は、試遊と調整をする開発者、素材を差し替える絵担当、後続のステージ制作に参加する協力者。ステージ4を、遊べる戦闘と差し替え可能な素材を備えた最小の制作モデルとして渡す。

今回の到達点は一戦分の実装・検証・受け渡し。ユーザーの試遊と、その結果に基づく立ち回り・HP・モーションの調整は実装完了後の別作業として残す。

## 2. 仕様の参照先と今回の範囲

ゲームの決まりと個別演出は専用仕様に集約する。本書から同じ定義を複製せず参照する。

| 内容 | 正の置き場 | 実装で確認する結果 |
|---|---|---|
| 戦闘進行・首の構成 | [ヒュドラ仕様 2・3章](docs/game/hydra.md#2-戦闘の進行) | 中央を攻めて首が増え、瓦礫破壊で分離し、不死の蛇の撃破で勝利へ進む |
| 通常攻撃 | [ヒュドラ仕様 4章](docs/game/hydra.md#4-通常攻撃) | 首ごとの技が位置・状態・予算に応じて選択される |
| 大技と反撃 | [ヒュドラ仕様 5章](docs/game/hydra.md#5-大技) | 配置と判定が成立した技だけを使い、終了後に攻めどきがある |
| 首のコンボ | [ヒュドラ仕様 6章](docs/game/hydra.md#6-首の特性を使うコンボ) | 発動機会に使用可能な候補から1種類を選び、共通の待ち時間を守る |
| 状態とBehaviorTree | [ヒュドラ仕様 7章](docs/game/hydra.md#7-攻めどきと行動判断の要件) | 欠員・硬直・位置・形態が変わっても攻撃選択と位置取りが成立する |
| モーションとVFX | [ヒュドラ仕様 8章](docs/game/hydra.md#8-素材と演出) | 蛇の体全体の自然な動作と状態間の接続、判定に同期したピクセル表現がある |
| 実装と検証の順番 | [実装計画](tasks/plan.md)・[タスク一覧](tasks/todo.md) | 各タスクの受け入れ条件とチェックポイントを満たす |
| 採用・実装状況 | [敵一覧](docs/game/catalog/enemies.md) | 採用仕様と実際に動く範囲が区別されている |

格子ビームは仕組みと差し替え可能な仮1配置を今回の対象にする。正式5配置は受領後の別作業。分離蛇の通常時の間合い・移動範囲は初期設定で動かせるようにし、蛇らしい動作とゲーム中のモーション接続まで今回に含める。

ユーザー試遊後の調整は [実装完了後の別作業](tasks/todo.md#after-implementation) を参照する。この項目は今回の実装タスク列・依存関係・完了条件に含めない。

## 3. 技術構成と制約

- 本番プロジェクトは [speed/project.godot](speed/project.godot)。Godot 4.6系、GDScript、Forward Plusを使う。
- 既存のLimboAI GDExtension v1.8.1、LimboHSM、BehaviorTree、AnimationPlayerを使う。ゲームと素材は本番の構成を継続する。
- 形態進行は役者、状況判断はBT、攻撃の振り付けはタイムライン、表示は差し替え可能な演出側で扱う。詳細は [設計書 6.1](docs/game/architecture.md#61-敵とボスの-ai) を参照する。
- 既存のEnemyTable、部位の行と所有ID、攻撃予算、実験セッションを使う。特定のボスへの依存を共通Managerへ埋め込まない。
- 判定・タイムライン・モーション・VFXを世界時間へ同期する。描画と衝突で経路と攻撃の形を共有する。
- 調整値の正は `speed/data/` の `.tres`。HP、装甲、距離、速度、重み、予算コスト、各時間をコードへ散在させない。
- 画面比率と解像度の変化に対応し、配置・危険範囲・一筆で通る余裕を検証する。

## 4. コマンド

すべてリポジトリのルートから実行する。以下は実装承認後のコマンド。仕様作成段階では文書確認だけを実行する。

### 開発・試遊

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path speed
/Applications/Godot.app/Contents/MacOS/Godot --path speed res://gyms/hydra_trial.tscn
```

### インポート・スクリプトとリソースの読み込み

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed res://tests/load_all.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed --script res://tests/check_rules.gd
```

本番の配布ビルドと書き出し方法は未設定。今回のビルド確認はインポートと全リソースの読み込みを使い、配布用ビルドの成功とは区別する。

### 代表的な振る舞い・回帰テスト

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed res://tests/hydra_ai.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed res://tests/hydra_targeting.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed res://tests/lab_core.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed res://tests/lab_director.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed res://tests/lab_replay.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed res://tests/attack_priority.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed --script res://tests/clip_attack_priority.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path speed --log-file /tmp/speed-hydra-acceptance.log res://tests/thrill_acceptance.tscn
```

これは本番テスト全体の一部。全体実行では `speed/tests/` の自動検証用シーンとスクリプトを調べ、補助シーンと区別して対象を確定する。新規テストは対応する実行コマンドを実装時に追記する。

### 文書と差分

```bash
python3 tools/check_docs.py
git diff --check
```

## 5. プロジェクト構成

| パス | 用途 |
|---|---|
| `speed/scripts/bosses/` | Hydra役者、首の形状、攻撃・演出の処理 |
| `speed/scripts/bosses/tasks/` | LimboAIの条件・実行タスク |
| `speed/scenes/bosses/` | ボス、BT、タイムライン、演出のシーンとリソース |
| `speed/scripts/actors/boss_actor.gd` | ボス役者の共通インターフェース |
| `speed/scripts/managers/` | 既存のダメージ、部位所有、攻撃の形、最終勝利などの共通接続 |
| `speed/data/bosses/`・`speed/data/enemies/` | ボスと首の定義・調整値 |
| `speed/shaders/`・`speed/assets/` | シェーダーと差し替え素材 |
| `speed/gyms/hydra_trial.*` | 本番の戦闘を使う短い試遊経路 |
| `speed/tests/` | 実験セッションを使う振る舞い・回帰・読み込み確認 |
| `docs/game/hydra.md` | 個別のゲーム仕様と演出要件 |
| `tasks/plan.md`・`tasks/todo.md` | 作業順・受け入れ条件・実装後の別作業 |

## 6. コードスタイル

既存のGDScriptに合わせ、タブでインデントする。関数・変数は `snake_case`、定数は `UPPER_SNAKE_CASE`、型名は `PascalCase` を使う。状態・技のIDには既存の `StringName` の流儀を使い、公開する値はInspectorやリソースから編集できるようにする。

既存の `hydra_boss.gd` の例：

```gdscript
func _alive(neck: Neck) -> bool:
	return neck.row >= 0 and manager.enemies.is_same(neck.row, neck.row_id) and table.dead[neck.row] == 0
```

行番号とIDを照合し、再利用された別の敵を操作しない。状態の更新・終了処理・所有する攻撃の解放を明確に分け、BTの条件評価は読み取りだけにする。タスクの対象に必要な最小の変更を行い、隣接する無関係な処理の整理を混ぜない。

## 7. テスト戦略

既存のGodotテストシーンと実験セッションを使い、新たなテストフレームワークの導入を前提にしない。

1. 実装承認後、編集前に基準状態の読み込みと既存テストを確認する。コード・規約・旧テストの期待が食い違う失敗と、新しい変更による回帰を区別する。
2. 新しい振る舞いは期待する結果を先に失敗テストで示し、最小実装で成功させる。選択される行動、HP、状態、実ダメージ、経路と攻撃範囲を検証する。
3. 旧Hydraの露出・段階・再生を期待する検証は、承認仕様へ置き換えるタスクで更新する。無関係な検証を削ったり、理由なくスキップしたりして成功扱いにしない。
4. 各タスクで対象テストと影響する回帰、読み込みを確認する。チェックポイントと最終確認では本番のテスト全体を検証する。各結果は終了値とログの両方を確認する。
5. シェーダー、蛇の自然な動き、モーション遷移、予告と安全な隙間は、実装側が描画付きの短い試遊で確認する。Headlessでの成功を見た目の品質の証拠にしない。
6. 実験は固定seedと隔離した設定を使い、通常のセーブ・録画へ書かない。実装側の動作確認と、後日ユーザーが行う試遊・調整を分ける。

数値のカバレッジ率を新設する代わりに、各タスクの受け入れ条件、首の欠員、位置条件、状態境界、中断・復帰・行再利用、時間停止、形態移行、勝利通知の重複をケースで押さえる。

## 8. 作業境界

### 常に行う

- 最新のユーザー指示、[AGENTS.md](AGENTS.md)、[文書規定](docs/README.md)、[一覧の運用](docs/game/catalog/rules.md) を守る。
- 承認した仕様・計画に沿って縦に小さく実装し、BT・動作・判定・演出・検証がつながった単位で完了させる。
- 敵一覧には採用と実装状況を分けて反映する。ゲームの詳細定義は専用仕様、数値は `.tres` に置く。
- 未コミット変更の帰属を確認し、自分の変更だけを対象にする。実装では1タスク1コミットを基本とし、コミット前に検証と文書チェックを行う。
- 攻撃予告・実行・被弾・中断・硬直と、素材の差し替え経路を保つ。

### 先に確認する

- ゲーム実装の開始。この仕様と全体計画の明示的な承認を得る。
- 採用した技・形態進行・攻撃の制約・作業範囲を変える判断、未決の読み方が大きく分かれる判断。
- 新しい外部依存、共有APIやプロジェクト設定の大きな変更、セーブ形式、CIや配布方式の変更。
- 他作業の変更と競合し、変更の所有・安全な分離が判断できない場合。
- push、mainへの統合、公開・配布。実装の承認と分けて扱う。

### 行わない

- 仕様・計画のレビュー中にゲームを実装すること。
- 未合意の新ギミック、正式扱いの格子配置、固定バランス、専用の攻撃解禁条件を追加すること。
- 蛇の移動を直線追跡だけにし、停止した全身のその場回転で旋回を済ませること。
- ユーザー試遊やその結果による立ち回り調整を、今回の実装完了の待ち条件にすること。
- demo、他のボス、別担当の性能改善、通常ステージの出現変更、共通獲得演出の再制作を今回へ混ぜること。
- ユーザーの未コミット編集を上書き・破棄すること、生成画像や `.godot/` を巻き込むこと、秘密情報を保存すること。
- `git add -A`、`git commit -a`、force push、承認のないpushやmainの変更。
- 未実行の検証や、未受領の正式素材・ユーザーの意見を完了・確認済みとして報告すること。

## 9. 成功条件

- [x] [実装計画](tasks/plan.md) の今回のタスクと受け入れ条件を満たし、一戦の操作確認と回帰検証ができる。
- [x] 採用した攻撃がBTから実行され、首の欠員・位置・予算・再使用待ち・中断を扱える。
- [x] 表示と判定が一致し、蛇の動作とモーションの接続、シェーダー表現、反撃の隙を実画面で確認できる。
- [x] 最終勝利と共通の獲得演出へ一度だけつながり、途中の中央破壊と区別される。
- [x] 試遊可能な成果物、操作方法、素材・調整値の編集方法、検証結果を渡す。
- [x] 正式格子5配置とユーザー試遊後の調整は、実装済み範囲と分けて残す。

## 10. 未決事項の扱いと承認

詳細な未決項目は [ヒュドラ仕様 10章](docs/game/hydra.md#10-実装後に調整する事項)、回答状況と仮実装できる範囲は [計画の判断表](tasks/plan.md#着手前の判断h00cp0) を参照する。

既定の技に必要な位置・時間・重み・予算・移動範囲は初期設定として編集可能にする。戦闘ルールが変わる判断は明示して確認する。ユーザー試遊後の調整項目を事前に決め切ることは着手の条件にしない。

本書と既存の実装計画の承認範囲で実装する。範囲を変更する場合は改めて確認する。
