# Implementation Plan: 突進サバイバー試作

## Overview
`SPEC.md` の全要素を、単一 HTML で遊べる 10 分ランとして実装する。
設計書の試作順（操作 → 重力 → 衝突 → モジュール → 演出）に沿って縦切りで積み上げ、各段階で遊べる状態を保つ。

## Architecture Decisions
- **ESM ソース + 自前バンドラ**：`src/*.js` を ES Modules で書き、`build.js` が import/export を剥がして IIFE に包み `dist/speed.html` に埋め込む。外部ツール不要、file:// で開ける
- **ロジックと描画の分離**：`world.js` の `update(game, dt, input)` が全状態を進め、イベント列（kill, crit, hit, levelup, boom…）を出す。描画・音・UI はイベントと状態を読むだけ。ロジックは Node で headless テスト可能
- **固定タイムステップ（1/120 秒）＋ スウィープ判定**：高速時のすり抜け防止。貫通は線分×円の交差を時刻順に処理
- **数値は `config.js` に集約**：調整パネルはこの CONFIG を直接書き換える
- **乱数はシード可能**：テストとバランス検証の再現性のため

## Task List

### Phase 1: 操作と重力
- [ ] Task 1: 土台（package.json / build.js / index.html / math / 空のキャンバス）
- [ ] Task 2: 引っ張り突進・ゲージ・慣性・持ち越し・カメラ・軌跡
- [ ] Task 3: 重力（中心惑星・小惑星）・フィールド境界・ゾーン・予測線・ミニマップ

### Checkpoint A: 飛び回れる
- [ ] テスト・ビルド通過、ブラウザで突進とスイングバイが動く

### Phase 2: 戦闘とラン
- [ ] Task 4: 衝突と貫通（攻撃力・装甲・弾かれ＋ダメージ・弱点クリティカル・HP・ヒットストップ）
- [ ] Task 5: 敵の種類と行動（8 種＋隕石・宇宙塵）・敵弾
- [ ] Task 6: 時間フェーズ出現・ゾーン強度・経験値・タイマー・勝敗・リザルト

### Checkpoint B: 1 ランが始まって終わる
- [ ] 10 分で負け、規定速度でクリアになる。headless シミュレーションが完走

### Phase 3: 成長とメタ
- [ ] Task 7: モジュール基盤（6 部位・レアリティ・ステータス合成・入手モーダル・HUD）
- [ ] Task 8: 性質を変えるモジュール効果・フィールドカプセル・8:30 以降の出力コア
- [ ] Task 9: コインとステーション画面（メタ強化・記録・保存）

### Checkpoint C: 繰り返し遊べる
- [ ] ステーション → ラン → リザルト → ステーションが一周する

### Phase 4: 演出と調整
- [ ] Task 10: 演出（速度段階・ベイパーコーン・ソニックブームのスロー＋静寂・WebAudio）
- [ ] Task 11: 調整パネル（数値スライダー・時間スキップ等）とバランス検証

### Checkpoint D: 完成
- [ ] 全テスト・ビルド通過、ブラウザで通しプレイ確認

---

## Task 1: 土台
**Description:** ESM ソースを単一 HTML に結合するビルドと、全画面キャンバスが表示される最小ページ。
**Acceptance criteria:**
- [ ] `npm test` が `node --test` を実行する
- [ ] `npm run build` で `dist/speed.html` が生成され、import/export を含まず JS として構文が通る
- [ ] ベクトル・乱数（シード可能）ユーティリティがある
**Verification:** build.test.js / math.test.js 通過、ブラウザで黒いキャンバス
**Dependencies:** None
**Files:** package.json, build.js, index.html, src/math.js, src/main.js, test/build.test.js, test/math.test.js
**Scope:** M

