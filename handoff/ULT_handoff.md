# ULT演出 引き継ぎ（SPEED / Godot本番）

作業ブランチ：`claude/ult-effects`（origin に push 済み）。続きも同じブランチで行う。
最新コミット：`bb335cf1` ペルセウス座の力をメドゥーサの目の演出と一斉に砕ける石化にする
ベース：少し前の `main`（`7dd8f026`）。今の `origin/main` より遅れている。PR化の前に main の取り込みが必要。

このファイルと `handoff/tools/` は、ユーザーの指示でブランチに入れている一時的な引き継ぎ。ULTの作業が終わったら `handoff/` ごと消す。

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

### しし座 — 方向決定・絵待ち（ユーザーがシルエットの絵を用意する）
- 力を変更する（仕様書はまだ未変更）：「線が太くなる」→ **獅子になる**
  - 効いている間、機体は星でできた獅子の姿をまとう。機体は隠す（獅子そのものが機体）。
  - 操作は通常の移動だけ（ゲージの描画なし）。速さは高速移動（なぞり終えたあとの勢い）と同じか少し速いくらい。
  - 被弾しない（マリオのスター状態）。武器は止める。
  - 触れた敵は装甲・特殊な倒し方に関係なく貫く。攻撃力は慎重に（大物・ボスのワンパン不可）。同じ敵には間隔を置いて当たる（張り付き不可、露骨に長くない自然な間隔）。
  - 障害物は全部砕ける。惑星・月は跳ね返される（未確認、下書きではそうした）。
  - 効いている時間はULTごとに強さを見て決める（一括にしない）。
- 見た目：真上から見下ろす。唐獅子の形を参考（シーサー、古代メキシコのジャガー像、ライドンもモチーフ。ただし形をなぞらない）。体の中は半透明の宇宙（紫・マゼンタ・青の水彩の星雲に細かい星。参考画像はユーザーが会話で提示）、全身から金のオーラが立ちのぼり体のふちにもかかる、輪郭線は描かない。たてがみは体の6割ほどまでなびくのが一番かっこいい。シルエットは力強く。大きさは機体の2〜3倍。
- 絵の依頼の目安：真上から・頭が右・機体の2〜3倍・シルエットのみ（色はshader）・たてがみは体の6割まで（別レイヤー可）・駆ける4〜6コマ。
- 未コミットの試作（作業ツリーに残っている）：`speed/shaders/hero_leo.gdshader`、`speed/scripts/render/equipment/leo_lion.gd`。どちらも却下された図形ベースの試作。宇宙の質感（`cosmos()`）と星くずの粒は流用できるかもしれない。絵が来たら作り直す。

### ふたご座 — 方向のみ
- 力は今のまま（線を2本、双子の機体が2本目を走る）。ミラージュ（分身）と近いが、ユーザーは「今のままでいい」。
- コンセプト：カストルとポルックス、**光と影の兄弟**（片方が光、片方が影）が「かっこいい」と好評。具体案・試作はまだ。

### ヘルクレス座（火の隕石）— 方向のみ
- 土台は pixelFX の `fire/meteor` の作り（上から見た向き）。燃える岩が煙と火の尾を引いて落ち、着弾の閃光・火球・岩・燃えかす・冷えるクレーター。共通の爆発（BlastBursts）とかぶらない専用の着弾にする。試作はまだ（初期に作った円と点線の版は却下・削除済み）。
- 今の表示は `heroes.gd` の `draw_fire`（円を描くだけの仮）。

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
- `make_gif.py`：生RGB連番→GIF（標準ライブラリのみ）
- `gif_frames.py`：GIFから指定コマをPNGに
- `crop_png.py`：PNGの一部を切り出して拡大（見比べ用）
- `live_capture.gd` / `capture_srgb.gdshader`：本物のC++ランとRunFrameViewでULTを撮る
- `pfx_raw.mjs`：pixelFX の本物のエフェクトを連番に書き出す（GIFで候補を見せる用）
