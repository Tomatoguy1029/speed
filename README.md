# SPEED

敵の大群に対して高速移動で立ち向かい、一気に吹き飛ばして圧倒する快感を楽しむ、宇宙を舞台にした2D見下ろしのサバイバーゲーム。

本番ゲームの開発を Godot へ移行しました。ブラウザ版の試作は `demo/` にまとめ、今後も新機能や新スキルを手早く試す実験場として使います。

## Godot で開発する

Godot のプロジェクトは [speed/project.godot](speed/project.godot) です。このリポジトリを `speed/` にクローンした場合、`speed/speed/project.godot` を Godot のプロジェクトマネージャーからインポートしてください。

開発用の入口はメニューバーの **プロジェクト → ツール → SPEED** にまとめています。データ編集・ボス行動・出現タイムライン／編成・ステージ敵調整、ステージ起動・各実験場、ビジュアル／背景編集、素材確認・性能計測をここから開けます。既存のツールバーボタンとショートカットも使えます。無効にしたエディタープラグインの項目は表示されません。

Godot 4.7.2・Forward Plus で開発します。ランの状態と戦闘処理は C++ の GDExtension、制作画面・入力・資源読み込み・表示・UI は Godot が担当します。

### C++ライブラリ

Godotでプロジェクトを開くと、ツールバーの右側に状態を表示します。

| 表示 | 意味 | すること |
|---|---|---|
| `C++: 最新` | ライブラリがソースと一致している | なし |
| `C++: 取得中` | CIが作ったライブラリを取得している | 完了を待つ |
| `C++: 再起動で反映` | 取得は完了し、ゲームは新しいライブラリで動く | エディター内の機能にも反映するならGodotを開き直す |
| `C++: ビルドが必要` | 同じソースのライブラリが公開されていない | **ビルド** を押す |

`main` のC++は、統合後にGitHub Actionsがビルドし、Godotが自動で取得します。クローン直後の初回は拡張の読み込みエラーが出ますが、取得が終われば起動できます。初回のデータ生成はエディターを開いたあと裏で進み、ツールバーに進み具合が出ます。生成中にF5を押すと、終わり次第起動します。

