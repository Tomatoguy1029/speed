# ステージ1・5 作業一覧

自動実装承認済み。未完了の項目はチェックを外して保持する。[計画](plan.md) と [SPEC](../SPEC.md) に従う。

## 共通の完了条件

各タスクは記載した動作を実際の試遊入口まで通す。新技は値・条件・フロー登録・表示・終了/取消・保存再読込を含む。既存共通処理は必要性を確認した最小変更に限る。各タスクの正本と敵一覧を同じ変更で更新し、実装済みと未検証を区別する。

パスは特記を除き `speed/` 基準。「新」は追加予定で未存在。ファイル欄は主な変更候補で、文書や生成差分を含めて約5ファイルを超える場合は、独立して試遊できる小タスクに分けてから着手する。大きな項目14/19/20/21/28は下記の実行単位で扱う。

- 14a 突進 → 14b 飛びかかり噛みつき。各回それぞれの技だけを登録・試遊。
- 19a 本体+複製2体で噛みつき系統 → 19b 渦 → 19c 瓦礫 → 19d ビーム → 19e 雷 → 19f 順番の飛びかかりと回収。各回、該当Hydra技だけを追加し、既存本番Hydraと比較。系統追加は独立、19fは全系統後。
- 20a 吸引・ゼロ吸収ビーム・口到達の排出 → 20b 星数連動の弧状弾・配置編集。20bは20a後。
- 21a 巻く接近・接触・脱出 → 21b 収縮・一度被弾・無敵離脱。21bは21a後。
- 28a 山3 → 28b 山4 → 28c 山5。各回、その区間と隣接育成だけを再確認。

これらの小単位にも親項目の完了条件・検証・ファイル上限を適用し、その単位だけの結果を確認して次へ進む。基礎だけを作って後で全て接続する分け方にはしない。

## 検証記号

- **G**：SPEC掲載の正規生成コマンドとGodot import/読み込み。終了コードに加えてログのエラーを確認。
- **M**：保存を保護した実験場/単独試遊で、各項目に書いた操作と結果を目視確認。
- **E**：編集→保存→正規生成→新しい試遊/再読込の往復。同じ実行中の旧参照を壊さない。
- **D**：文書・リンク・差分・文言生成の整合確認。`tasks/`による既存checkerの失敗は別記し、通過と報告しない。

計画作成時は計画のみ。以下のG/M/Eおよびゲーム自動テストは実行していない。

## 00 着手条件と既存差分を確認

- [x] 完了
- **依存**：なし
- **受け入れ条件**：ブランチ・変更所有・仕様差が分かり、既存の矢試作を保持する。SPECの未決と合意済み事項を区別する。
- **検証**：D。git status/diffと各仕様を読み、作業対象と保留を提示。生成やゲーム起動はしない。
- **主なファイル**：読取のみ：SPEC.md、docs/game/bosses、docs/game/stages、git差分

## 01 一角獣の突進を地形対応込みで仕上げる

- [ ] 完了
- **進捗**：遠方で届かない突進を始める回帰を再現し、距離条件を修正。正規生成と一角獣テストは通過。全体テストと画面確認に未解消があり、完了扱いは保留。
- **依存**：00
- **受け入れ条件**：通常・往復突進が近くへ戻って始まり、明らかな遮蔽を避ける。惑星を壊さず角刺さり→抜きまで進む。
- **検証**：G・M・E・Dの該当範囲。惑星手前/背後、画面外、自機移動、往復中の形態予約を単独試遊。
- **主なファイル**：scripts/bosses/monoceros_boss.gd; data/bosses/monoceros_moves/charge.tres; data/bosses/monoceros_moves/return_charge.tres

## 02 一角獣の薙ぎ・蹴りを表示と条件まで仕上げる

- [ ] 完了
- **依存**：01
- **受け入れ条件**：各技の予告・命中・隙が一致し、既存条件から発動する。固定連携を必須にしない。
- **検証**：G・M・E・Dの該当範囲。正面/背面/範囲外、技途中の閾値到達、単独と区間再生を確認。
- **主なファイル**：scripts/bosses/monoceros_boss.gd; scripts/bosses/monoceros_presentation.gd; data/bosses/monoceros_moves/sweep.tres; data/bosses/monoceros_moves/kick.tres

