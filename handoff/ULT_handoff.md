# ULT演出 引き継ぎ（SPEED / Godot本番）

作業ブランチ：`claude/ult-effects`（origin に push 済み）。続きも同じブランチで行う。
最新コミット：`bb335cf1` ペルセウス座の力をメドゥーサの目の演出と一斉に砕ける石化にする
ベース：少し前の `main`（`7dd8f026`）。今の `origin/main` より遅れている。PR化の前に main の取り込みが必要。

このファイルと `handoff/tools/` は、ユーザーの指示でブランチに入れている一時的な引き継ぎ。ULTの作業が終わったら `handoff/` ごと消す。

**ふたご座・ヘルクレス座の詳細引き継ぎ**：[`ULT_gemini_hercules_spec.md`](ULT_gemini_hercules_spec.md)。両ULTの操作・攻撃・エフェクト・確定事項と未決事項はこちらを参照。下記「方向のみ」等の記述は詳細引き継ぎより前の状態を示すため、最新の合意・試作方針については新文書を優先する。


---

## 1. 全ULT共通の方針（ユーザーと合意したこと）

- **主役は力そのもの**。発動時に、その力に関わるもの（英雄・メドゥーサ等）を「イメージさせる」演出を出す。英雄そのものを派手に描くのが目的ではない。
- **武器と差別化し、武器より強く**。強さの方向はULTごとに違ってよい（画面全体の範囲、決まりを外す、時間を止める等）。全部を画面全体にする必要はない。
- **ほかの演出とかぶらない**（クリティカルの星、プラズマ、共通の爆発 BlastBursts、星座の金の光、レア彗星の金の尾 など）。
- pixelFX は **技法の参考**（粒の動き、ノイズの炎・煙、光の重なり、段の色）。エフェクトをそのまま使うのは不可。Godot の shader で作る（既存の plasma_burst などと同じ作り）。
- **上から見下ろす画角**。
- **獲得演出**：星座を完成させたら絵を重ね、そのあと獲得の演出。今の仮カットイン（`scripts/ui/ult_cutin.gd`・`assets/ui/rewards/ult_grant.gdshader`）は一切使わず一から作る。

### ユーザーの好み・ダメ出しの傾向（重要）
- 円・点線・図形を組み合わせただけのものは「使い物にならない」。
- 線がくっきりしすぎ・色が濃すぎてゲームから浮くのはNG。宇宙の壮大さ・深淵から睨む恐怖感、人智を超えた力。
- 動きは**生き物らしく**。機械的なイージング・単純な波でゆがませるだけはNG。重々しく、緩急（例：7割まで開く→数コマ止まる→0.12秒で勢いよく見開く）。1コマで変わるのは「バグに見える」。
- 生き物の形（獅子など）を shader の図形やコードのドット打ちで作るのは、何度やっても品質が届かなかった。**形は絵で用意する**方針。
- 試作は必ずGIFで見せる。見せる前に自分で見て、明らかにダメなら送らない。
- 許可した見た目は、本物の画面でも**同じ色・形**で出すこと（ここで大きく揉めた。§4参照）。

---

## 2. 各ULTの状態

### ペルセウス座（メドゥーサの首）— 完了・コミット済み
- 仕様：`docs/spec.md` 8.1 を書き換え済み。発動→約2秒で目が開ききる→画面内の敵（ボス・障害物以外）と弾が石化→0.6秒後に一斉に砕けて倒れる。大物（★6以上）は砕けず最大HPの25%、ボスは `boss_stun` 停止＋最大HPの8%。データは `speed/data/heroes/perseus.tres`（`open_delay` 2.0 / `shatter_delay` 0.6 / `big_damage_ratio` 0.25 / `boss_damage_ratio` 0.08 / duration 3.8）。
- 演出（許可済み。今のコミットの見た目が正解）
  - 目：閉じた黒い線が急に現れて太くなる→上まぶたが大きく下は小さく、つかえながら7割まで重く開く→数コマ止まる→0.12秒で見開く。瞳孔は真ん中が少しふくらんだ蛇の目。眼球（虹彩＋瞳孔）はわずかに動く。目は機体の手前。
  - 見開いた瞬間：画面ブラー（目の中心へ引き込み）＋一瞬の色収差＋蛇の形の闇のオーラ（蛇そのものではない）。円の波はNG。
  - 石化は敵の中心から外へ。破片は凹形も混じる不揃いな石のかけら（敵の大きさで数・大きさ・距離が変わる）。