## Task 2: 引っ張り突進
**Description:** 押してドラッグ→離して逆方向へ発射。ゲージは押下時間で溜まる。チャージ中も慣性で流れ、勢いは持ち越し。上限超過は緩やかに減衰、エネルギー切れで少し減速。カメラは速度でズームアウト、軌跡は速度で伸びる。
**Acceptance criteria:**
- [ ] 発射方向がドラッグの逆、ゲージが押下時間で 0→上限まで増える
- [ ] 同方向への連続突進で速度が積み上がり、上限で頭打ち
- [ ] チャージ中も位置が速度に沿って進む
**Verification:** ship.test.js、ブラウザで操作確認
**Dependencies:** 1
**Files:** src/config.js, src/ship.js, src/input.js, src/render.js, src/world.js, test/ship.test.js
**Scope:** M

## Task 3: 重力とフィールド
**Description:** 中心惑星と小惑星の重力、スイングバイ。円形フィールドの境界、3 ゾーン表示、予測線（重力込み）、ミニマップ。
**Acceptance criteria:**
- [ ] 重力加速度は中心に近いほど強く、何もしないと中心へ落ちる
- [ ] 中心をかすめると速度が上限を一時的に超える
- [ ] 境界の外へは押し戻される
**Verification:** gravity.test.js、ブラウザで確認
**Dependencies:** 2
**Files:** src/gravity.js, src/field.js, src/world.js, src/render.js, test/gravity.test.js
**Scope:** M

## Task 4: 衝突と貫通
**Description:** 攻撃力（速度×倍率）と装甲で貫通/弾かれを判定。弾かれたら自機ダメージ。弱点（向き依存）でクリティカル。スウィープ判定で 1 回の突進が複数体を貫く。HP、無敵時間、ヒットストップ、撃破パーティクル。貫通不可の敵は表示が変わる。
**Acceptance criteria:**
- [ ] 攻撃力 ≥ 装甲で貫通、未満で自機ダメージ＋反射
- [ ] 弱点角度内の接触は必ずクリティカル
- [ ] 高速でもすり抜けず、一直線上の複数体を一度に貫ける
**Verification:** combat.test.js、ブラウザで確認
**Dependencies:** 3
**Files:** src/combat.js, src/enemies.js, src/world.js, src/render.js, test/combat.test.js
**Scope:** M

## Task 5: 敵の種類
**Description:** ドリフター・ダーター・装甲型・分裂型・減速型・射撃型・ミサイル艇・戦艦、隕石・宇宙塵。敵弾（直進弾・誘導ミサイル）。
**Acceptance criteria:**
- [ ] 各種が固有の行動をし、分裂型は時間で増える、減速型は速度を奪う
- [ ] 敵弾に当たると HP 減少＋減速
- [ ] 隕石は攻撃力があれば砕ける
**Verification:** enemies.test.js、ブラウザで確認
**Dependencies:** 4
**Files:** src/enemies.js, src/projectiles.js, src/world.js, src/render.js, test/enemies.test.js
**Scope:** L

## Task 6: 時間フェーズとラン進行
**Description:** 0:00–10:00 のフェーズ表に沿った出現量・種類・強さ。ゾーン（中心・外縁）で強化。経験値ジェム、レベル、タイマー、HP 0 / 時間切れで負け、規定速度到達でクリア、リザルト画面。
**Acceptance criteria:**
- [ ] getPhase(t) がフェーズ表どおり、無双期は数が多く 1 体あたりは脆い
- [ ] 規定速度到達で勝ち、HP 0 / 600 秒で負け
- [ ] headless で 600 秒シミュレーションが例外・NaN なく完走
**Verification:** spawner.test.js / world.test.js、ブラウザで確認
**Dependencies:** 5
**Files:** src/spawner.js, src/progression.js, src/world.js, src/ui.js, test/spawner.test.js, test/world.test.js
**Scope:** M