### C1 一角獣の接近・通常攻撃を試遊して確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 03 一角獣の登場とブースターを接続

- [x] 完了
- **進捗**：登場飛行・停止と青白いブースターを実装。回帰テストと描画確認を通過。
- **依存**：02
- **受け入れ条件**：画面外から飛来→停止→構えが動く。青白い炎の尾が船尾から伸び、突進時に噴射が強まる。
- **検証**：G・M・E・Dの該当範囲。登場から攻撃へ進め、停止/移動/突進/被弾/終了で炎が残らないことを確認。
- **主なファイル**：scripts/bosses/monoceros_boss.gd; scripts/bosses/monoceros_presentation.gd; scenes/bosses/monoceros_presentation.tscn; data/bosses/monoceros.tres

## 04 剣状の角への移行と光の槍を接続

- [x] 完了
- **依存**：03
- **受け入れ条件**：現在の技・隙・角抜き後に形態移行し、その間は攻撃可能。槍は突き終わりに固定→全体飛散→粒子減衰する。
- **検証**：G・M・E・Dの該当範囲。技・回復・角刺さり中の予約を試し、槍表示と判定の終端、再読込を確認。
- **主なファイル**：scripts/bosses/monoceros_boss.gd; scripts/bosses/monoceros_presentation.gd; data/bosses/monoceros_moves/lance.tres; scenes/bosses/monoceros_presentation.tscn

## 05 ステージ1の6山から一角獣を試遊

- [ ] 完了
- **依存**：04
- **受け入れ条件**：既存6山と480秒の接続を保ち、編集した出現/予算が反映される。成長は8〜9割・好プレイMAX目標と実測を区別。
- **検証**：G・M・E・Dの該当範囲。保存→生成→区間再生。通常開始の人間試遊で装備完成度を確認し、数値目標を勝手に固定しない。
- **主なファイル**：data/stages/stage_1.tres; data/formations/内の対象s1編成（1回の調整は最大3シーン）

### C2 一角獣の一戦とステージ1の接続を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 06 竜を仮本体と噛みつき一技で試遊

- [x] 完了
- **依存**：00
- **受け入れ条件**：本番用BossActorを実験場に生成し、噛みつきの予告→判定→隙が動く。全身が一つの命中先を使う。
- **検証**：G・M・E・Dの該当範囲。頭/胴へ通常攻撃・突進を当て、1攻撃の重複と再命中を確認。シーン再生成時の行ID再利用も確認。
- **主なファイル**：新 scripts/bosses/draco_boss.gd; 新 scenes/bosses/draco_boss.tscn; 新 data/bosses/draco.tres; 新 scripts/bosses/draco_presentation.gd; 新 data/bosses/draco_moves/bite.tres

## 07 竜の噛みつきを共通フローと正規生成から実行

- [x] 完了
- **依存**：06
- **受け入れ条件**：距離・方向条件、開始・完了・失敗・取消が既存adapter契約につながる。生成物から技が動く。
- **検証**：G・M・E・Dの該当範囲。候補なし/開始失敗/取消後再開、入力更新・出力欠落時の生成、既存ボス生成を確認。
- **主なファイル**：scripts/bosses/draco_boss.gd; 新 data/bosses/ai/draco_action_rules.tres; 新 data/bosses/ai/draco_flow.tres; addons/content_build/builder.gd; tools/content/build_boss_program.gd

## 08 ボス行動画面から竜を編集して試遊

- [x] 完了
- **依存**：07
- **受け入れ条件**：竜が選択肢に現れ、条件と値を保存・再読込・単独試遊できる。独自AIを追加しない。
- **検証**：G・M・E・Dの該当範囲。噛みつきの距離を変更し、プレビューと実行を比較。海蛇/一角獣も開く。
- **主なファイル**：tools/editor/boss_flow/editor.gd; tools/editor/boss_flow/range_preview.gd; gyms/boss_flow_trial.gd; data/bosses/ai/draco_action_rules.tres

### C3 竜を編集・生成・単独試遊できることを確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 09 竜のHP閾値で攻撃を止めて次段階へ進む