- 実装：`cpp/behaviors/heroes/perseus.cpp`、`scripts/render/equipment/heroes.gd`、shader `hero_medusa` / `hero_medusa_screen` / `hero_shatter` / `hero_stone.gdshaderinc` / `hero_color.gdshaderinc`、敵の `pixel_sprite` / `pixel_armor` / `biter_part_armor`、`scripts/render/fx/stone_shards.gd`。設計は `docs/architecture.md` の該当段落。
- 未確認：大物へのダメージの画面確認、多角形描画の敵（おおいぬ座の体など）は石の見た目対象外、`hero_aura_gpu.gd` は main 時点から別の型エラーで途中停止している（ペルセウス部分まで届かない）。

### しし座 — 実装済み・未コミット（見た目はユーザー確認済み、力の中身は試遊待ち）
- 力「獅子になる」は仕様書 8.1 が正本。数値は `speed/data/heroes/leo.tres`（10秒・クールダウン60秒・毎秒600・曲がり1.5倍・A×2.5・0.4秒間隔）。
- C++：`cpp/behaviors/heroes/leo.{h,cpp}`（`active`・`contact`）、`ship.cpp`（移動・曲がり・当たりの切替）、`draw.cpp`（なぞり不可）、`run_runner.cpp`（武器・特性停止）、`combat_resolver.cpp`（被弾なし）、`heroes.cpp`（描画中は発動しない）。旧「線が太くなる」の `trace_width` は全削除。スキーマは LeoDefinition（speed・turn_mult・power・hit_interval・front・back・radius）。
- 見た目：`speed/scripts/render/equipment/leo_lion.gd`、`speed/shaders/hero_leo.gdshader`（本体）、`hero_leo_blur.gdshader`（本体とオーラ別々のモーションブラー）、`hero_leo_screen.gdshader`（画面外側の星雲の光と十字のきらめき）、絵は `speed/assets/pixel/leo/`（`handoff/tools/export_lion.py` で aseprite から書き出し、はぐれドット除去）。`heroes.gd` が発動中だけ獅子を出し、`run_frame_view.gd` が機体を隠す。
- 変身：星くずが輪郭へ移る（0.55秒）→閃光と波→本体4段階（〜0.95秒）→粒子4段階（〜1.75秒）。ユーザー確認はまだ。
- テスト：`hero_behaviors.gd -- --cpp-leo`、`hero_aura_gpu.gd -- --cpp-leo` は新しい力に書き換え済みで通過。
- 撮影・試遊：一時作業場所（`tools/dev/workspace.py`）の project.godot に `handoff/tools/lion_game_capture.gd`（本物のゲームで撮影）・`lion_play.gd`（しし座を救出した状態で起動）を autoload で足して使う。スクリプトを変えたら `build_all.gd -- --force` で内容データを作り直す（作り直さないとランの開始に失敗する）。
- GIF はコマごとに色を選び直す `make_gif.py` を使う（共通パレットだと画面演出に色を取られて獅子の色が崩れる）。

### ふたご座（光と影の兄弟）— 試作実装済み・未コミット（ユーザーと見た目を調整中）
- 力は仕様書 8.1 が正本。`power`（影の体当たりの倍率、仮で2.0）は `speed/data/heroes/gemini.tres`。旧「線を2本」（`twin.first`・`capture_first`・`swap_paths`）は削除。`TwinFirst` の通知は `MeteorImpact` に置き換えた。
- C++：`cpp/behaviors/heroes/gemini.{h,cpp}`。
  - `launch`：反転した経路を作る。
  - `follow`：並走中の影の位置。
  - `duplicate`：弾の複製。
  - `weapons`：ソニックブームの発射とエスコートウィングを毎フレーム進める。
  - `finish`：突進の終わりの武器。
  - `AsTwin`：機体の位置と経路を影のものに差し替える範囲。
  - `equipment_appear`：ドローンが現れる進み。