## Task 7: モジュール基盤
**Description:** 6 部位・レアリティ・ステータス合成。経験値で 1 つ提示 → 一時停止 → 付け替え/捨てる。部位の偏りを抑える抽選。HUD に装備表示。
**Acceptance criteria:**
- [ ] 付け替えで旧モジュールは消え、ステータスが再計算される
- [ ] 抽選は空き・低レア部位を優先しつつランダム
- [ ] 提示中はゲームが止まる
**Verification:** modules.test.js、ブラウザで確認
**Dependencies:** 6
**Files:** src/modules.js, src/world.js, src/ui.js, test/modules.test.js
**Scope:** M

## Task 8: 性質を変えるモジュールとカプセル
**Description:** 反射、軌跡炸裂、チャージ衝撃波、終点爆発、吹き飛ばし巻き込み、回生、自己修復、ソニックブーム小/大、リミッター解除。フィールドのカプセル（中心ほどレア）、8:30 以降の出力コア。
**Acceptance criteria:**
- [ ] 各効果が発動し、イベントとして観測できる
- [ ] カプセルのレア度がゾーン依存
- [ ] 8:30 以降にリミッター解除の入手機会がある
**Verification:** modules.test.js 追加分、ブラウザで確認
**Dependencies:** 7
**Files:** src/modules.js, src/effects.js, src/world.js, src/render.js, test/effects.test.js
**Scope:** L

## Task 9: コインとステーション
**Description:** コイン（部品）ドロップ・回収。ラン終了で持ち帰り。ステーション画面でメタ強化（HP・最高速・チャージ・攻撃・回収範囲・経験値）。記録（脱出タイム・最高速度）。localStorage 保存。
**Acceptance criteria:**
- [ ] 勝敗に関わらずコインが加算・保存される
- [ ] メタ強化が次のランの基礎値に反映される
- [ ] 保存データが壊れていても初期値で起動する
**Verification:** progression.test.js、ブラウザで一周確認
**Dependencies:** 8
**Files:** src/progression.js, src/ui.js, src/main.js, test/progression.test.js
**Scope:** M

## Task 10: 演出
**Description:** 速度段階演出、ベイパーコーン、上限付近で音が遠のく、ソニックブームのスロー＋静寂＋衝撃波、画面揺れ、星の流れ、WebAudio 効果音。
**Acceptance criteria:**
- [ ] 速度段階を超えたときイベントと表示が出る
- [ ] ソニックブーム発動時にタイムスケールが一時的に下がる
- [ ] 音は初回操作後に開始し、失敗してもゲームは動く
**Verification:** fx.test.js、ブラウザで確認
**Dependencies:** 9
**Files:** src/audio.js, src/render.js, src/world.js, test/fx.test.js
**Scope:** M

## Task 11: 調整パネルとバランス
**Description:** CONFIG の主要値をスライダーで変更、時間スキップ、モジュール付与、無敵、コイン付与。headless ボットで時間ごとの敵数・撃破数・到達速度を出力して初期値を調整。
**Acceptance criteria:**
- [ ] パネルの変更が即時反映される
- [ ] 時間スキップでフェーズが進む
- [ ] ボット計測で各フェーズの意図（無双期の撃破密度など）が数値で確認できる
**Verification:** world.test.js 追加分、`node tools/balance.js` 出力、ブラウザで通しプレイ
**Dependencies:** 10
**Files:** src/debug.js, src/config.js, tools/balance.js
**Scope:** M

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| 高速時のすり抜け・操作不能感 | High | 固定 1/120 秒ステップ＋スウィープ判定、カメラズームを調整可能に |
| 体験曲線（無双期・緊張期）が数値で崩れる | High | フェーズ表を data 化、headless ボットで計測、調整パネル |
| 敵数増加での描画負荷 | Med | 空間ハッシュ、パーティクル上限 |
| 手触りは自動テストで測れない | Med | ブラウザで実操作確認を各チェックポイントで行う |

## Open Questions
- なし（未決定事項は SPEC の範囲で仮決めし、数値は調整パネルで変更可能にする）