- [x] 完了
- **依存**：08
- **受け入れ条件**：70/40%の仮閾値でHPを止め超過を捨てる。移行中の被弾保護と操作許可を適用し、技を再開できる。
- **検証**：G・M・E・Dの該当範囲。最大HPを超える一撃、連続命中、噛みつき途中で試す。hitイベントのdmg/撃破通知と実HPの整合も調べる。
- **主なファイル**：scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/draco.tres; 必要時 scripts/runtime/systems/combat_system.gd; 必要時 scripts/actors/boss_actor.gd

## 10 竜の尾の薙ぎ払いを単独・フローで使う

- [x] 完了
- **依存**：09
- **受け入れ条件**：左右の構え→尾の判定→隙が見える。キャンセルで判定と表示を終了する。
- **検証**：G・M・E・Dの該当範囲。側面/後方の範囲内外、HP移行を確認し、値変更後に再読込。
- **主なファイル**：新 scripts/bosses/draco_tail_sweep.gd; 新 data/bosses/draco_moves/tail_sweep.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_action_rules.tres

## 11 竜の頭部星弾を一斉発射

- [x] 完了
- **依存**：09
- **受け入れ条件**：頭の左右60〜70度を目安とする扇に等間隔の弾を並べ、一斉発射する。発射後の弾はHP移行で残る。
- **検証**：G・M・E・Dの該当範囲。準備/発射直後に中断し、発射済みのみ残ること、発射位置の保存反映を確認。
- **主なファイル**：新 scripts/bosses/draco_star_fan.gd; 新 data/bosses/draco_moves/star_fan.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_action_rules.tres

### C4 HP段階と基本攻撃の表示/判定を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 12 尾の叩きつけと小衝撃波を当てる

- [x] 完了
- **依存**：10
- **受け入れ条件**：予告地点への叩きつけと周辺の小衝撃波が表示に一致する。
- **検証**：G・M・E・Dの該当範囲。直撃/周辺/範囲外と移行中断を確認。照準固定時点は着手時に相談する。
- **主なファイル**：新 scripts/bosses/draco_tail_slam.gd; 新 data/bosses/draco_moves/tail_slam.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_action_rules.tres

## 13 隕石の裏で薙ぎ払いブレスを防ぐ

- [ ] 完了
- **依存**：09
- **受け入れ条件**：口から隕石を投射→炎を掃く一連の技を試遊できる。遮蔽を表示と判定で共有し、岩はプレイヤーが壊せる。ブレスを防ぎ切って終了後に崩れる。
- **検証**：G・M・E・Dの該当範囲。岩の裏/縁/破壊直後、首の回転、HP移行前後で安全地帯と岩の寿命を確認。未決の飛行中判定を相談。
- **主なファイル**：新 scripts/bosses/draco_breath.gd; 新 data/bosses/draco_moves/breath.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_action_rules.tres

### C5 遮蔽と通常攻撃を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 14 突進と飛びかかり噛みつきを個別に接続

- [ ] 完了
- **依存**：09
- **受け入れ条件**：突進は星の角で予告直線へ、飛びかかりは踏み込み→跳躍→噛みつきで動く。前脚/振向き噛みを足さない。
- **検証**：G・M・E・Dの該当範囲。このタスクは技ごとに2回に分けて完了判定する。画面外再配置・予告固定・違う画面比率・HP取消を各回確認。
- **主なファイル**：新 scripts/bosses/draco_charge.gd または draco_leap.gd（各回1つ）; 新 data/bosses/draco_moves/対応する技.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_action_rules.tres

## 15 三本爪と残る亀裂を通過・遮蔽まで接続

- [ ] 完了
- **依存**：09
- **受け入れ条件**：左右の爪にだけダメージを置く。残る亀裂は押出しと機体/両陣営の弾遮蔽を持ち、隙の後に修復する。
- **検証**：G・M・E・Dの該当範囲。生成時の重なり、爪だけ被弾、弾遮蔽、HP移行での閉鎖、次技に残らないことを確認。
- **主なファイル**：新 scripts/bosses/draco_rifts.gd; 新 data/bosses/draco_moves/rifts.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_action_rules.tres

### C6 移動攻撃と亀裂の中断を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 16 既存敵のピカロを生成して倒せるようにする