- 呼び出し元と、各武器の変更：
  - `draw.cpp`：launch。`run_runner.cpp`：follow・duplicate・weapons。`render_builder.cpp`：ふたご座の間は通常のなぞり線を出さない。
  - 影の武器は軽い方式で作った。弾は複製し、接触は `EquipmentSystem::contact` で反応させる。ミラージュは同じ残像の一覧へ影の残像を足し、ソニックブームは `SonicBehavior::emit` を影の値で呼ぶ（輪に `twin`）。エスコートは `LoadoutState::twin_escort` に影用の状態を持ち、質量牽引は `TowCargo::twin` で区別する。
- 見た目：
  - `gemini_twins.gd` が担当する。光の機体（金・形だけ）、影の機体、粘る分裂、並走、残光・残像、崩れて戻る断片、ドローンを影の粒が組み立てる演出。
  - シェーダーは `hero_gemini.gdshaderinc`・`hero_gemini.gdshader`・`hero_gemini_split.gdshader`。
  - 2本の線は `heroes.gd` の `draw_fire` が粉で描く。
  - ふたご座の間は、`run_frame_view` が本物の機体を隠す。
  - `afterimage.gd` は残像を番号で見分ける（同じ時刻に始まる影の残像と混ざって、2機の間が塗られる不具合への対応）。
- 未確認：
  - ドローンの組み立て演出と、ミラージュの塗りの修正は、実際の画面ではまだ見ていない。
  - 装備のテスト（`equipment_effects`）で全武器が失敗していた。変更前からかどうかは、ユーザーの指示で調べていない。

### ヘルクレス座（火の隕石）— 試作実装済み・未コミット（ユーザーと見た目を調整中）
- 力の中身は今のまま（仕様書 8.1）。着弾の通知は共通の爆発ではなく `meteor_impact`（`cpp/behaviors/heroes/hercules.cpp`）。
- 見た目：
  - `hercules_meteors.gd` と `hero_hercules.gdshader` が担当する。
  - 落下と着弾：炎に包まれた岩と涙の形の尾、岩の形の落下予告の影（0.6秒で岩の大きさまで育つ）、着弾の閃光・照り返し・破片・溶岩のしずく・煙、カメラの揺れ（`run_frame_view`）。
  - 焼け跡：溶岩の殻のマグマ。
- 落下時間を延ばす案（0.9秒）は、戦闘の時間のテストが6か所崩れるので保留。

### 獲得演出（カットイン）
- 星座完成→絵を重ねる→獲得演出。今の仮は使わない。各ULTの演出が決まってから作る。

---

## 3. 進め方のメモ

- ユーザーとは日本語。設計はまず話して決めてから実装。試作はGIFで見せる。
- ULTの仕様変更は仕様書 8.1・データ `speed/data/heroes/<id>.tres`・C++ `cpp/behaviors/heroes/`・テスト `tests/runtime/hero_behaviors.gd` をそろえる。データの値を足すときは `cpp/content/schema/heroes.json` と `tools/content/build_run_content.gd`、生成は `tools/build/generate_run_schema.py`。
- 生き物の形は絵、質感と動きは shader、が今の分担。

---

## 4. 技術的にハマったこと（必読）

1. **HDR の色**：本物のゲームは HDR（`render_pipeline.gd` が `use_hdr_2d = true`）。Godot は `source_color` 付きの uniform を HDR で自動的にリニアへ直す。手でさらにリニアへ直すと二重変換で真っ黒になる。
   → ULTの shader は色の uniform に **source_color を付けない**（sRGB の数値で受ける）。計算は sRGB で行い、HDR のときだけ最後に `to_linear`（`hero_color.gdshaderinc`）。`linear_output` は `get_viewport().use_hdr_2d` から毎フレーム渡す。敵の material は作る時点で HDR がまだ有効でないので `RenderingServer.get_current_rendering_method() != "gl_compatibility"` で決める（`stone_linear`）。色の丸め（floor）は sRGB の値で行う。