統合前のCI確認は、[Actions「開発用ライブラリ」](https://github.com/Tomatoguy1029/speed/actions/workflows/runtime-library.yml) の手動実行で、実行ブランチと `ref` に確認対象を指定します。Macの両CPUとWindowsをすべてビルドし、ActionsのArtifactsへ保存します。手動実行はReleaseの公開・上書き・削除を行いません。mainへの統合前は次のCLIで `fix/macos-distribution` の手動入口を実行できます。

```bash
gh workflow run runtime-library.yml --repo Tomatoguy1029/speed --ref fix/macos-distribution -f ref=<完全コミット>
```

手元でC++を編集したら、ツールバーの **ビルド** を押します。ビルドは押したときだけ別プロセスで動き、その間もエディターを使えます。ログは下部パネルの **C++ビルド** に表示します。ライブラリが古いまま起動しようとすると、**このまま起動** と **ビルド** を選ぶ確認を表示します。

手元ビルドにはPython 3とC++コンパイラーを使います。macOSはXcode Command Line Tools、Windowsは「C++によるデスクトップ開発」を入れたVisual Studioです。固定版のSDKとSConsは初回のビルドで取得します。SDK・中間ファイル・共有キャッシュは、macOSは `~/.cache/speed-build`、Windowsは `%LOCALAPPDATA%\\speed-build` に置き、全worktreeで使います。

Godotを使わない場合は次の入口を使います。

```bash
python3 tools/build/dev_build.py status
```

```bash
python3 tools/build/dev_build.py build
```

依存の正は [cpp/dependencies.json](cpp/dependencies.json) です。Godot 4.7.2、API 4.7、export template `4.7.2.stable`、SCons 4.11.1、単精度を使います。SDKの完全コミット・APIハッシュ・SConsの版が一致しない場合はビルドを止めます。

### 実行用データ

F5などの実行前に、変更した分だけ自動で生成します。CLIではGodotのimportと共通生成を順に実行します。

```bash
godot --headless --editor --import --path speed
godot --headless --path speed --script res://tools/content/build_all.gd -- --force
```

`.content/run/` に戦闘バイナリ・索引・表示用資源表がそろってから起動できます。生成失敗時はGodotの出力を確認し、古い生成物のまま進めないでください。タイトル・ステージ選択・ゲーム本体のメインシーンは `scenes/app/main.tscn` です。Godot 4.7.2 で開き、**F5 → ゲームスタート → ステージ選択 → 任意のステージ**で遊べます。エディタからの実行とデバッグ用ビルドでは、ステージ選択の「デバッグ全開放」で全ステージを表示できます。調整機能は [仕様書](docs/spec.md#20-調整機能) を参照してください。

開発版のメインメニューにある **敵・ルート実験場** から、敵の配置、数値編集、停止・巻き戻し、線の隔離試行、ランダム候補の比較を使えます。エディタでは上部の **▶ 実験場** から直接起動できます。専用シーン `speed/gyms/enemy_lab/enemy_lab.tscn` を開いてF6でも起動できます。操作と保存・反映の流れは [仕様書の実験場](docs/spec.md#201-敵ルート実験場) を参照してください。

実験場上部の **ヒットストップ（試遊のみ）** では、敵種類を選ぶか配置済みの敵を選択し、「選択中の敵」で対象を合わせて倍率を変えます。試遊を続けながら、現在の同種の敵と次に出現する敵で効果を確認できます。0は停止なし、1は共通時間です。「元の値へ戻す」は選択種類の定義またはステージ上書きへ戻し、実験場の条件リセットも試遊値を消します。恒久保存は **データ編集** または **ステージ敵調整** で行います。

炎・オーラ・後光・マップ・連続強化は、エディタ上部の **▶ ビジュアル編集**、または `speed/gyms/visual_editor.tscn` のF6から共通画面で調整できます。左で種類を選び、中央でプレビュー、右で項目を編集します。保存先と未保存状態を上部へ表示し、切替後も未保存値を保持します。「保存」は表示中の素材だけへ反映し、「再読込」と終了時には未保存値の破棄を確認します。オーラと後光は選択中の伝説モジュールを共有し、ベイク操作はオーラに表示します。

ピクセル炎の再生・配置・保存・PNG出力は **ビジュアル編集 → 炎** にまとめています。既存の `speed/gyms/pixel_fire_preview.tscn` を直接開いた場合も、Inspectorで炎を編集できます。[炎の調整・プリセット保存](docs/dev/tools/pixel-fire-2d.md)を参照してください。

ステージ制作は [制作ガイド](docs/dev/stage-production.md) から始めます。録画JSONLと感想を使うバランス調整は [試遊・分析・再比較の手順](docs/dev/stage-production.md#6-記録と感想で調整する) に沿って [分析スキル](.agents/skills/speed-balance-analysis/SKILL.md) を呼び出します。AIへの実装依頼は [AI向け資料](docs/dev/stage-production-ai.md)、ステージ4の制作要件は [個別仕様](docs/game/stages/stage-4.md) を参照してください。

敵・隕石・月・惑星・自機は、素材のある種類を透過ピクセルスプライトで、素材が未制作の敵を仮の図形で表示します。マウスへ機体が向き、左クリックで経路を描き始め、もう一度クリックするとその経路を突進します。Escでポーズ、Pで開発用調整パネルです。アート確認用の静止シーンは `tools/preview_pixel_assets.tscn`（F6で実行）。素材と再生成手順は [ピクセル素材](speed/assets/pixel/README.md) を参照してください。

macOSで描画付きのGodotを起動するときは、フォーカスを奪わない `godot-bg` を使います。リポジトリのルートから次のコマンドでエディタを開けます。`--headless` の実行は `godot` を使います。

```bash
godot-bg --editor --path speed
```

ゲーム中の名前・説明・UI 文言は [ゲーム内文言](docs/game/text.md) で編集し、記載の手順で CSV とリソース表示名へ反映します。

`.godot/`・`.content/`・拡張の共有ライブラリは生成物としてGit管理から除外します。編集元の保存と、実行用データの生成を分けて扱います。エディタの実行前・CLI・exportは同じ生成入口を使います。

### 配布用ビルド

GitHubで手動実行する入口は [Actions「C++配布確認」](https://github.com/Tomatoguy1029/speed/actions/workflows/cpp-runtime.yml) です。配布フローの修正は `fix/macos-distribution` ブランチにあり、mainへの統合前です。

1. **Run workflow** を開き、**Use workflow from** で `fix/macos-distribution` を選びます。
2. `ref` に `fix/macos-distribution`（版を固定するときは完全コミットSHA）、`platform` に **all** を指定します。片方だけ作る場合は `windows` または `macos` を選びます。mainの入力フォームが表示される場合も、`ref` と `platform=all` を明示します。
3. **Run workflow** を押します。成功後は実行結果の **Summary → Artifacts** から `speed-windows-<run_id>` と `speed-macos-<run_id>` を取得します。`-logs-` を含む成果物は確認ログです。WindowsはダウンロードしたZIPを一式展開し、Macは中の `Speed.zip` を使います。

CLIでも同じブランチ・対象を指定できます。

```bash
gh workflow run cpp-runtime.yml --repo Tomatoguy1029/speed --ref fix/macos-distribution -f ref=fix/macos-distribution -f platform=all
```

配布用のビルドはソースの外に新しい作業先を指定します。以下はMacの例です。MacのexportはGodot本体を直接使えます。手元の `godot-bg` がPATHにあれば、フォーカスを保つ補助として使います。importと共通生成はheadlessで行い、シェーダー事前変換を使うexportは描画付きで行います。`--templates` は `version.txt` を持つGodot 4.7.2のexport templateフォルダへ置き換えてください。

```bash
python3 tools/build/build_run.py --sdk ~/.cache/speed-build/sdk/godot-cpp-e103d348c4b2 --scons ~/.cache/speed-build/scons-4.11.1/bin/scons --platform macos --package-dir <ソース外の新しい作業先> --godot godot --templates /path/to/4.7.2.stable
```

この入口はMacのarm64・x86_64拡張をuniversalへまとめ、独立コピーでimport・共通生成・export・配布構成の確認まで行います。Windowsは `--platform windows` を使います。`--verify` を付けると`verification/` 内の保存先を隔離した確認用パッケージで最小ランと拡張欠落時の拒否を確認し、Macでは `--rendered` を併用すると描画付きの確認を行います。`--verify-final` は隔離した保存先で通常出撃から自然な終了・結果保存・戻るを確認します。Macの出撃準備・初期装備・交換・取消の計測は `--verify-loading --verify-final --rendered` を使います。配布するのは `export/` の成果物です。`package.json` はソースのコミット・成果物のSHA-256・確認範囲を持ちます。CIは配布物と確認ログを別々に保存します。配布構成と署名・公証の範囲は[設計書](docs/architecture.md#15-ビルドと配布)を参照してください。

検査は一時作業場所で、変更に関係する既存の入口だけ使います。C++の人数・出現の確認は `res://tests/runtime/run_population.tscn`、制作・生成・UI・配布は `speed/tests/` の各対象を参照します。検査を行う範囲は [AGENTS.md](AGENTS.md#検証) に従います。

一時作業場所は次の入口で作ります。`--with-generated` を付けるとライブラリ・実行用データ・importキャッシュも複製します。置き場所はユーザーキャッシュの `work/` です。

```bash
python3 tools/dev/workspace.py create <名前> --with-generated
```

終わったら `python3 tools/dev/workspace.py remove <パス>` で消します。残ったものは次の `create` と `clean` が片付けます。7日を過ぎたものと、合計20GBを超えた分の古いものが対象です。使用中のもの、未コミットの変更や未pushのコミットがあるものは残します。

性能計測の入口は `res://tools/profiling/profile_run.tscn`。生成済みのラン定義がある一時作業場所を使い、`SaveManager.SAVE_PATH` と `SETTINGS_PATH` を両方その中へ隔離してから `godot-bg` で起動します。`--time` で開始ラン秒、`--seconds` で60秒以上の計測区間、`--revision` で確認したコミットID、`--out` で結果の保存先を指定します。通常の出撃・C++ラン・入力・描画を使い、条件の未成立と性能未達を分けて出力します。

## 構成

| パス | 用途 |
|---|---|
| `speed/` | Godot 本番プロジェクト。制作・入力・資源・表示・UI・保存 |
| `cpp/` | C++ランの状態・時計・乱数・戦闘・ボスと公開API |
| `tools/build/` | 共通スキーマ生成、固定SDKの拡張ビルド、独立コピーでの配布 |
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