- [ ] 完了
- **依存**：09
- **受け入れ条件**：既存絵/行動を持つ敵を共通cosmic shaderで生成。星→膜→裂開→敵出現が判定開始と同期する。
- **検証**：G・M・E・Dの該当範囲。異なる行動の敵2種類以上で元行動・HP・shader共有と破棄を確認。候補全種類と除外設定の経路を用意する。
- **主なファイル**：新 scripts/bosses/draco_picaro.gd; 新 shaders/picaro.gdshader; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/draco.tres

## 17 初回生成・奥への採集・復帰を一巡する

- [ ] 完了
- **依存**：16
- **受け入れ条件**：初回のみ操作停止と黒帯。通常は全滅/時間で帰還し、再生成中に本体を攻撃できる。攻撃担当と深奥の非対象化が切り替わる。
- **検証**：G・M・E・Dの該当範囲。初回/2回目、全滅/時間、通常切替のビーム完了待ちとHP切替の即停止を確認。
- **主なファイル**：scripts/bosses/draco_picaro.gd; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_flow.tres; data/bosses/draco.tres

## 18 ピカロ壁と口からの光の矢を共同攻撃にする

- [ ] 完了
- **依存**：17
- **受け入れ条件**：矢は上へ連射→画面外→警告時の自機位置へ固定→縮む予告→小さな光の爆発。隊列と共有予算で攻撃できる。
- **検証**：G・M・E・Dの該当範囲。既存試作の不備を確認し、移動で回避・移行中の発射停止・既発射の残存・隊列攻撃との予算を確認。
- **主なファイル**：新 scripts/bosses/draco_picaro_wall.gd; scripts/attacks/cosmic_arrow.gd; scripts/render/attacks/cosmic_arrow.gd; 新 data/bosses/draco_moves/picaro_wall.tres; data/bosses/ai/draco_action_rules.tres

### C7 初回生成・担当切替・共同攻撃を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 19 本体と複製2体でHydra専用技を使う

- [ ] 完了
- **依存**：17
- **受け入れ条件**：本体込み3体、5系統から担当。各個体はHydra専用技だけを使い、順番の飛びかかりと別技分担が動く。複製独立HPと終了時回収を実装。
- **検証**：G・M・E・Dの該当範囲。5系統は1系統ずつ接続・確認する小タスクに展開。複製撃破で本体HPを減らさず、格子ビームを選ばない。
- **主なファイル**：新 scripts/bosses/draco_clones.gd; scripts/bosses/draco_boss.gd; 新 data/bosses/draco_moves/clones.tres; data/bosses/ai/draco_action_rules.tres; 必要時 scripts/bosses/hydra_normals.gd

## 20 吸引から吐出を弧の編集まで一巡する

- [ ] 完了
- **依存**：17
- **受け入れ条件**：ピカロの星数が直後1回の吐出だけを強化。複数の弧の数/半径/角度/配置を保存できる。口への到達は噛み→排出→操作復帰。
- **検証**：G・M・E・Dの該当範囲。吸収ゼロ/複数、次の吐出への持越し無し、排出中の保護、弧編集再読込を確認。実装は吸引一巡と弧編集の2小タスクへ分割。
- **主なファイル**：新 scripts/bosses/draco_inhale.gd; 新 data/bosses/draco_moves/inhale.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; tools/editor/boss_flow/editor.gd

### C8 複製と吸引吐出、弧の編集を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 21 螺旋収縮を回避・挟まれ演出まで試遊

- [ ] 完了
- **依存**：09
- **受け入れ条件**：初期自機位置を中心に2周し、隙から脱出できる。青紫の壁は弾を遮り、挟まれたら一度被弾→点滅無敵→竜が下へ離脱する。
- **検証**：G・M・E・Dの該当範囲。中心固定、逃げ道、接触と挟まり、共通無敵、移行取消を確認。初回は巻き/脱出、次に収縮/被弾を完成する。
- **主なファイル**：新 scripts/bosses/draco_spiral.gd; 新 data/bosses/draco_moves/spiral.tres; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; data/bosses/ai/draco_action_rules.tres

### C9 螺旋の逃げ道と挟まれ演出を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 22 HP0からこぐま座解放とモジュール合体へ進む