2. **画面の取り込み**：`hint_screen_texture` は前の層で取り込まれた古い画面が使い回され、目が消えた。目は画面演出より上の専用 CanvasLayer（`follow_viewport_enabled`）に置き、画面演出の前に `BackBufferCopy`。
3. **`pixel_sprite.gdshader` は敵以外にも使われる**（弾など、色の b=1 のことがある）。石の変換は `stone_enabled` を敵の絵のときだけ有効にしている。
4. **確認用の撮影**：HDR の画面をそのまま `get_image()` すると暗く写る／8bitで変換すると暗部がつぶれる。`handoff/tools/capture_srgb.gdshader` を付けた TextureRect でHDRでない画面へ写して撮る（`handoff/tools/live_capture.gd` 参照）。これを知らずに暗いGIFを何度も送ってしまった。
5. **文字コード**：このブランチの `generate_run_schema.py` は日本語Windowsで文字化け・`--check` 失敗する（修正はワープホールのブランチ `0cf94dd1` にだけある）。`PYTHONUTF8=1` を付けて生成・ビルドする。
6. **改行**：Windows の Python で `open(..., "w")` すると CRLF になる。`newline=""` か `"\n"` を付ける。PowerShell の Set-Content は日本語を壊すので使わない。
7. **作業フォルダが共有されている**：途中でこのフォルダのブランチが別の操作で `claude/warp-bonus-effects` に切り替えられ、pull もされた。コミット前に `git branch --show-current` を必ず確認。ワープ用の `.uid` やコンテンツ一覧の差分がエディタから湧くことがある（自分のものではない）。

---

## 5. 環境

- Godot：`C:\Users\brigh\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Node（Codex が入れたもの）：`C:\Users\brigh\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe`
- Python：`C:\Users\brigh\AppData\Local\Programs\Python\Python312\python.exe`（Pillow なし・ffmpeg なし。GIFは `handoff/tools/make_gif.py`）
- pixelFX（固定コミット a841596）：スクラッチの clone は消えるかもしれない。必要なら `git clone https://github.com/patch-gg/pixelfx`（スキルは `skills/pixelfx/SKILL.md`）。
- C++ ビルド（Windows）：godot-cpp `e103d348…` を `/tmp/speed-godot-cpp`、SCons 4.11.1 を `/tmp/speed-build-python`（venv）。ない場合は作り直す（clone と pip install、ダウンロードはユーザー許可済みだった）。
  `PYTHONUTF8=1 python tools/build/build_run.py --sdk <godot-cpp> --scons <scons.exe> --platform windows --arch x86_64 --output <出力フォルダ>`
  `--output` はフォルダとして扱われ、その中に DLL ができる。本体の `speed/extensions/run/bin/` には置かず、`/tmp` のコピーへ入れて確認する（AGENTS.md の検証方針）。
- 確認の手順：リポジトリの `speed/` を `/tmp` へコピー（`.godot` 除外）→DLLを `extensions/run/bin/` へ→`--headless --editor --import`→`--script res://tools/content/build_all.gd -- --force`→テスト `res://tests/runtime/hero_behaviors.tscn -- --cpp-perseus`。
- 本物の画面での撮影：`handoff/tools/live_capture.gd` と `capture_srgb.gdshader` をコピー先の `res://` に置き、`--script res://live_capture.gd -- <出力フォルダ> armored`（第2引数は敵の種類。テスト用ランの雑魚を差し替える）。今はペルセウス座を発動する流れなので、ほかのULTは発動する英雄と撮るコマを書き換えて使う。生のRGBを `handoff/tools/make_gif.py <フォルダ> <out.gif> 1024 768 30` でGIF化。

## 6. handoff/tools/ の中身
- `hero_capture.gd`：本物のゲームで英雄を救出して発動し、決まった操作を流して撮る（`--hero-capture <出力> <gemini|hercules> [ステージ] [秒] [武器,…]`）。武器選択では1を押し、獲得演出などで操作できない間は3秒待ってから1秒おきにクリックする
- `hero_lab.gd`：実験場のシーンを直接開いて英雄の力を選んだ試遊にする（`res://gyms/enemy_lab/enemy_lab.tscn -- --hero-lab <ID>`）
- `make_gif.py`：生RGB連番→GIF（標準ライブラリのみ）
- `gif_frames.py`：GIFから指定コマをPNGに
- `crop_png.py`：PNGの一部を切り出して拡大（見比べ用）
- `live_capture.gd` / `capture_srgb.gdshader`：本物のC++ランとRunFrameViewでULTを撮る
- `pfx_raw.mjs`：pixelFX の本物のエフェクトを連番に書き出す（GIFで候補を見せる用）