- [ ] 完了
- **依存**：09,16
- **受け入れ条件**：HP0で通常CLEARに入らず、核解放→咆哮→4モジュール合体が進む。戦闘操作とダメージを保護する。
- **検証**：G・M・E・Dの該当範囲。HP0への同時命中・残留攻撃・再入場で演出と報酬が二重起動しないことを確認。
- **主なファイル**：新 scripts/bosses/draco_finale.gd; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; scripts/runtime/run_simulation.gd; data/bosses/draco.tres

## 23 最終自由描画から固定演出を開始

- [ ] 完了
- **依存**：22
- **受け入れ条件**：世界速度0で長さ無制限・任意ガイドの入力ができ、離すと経路によらず固定フィニッシュへ進む。通常描画を変更しない。
- **検証**：G・M・E・Dの該当範囲。短い/長い線、入力解除、ポーズ/フォーカス復帰を確認。無入力時の扱いなど未決は着手時に相談。
- **主なファイル**：scripts/bosses/draco_finale.gd; scripts/runtime/run_simulation.gd; 新 scripts/ui/draco_final_input.gd; scripts/bosses/draco_presentation.gd

## 24 固定フィニッシュから共通クリア・保存へ接続

- [ ] 完了
- **依存**：23
- **受け入れ条件**：多方向貫通→寄る→引く→下から上へ貫通→強い光→視界回復→二つの竜→爆発→CLEAR/結果が進む。保存は一度。
- **検証**：G・M・E・Dの該当範囲。演出途中終了/再開、画面比率、終端イベントの重複、通常ボスCLEARの回帰を手動確認。
- **主なファイル**：scripts/bosses/draco_finale.gd; scripts/bosses/draco_presentation.gd; scripts/runtime/run_simulation.gd; 新 scenes/bosses/draco_presentation.tscn; data/bosses/draco.tres

### C10 HP0から結果保存までを確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 25 竜の全技を一戦のフローに接続

- [ ] 完了
- **依存**：10,11,12,13,14,15,18,19,20,21,24
- **受け入れ条件**：通常6技と主な7技が該当段階で使われる。区間候補・距離方向条件・共有予算が働き、残留物が中断規則に従う。
- **検証**：G・M・E・Dの該当範囲。各技の準備/攻撃/隙で70/40%とHP0へ移行。候補なし/残量不足/開始失敗から復帰。単独試遊と一戦を別確認。
- **主なファイル**：data/bosses/ai/draco_flow.tres; data/bosses/ai/draco_action_rules.tres; scripts/bosses/draco_boss.gd

### C11 竜の一戦と全技の移行・後始末を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 26 ステージ5の編成確認と8分の道中枠

- [ ] 完了
- **依存**：00
- **受け入れ条件**：直近の山編成表をユーザーと確認し正本へ反映。10区間が0〜480秒に並び、雑魚と育成の強敵が再生できる。
- **検証**：G・M・E・Dの該当範囲。時間配分を既決どおり照合。ボスを無効のまま保存→生成→途中再生。
- **主なファイル**：data/stages/stage_5.tres; data/formations/新s5育成編成（最大3シーン）; ../docs/game/stages/stage-5.md

## 27 山1・2と継続するカラスを試遊

- [ ] 完了
- **依存**：26
- **受け入れ条件**：合意した山1/2が動き、山2以降の育成でもカラスが継続。経験値の回収と取り返しが現行行動に沿う。
- **検証**：G・M・E・Dの該当範囲。区間境界で生存敵を無断消去しない。予算と補充を確認。竜へ運ぶ未実装挙動を今回完了と呼ばない。
- **主なファイル**：data/stages/stage_5.tres; data/formations/新s5山1・2・カラス編成（最大3シーン）

## 28 山3〜5の大物と段階的な圧力を試遊

- [ ] 完了
- **依存**：27
- **受け入れ条件**：ケフェウス/兵、わし、他強敵が合意編成で出現し、後半ほど強い山と育成の緩急がある。
- **検証**：G・M・E・Dの該当範囲。山3/4/5は1区間ずつ調整。分類・残留攻撃・valueと予算を確認し、種類数だけで難度を評価しない。
- **主なファイル**：data/stages/stage_5.tres; data/formations/各区間の新s5編成（1回最大3シーン）

### C12 道中の各山・育成と通常開始の成長を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 29 静かな星空から竜の一戦へ接続

- [ ] 完了
- **依存**：25,28
- **受け入れ条件**：道中→星空→裂け目/赤い目→北極星が光る胸→黒帯解除→戦闘→決着がつながる。構図は仮表示で差し替え可能。
- **検証**：G・M・E・Dの該当範囲。操作/カメラ/HP保護の引渡し、通常敵残留の扱い、boss_id/有効化、通常開始と途中試遊を確認。
- **主なファイル**：data/stages/stage_5.tres; 新 scripts/bosses/draco_entrance.gd; scripts/bosses/draco_boss.gd; scripts/bosses/draco_presentation.gd; scripts/runtime/run_simulation.gd

## 30 冒頭の北極星喪失から操舵へ接続

- [ ] 完了
- **依存**：00
- **受け入れ条件**：星空約3秒→影/捕食/赤い目/離脱→操作可能な航行約7〜8秒が進む。台詞は既存合意の少量。
- **検証**：G・M・E・Dの該当範囲。初回/再視聴/スキップ、操作解除直後の入力、画面比率、通常セーブ非汚染を確認。
- **主なファイル**：scripts/runtime/intro_sequence.gd; scripts/render/intro_visual.gd; scripts/ui/intro_screen.gd; scripts/data_types/intro_presentation.gd; scenes/app/intro.tscn

## 31 敵の生成からブースト体験・旅立ちへ接続

- [ ] 完了
- **依存**：30
- **受け入れ条件**：星と瓦礫から敵が現れ、既存の本番操作で倒すと星復元→一角獣の不穏な星空→旅立ちへ進む。
- **検証**：G・M・E・Dの該当範囲。操舵から描画/ブーストへの接続、未撃破で待つ、スキップ、再視聴、入力の残りを確認。
- **主なファイル**：scripts/runtime/intro_sequence.gd; scripts/runtime/intro_practice.gd; scripts/render/intro_visual.gd; scripts/ui/intro_screen.gd; scripts/ui/intro_overlay.gd

### C13 登場と冒頭・チュートリアルの接続を確認

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 32 編集往復と両ステージの完成条件を確認

- [ ] 完了
- **依存**：05,29,31
- **受け入れ条件**：SPECのS1〜E1を満たす証拠と未確認を分ける。共通値を勝手に変えず、正本と敵一覧を実装状況に揃える。
- **検証**：G・M・E・Dの該当範囲。文書/生成/読み込み・既存ボスの編集回帰・セーブ保護した人間試遊。全編自動プレイや自動テストは依頼時のみ。
- **主なファイル**：原則検証のみ。文書更新は対応するボス仕様・ステージ仕様・敵一覧を各小タスクと同時に行う

### C14 仮素材での制作範囲をユーザーにレビューしてもらう

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## 33 提供後の構図・ポーズを差し替える

- [ ] 完了
- **依存**：32, ユーザーの構図提供
- **受け入れ条件**：承認された構図だけを表示へ反映し、戦闘/入力進行を保つ。仮素材完成と正式見た目の完成を区別。
- **検証**：G・M・E・Dの該当範囲。登場/決着、画面比率、見切れ、当たり/遮蔽への影響を再確認。
- **主なファイル**：scripts/bosses/draco_presentation.gd; scenes/bosses/draco_presentation.tscn; data/bosses/draco.tres; 必要な正式素材（差し替えごとに分割）

### C15 正式構図の見た目をユーザーにレビューしてもらう

- [ ] 対象タスクの動作と編集反映を確認。未実施を明記。
- [ ] 残る仕様判断・不具合を提示し、進めてよい状態かレビュー。

## SPECとの対応

| 要件 | タスク |
|---|---|
| S1、M1〜M3 | 01〜05 |
| S5 | 26〜29 |
| D1、D2 | 06〜15、18、21、25 |
| D3、D4、D5 | 09、16〜20、25 |
| P1、P2 | 29〜31、33 |
| F1〜F3 | 22〜24 |
| E1 | 05、07〜08、各技、20、26〜29、32 |

計画・作業分割と自動実装は承認済み。テスト・ビルド・タスク単位のコミットを実施する。push・main統合は別途承認を得る。
