# ゲーム内文言

名前・説明・UI の翻訳文と、敵・英雄・ボスのリソース表示名の編集元。現行の本番文言を以下の表に置く。

## 編集と反映

日本語は分かりやすさを優先し、次に [世界観と用語](world.md) を合わせる。武器・特性の説明は効果と発動条件を短く書く。図鑑は効果の明快さに加えて世界観を伝える。名前は既存用語に沿う。

`keys`・管理 ID・言語列を保ち、名前も説明も該当セルを編集する。`{n}` などの置換名、`%s`・`%.1f` などの書式指定、全角空白、末尾空白を用途に合わせて保持する。翻訳表の空のキーは CSV の説明・見出しになる。

表のセルは通常の文章で書く。実際の改行は `<br>`、縦棒は `&#124;`、文字としての `<br>` は `&lt;br&gt;`、アンパサンドは `&amp;` とする。バックスラッシュは `&#92;`、Markdown の装飾記号は数値文字参照で表す。先頭・末尾の空白は `&#32;`（全角は `&#12288;`）、タブは `&#9;`、復帰文字は `&#13;` で保持する。文字参照は1回だけ復元する。Godot は CSV のバックスラッシュエスケープも現在の importer 設定で解釈する。

リポジトリのルートで、編集後に次を実行する。

```bash
python3 tools/generate_text.py
python3 tools/generate_text.py --check
python3 tools/check_docs.py
git diff -- docs/game/text.md speed/data/text/strings.csv speed/data/enemies speed/data/heroes speed/data/bosses
```

`--check` は生成先へ書き込まず、差分があれば diff と終了コード1を返す。CSV とリソース表示名は生成結果としてコミットする。Godot でプロジェクトを読み込むと、CSV importer が既存の日本語・英語の `.translation` を生成し、画面は既存の翻訳キーで読む。翻訳キャッシュは Git 管理から除外する。

生成対象は以下のマーカー内だけとする。採用前の案は文言案に置く。新しい敵・英雄・ボスを追加するときは、その `.tres` の `display_name` もリソース表示名の表へ登録する。データ編集画面で名前を試したら、採用する値をこの表へ戻して生成する。

## 翻訳文

<!-- csv:start -->
| keys | ja | en |
| --- | --- | --- |
|  | ゲーム中に表示する文章の生成データ。編集元は docs/game/text.md。ja 列が日本語、en 列が英語。設定の「言語」で切り替える。 |  |
|  | キーは「場所.項目」の形で、コードと画面がこのキーで文章を読む。武器・特性・伝説のモジュール・機体の強化は &lt;種類&gt;.&lt;ID&gt;.name と .desc（ID は .tres の id）、ステージは stage.&lt;番号&gt;.name。 |  |
|  | {n} などの波かっこは、ゲームが数値や名前に置き換える場所。両方の言語で同じ名前を使う。 |  |
|  | キーが空の行はこの説明と見出しで、ゲームは読まない。 |  |
|  | ■ 共通 |  |
| common.back | 戻る | Back |
| common.to&#95;main&#95;menu | メインメニューに戻る | Back to Main Menu |
| common.parts | 部品 {n} | Parts {n} |
|  | ■ タイトル・メインメニュー |  |
| menu.start | ゲームスタート | Start Game |
| menu.settings | 設定 | Settings |
| menu.quit | 終了 | Quit |
| menu.main&#95;menu | メインメニュー | Main Menu |
| menu.stage&#95;select | ステージ選択 | Stage Select |
| menu.enemy&#95;lab | 敵・ルート実験場（開発版） | Enemy &amp; Route Lab (Dev Build) |
| menu.upgrade | 機体の強化 | Ship Upgrades |
| menu.encyclopedia | 図鑑 | Codex |
|  | ■ 設定 |  |
| settings.volume | 音量 | Volume |
| settings.master&#95;volume | 全体の音量 | Master |
| settings.sfx&#95;volume | 効果音 | Sound Effects |
| settings.engine&#95;volume | エンジン音 | Engine |
| settings.mute | 消音（M キーでも切り替え） | Mute (also toggled with M) |
| settings.effects | 演出 | Effects |
| settings.screen&#95;shake | 画面の揺れ | Screen Shake |
| settings.hitstop | ヒットストップ（敵を倒したときなどに一瞬止まる） | Hit Stop (brief freeze on kills and critical hits) |
| settings.window&#95;mode | 画面モード | Display Mode |
| settings.windowed | ウィンドウ | Windowed |
| settings.fullscreen | フルスクリーン | Fullscreen |
| settings.exclusive | 排他フルスクリーン | Exclusive Fullscreen |
| settings.language | 言語 | Language |
| settings.language&#95;ja | 日本語 | 日本語 |
| settings.language&#95;en | English | English |
| settings.key&#95;bindings | キー設定（ボタンを押してから、割り当てるキーを押す） | Key Bindings (click a button, then press the key to assign) |
| settings.reset&#95;bindings | キー設定を初期値に戻す | Reset Key Bindings |
| settings.no&#95;key | （なし） | (None) |
| settings.press&#95;key | キーを押す… | Press a key… |
|  | ■ キー設定のアクション（action.&lt;アクション名&gt;） |  |
| action.draw&#95;alt | 描画の補助 | Draw (Assist) |
| action.hero | 英雄の星座の力 | Hero Constellation Power |
| action.pause | ポーズ | Pause |
| action.mute | 消音の切り替え | Toggle Mute |
| action.card&#95;1 | 3択の1枚目 | Card 1 |
| action.card&#95;2 | 3択の2枚目 | Card 2 |
| action.card&#95;3 | 3択の3枚目 | Card 3 |
| action.reroll | 3択の引き直し | Reroll Cards |
| action.debug&#95;panel | 調整パネル（開発版） | Tuning Panel (Dev Build) |
| action.debug&#95;perf | 性能の表示（開発版） | Performance Overlay (Dev Build) |
|  | ■ ステージ選択 |  |
| stage&#95;select.stage | ステージ {n}　{name} | Stage {n}  {name} |
| stage&#95;select.debug | 開発版：全ステージを選べます | Dev Build: All stages are available |
| stage&#95;select.locked | ステージ {n}　（前のステージをクリアすると選べる） | Stage {n}  (Clear the previous stage to unlock) |
| stage&#95;select.endless | エンドレス（準備中） | Endless (Coming Soon) |
| stage&#95;select.launch | 出撃 | Launch |
| stage&#95;select.available | 出撃可能 | Ready to launch |
|  | ■ ラン中（HUD・3択・ポーズ） |  |
| hud.draw | 描く | Draw |
| hud.kills | 撃破 {n} | Kills {n} |
| hud.bonus | ボーナスステージ　残り {n} 秒 | Bonus Stage  {n}s Left |
| hud.warning | WARNING!! | WARNING!! |
| hud.hero&#95;discovered | 英雄の星座を発見 | Hero constellation discovered |
| hud.clear | CLEAR! | CLEAR! |
| hud.game&#95;over | GAME OVER | GAME OVER |
| hud.levelup&#95;title | レベルアップ　1枚選ぶ（クリック／1〜3） | Level Up: Pick One (Click / 1–3) |
| hud.level&#95;bonus | おまけ | Bonus |
| hud.level&#95;bonus&#95;more | 継続！ | More! |
| hud.ult&#95;granted | 英雄の力を授かった | ULT ACQUIRED |
| hud.ult&#95;placeholder | 仮カットイン · 正式素材へ差し替え予定 | PLACEHOLDER CUT-IN · ART PENDING |
| hud.ult&#95;key | {key}：英雄の星座の力を発動 | {key}: Activate constellation power |
| hero.leo.power | 線が太くなる | Wider Line |
| hero.leo.desc | 線が太くなり、帯に触れた敵を装甲に関係なく貫く。 | Widen the line and pierce enemies in its path regardless of armor. |
| hero.perseus.power | メドゥーサの首 | Medusa's Head |
| hero.perseus.desc | 画面の中の敵（ボスと障害物のほか）と敵の弾を石にする。石は触れると砕ける。ボスは短時間止まる。 | Petrify enemies (except bosses and obstacles) and hostile shots on screen. Touch stone to shatter it. Bosses stop briefly. |
| hero.gemini.power | 線を2本 | Two Lines |
| hero.gemini.desc | 線を2本描き、機体と双子が同時に駆け抜ける。 | Draw two lines. Your ship and its twin dash along them together. |
| hero.hercules.power | 火の隕石 | Fiery Meteors |
| hero.hercules.desc | 機体の周りに火の隕石を落とし、落ちた跡を燃やす。 | Drop fiery meteors around the ship and leave burning ground. |
| hud.skip&#95;finish | 演出をスキップ | Skip sequence |
| hud.continuation | モジュール連続強化 | CONSECUTIVE UPGRADE |
| hud.continuation&#95;count | {n} 連続！ | {n} CHAIN! |
| hud.continuation&#95;next | クリックで進む | Click to proceed |
| hud.start&#95;title | 最初の武器を1つ選ぶ（クリック／1〜3） | Choose Your First Weapon (Click / 1–3) |
| hud.reroll | リロール（残り {n} 回）　{key} | Reroll ({n} Left)  {key} |
| hud.pause | ポーズ | Paused |
| hud.resume | 続ける | Resume |
| hud.quit&#95;run | メインメニューに戻る（このランは残らない） | Back to Main Menu (This Run Is Lost) |
| hud.swap&#95;title | 入れ替えて手放す武器を選ぶ | Choose a Weapon to Replace |
| card.new&#95;weapon | 新しい武器 | New Weapon |
| card.new&#95;trait | 新しい特性 | New Trait |
| card.weapon&#95;up | 武器強化 | Weapon Upgrade |
| card.trait&#95;up | 特性強化 | Trait Upgrade |
| card.first&#95;weapon | 最初の武器 | First Weapon |
| card.heal&#95;tag | 回復 | Repair |
| card.heal&#95;name | 緊急修理 | Emergency Repair |
| card.heal&#95;desc | HP を 30% 回復 | Restores 30% HP |
| card.swap&#95;tag | 入れ替える | Replace |
| card.swap&#95;desc | この武器を外して、{name}を付ける | Remove this weapon and equip {name} |
| card.keep&#95;tag | 見送る | Skip |
| card.keep&#95;name | 今の装備を残す | Keep Current Loadout |
| card.keep&#95;desc | {name}は受け取らない | Leave {name} behind |
|  | ■ 結果 |  |
| result.title | 結果 | Results |
| result.cleared | クリア | Cleared |
| result.failed | 失敗 | Failed |
| result.retry | もう一回やる | Play Again |
| result.stage | ステージ {n} | Stage {n} |
| result.time | 時間　{time} | Time  {time} |
| result.kills | 撃破　{n} | Kills  {n} |
| result.level | レベル　{n} | Level  {n} |
| result.peak&#95;speed | 最高速度　{speed} km/s | Top Speed  {speed} km/s |
| result.parts | 獲得した部品　{n} | Parts Earned  {n} |
| result.legendary | 手に入れた伝説のモジュール　{name} | Legendary Module Found  {name} |
| result.fastest | 最速クリア　{time} | Fastest Clear  {time} |
|  | ■ 機体の強化 |  |
| upgrade.row | {name}　{desc}　（{lv} / {max}） | {name}  {desc}  ({lv} / {max}) |
| upgrade.buy | 強化（部品 {n}） | Upgrade ({n} Parts) |
| upgrade.max | 最大 | Maxed |
| upgrade.select&#95;part | パーツを選択 | Select a part |
| upgrade.action | 強化 | Upgrade |
| upgrade.price | 必要部品：{n} | Cost: {n} Parts |
| upgrade.details | {desc}　（{lv} / {max}） | {desc}  ({lv} / {max}) |
| upgrade.part.atk | パワースパイク | Power Spike |
| upgrade.part.hp | フレーム強度 | Frame Strength |
| upgrade.part.charge | 充電効率 | Charge Efficiency |
| upgrade.part.xp | 学習回路 | Learning Circuit |
| upgrade.part.length | エンジンタンク | Engine Tank |
| upgrade.part.pickup | コレクター | Collector |
| upgrade.part.speed | ブースター | Booster |
| upgrade.part.reroll | 演算予備 | Spare Processor |
|  | ■ 図鑑 |  |
| codex.title | 図鑑　（{known} / {total}） | Codex  ({known} / {total}) |
| codex.weapons | 武器 | Weapons |
| codex.traits | 特性 | Traits |
| codex.legendary | 伝説のモジュール | Legendary Modules |
| codex.unknown | 未入手 | Undiscovered |
| codex.unknown&#95;name | ？？？ | ??? |
| codex.unknown&#95;detail | まだ手に入れていない | Not obtained yet. |
| codex.art&#95;custom | 専用ビジュアル | Artwork |
| codex.art&#95;placeholder | 仮ビジュアル（専用素材未設定） | Placeholder (No Artwork Yet) |
| codex.art&#95;effect | 効果イメージ | Effect Preview |
|  | ■ 武器（weapon.&lt;ID&gt;） |  |
| weapon.W01.name | ブラスター | Blaster |
| weapon.W01.desc | 進む向きへ自動で撃つ。Lv で威力・連射・弾数・貫通が伸びる | Fires automatically in your heading. Levels raise damage, fire rate, shot count and piercing. |
| weapon.W02.name | 散弾砲 | Scattergun |
| weapon.W02.desc | 進む向きへ扇状に撃つ。群れに向けて進むとまとめて当たる | Fires a spread in your heading. Fly at a swarm to hit many at once. |
| weapon.W03.name | 吹き飛ばし衝角 | Knockback Ram |
| weapon.W03.desc | 高速で触れた敵を進む向きへ吹き飛ばし、ほかの敵にぶつける | Enemies you touch at high speed are knocked forward into other enemies. |
| weapon.W04.name | 接触波動 | Contact Wave |
| weapon.W04.desc | 高速で敵に触れるたび、周りへ波動。弾かれた接触でも出る | Every high-speed contact sends out a wave. Works even when you bounce off. |
| weapon.W05.name | バリアシステム | Barrier System |
| weapon.W05.desc | 周りに定期的な波動を出し、敵の弾を防ぐ | Emits waves around you at intervals and blocks enemy shots. |
| weapon.W06.name | 追走ドローン | Chaser Drones |
| weapon.W06.desc | 周りを回って撃ち、駆け抜けた線を遅れて追って触れた敵も攻撃する | Orbit and shoot, then trail your dash line and strike enemies they touch. |
| weapon.W07.name | 軌跡機雷 | Trail Mines |
| weapon.W07.desc | 高速で実際に通った線に機雷を残す。遅れて入った敵を爆破 | Leaves mines along the line you flew at high speed. Blasts enemies that wander in. |
| weapon.W08.name | ソニックブーム | Sonic Boom |
| weapon.W08.desc | 駆け抜け始めと一定間隔で、進路ごと大きな衝撃波 | A huge shockwave along your path when a dash starts and at regular intervals. |
| weapon.W17.name | 接触電撃 | Contact Arc |
| weapon.W17.desc | 敵に触れると、周りの敵へ電撃が枝分かれして広がる。Lv ごとにつながる数が増える | Touching an enemy branches lightning out to surrounding enemies. Each level reaches more. |
| weapon.W21.name | 質量牽引砲 | Mass Tow Cannon |
| weapon.W21.desc | なぞり中に機体の近くで倒れた敵の船体を牽引し、なぞり終えると進む向きへ次々と撃ち出す | Tows the hulls of enemies defeated near your ship mid-dash, then fires them ahead one by one when the dash ends. |
| weapon.W22.name | 双極ビーム | Bipolar Beam |
| weapon.W22.desc | なぞり始めに発射器を残し、なぞり終えると機体との間を太いビームで貫く | Leaves an emitter where your dash starts, then cuts a thick beam between it and your ship when the dash ends. |
| weapon.W23.name | 後方ブラスター | Rear Blaster |
| weapon.W23.desc | 機体の後ろへ自動射撃。Lv2・5で弾数、Lv3で連射速度、Lv4で威力が上昇 | Fires automatically behind you. Lv2 and Lv5 add shots, Lv3 raises fire rate, Lv4 raises damage. |
| weapon.W24.name | 光の槍 | Light Lance |
| weapon.W24.desc | 突進中に機体が光の槍へ変わり、正面の敵に追加直撃。Lvで前方の長さと威力が伸びる | Become a lance of light during a dash and deal an extra direct hit ahead. Levels extend its reach and damage. |
| weapon.W25.name | 迎撃ドローン | Interceptor Drones |
| weapon.W25.desc | 周回編隊から近くの敵へ制御弾を撃ち、押し返して突進の余地を作る。Lvで機数と連射が増える | Orbiting escorts fire control rounds at nearby enemies, pushing them back to open space for a dash. Levels add drones and bursts. |
| weapon.W26.name | 突進範囲ドローン | Dash Range Drones |
| weapon.W26.desc | 突進時に左右へ編隊を展開し、横の敵まで貫く。Lvで機数と編隊幅、光跡が成長 | Deploy a formation beside the ship during a dash to pierce enemies across a wider path. Levels add drones, width, and longer light trails. |
| weapon.W27.name | 残像機 | Afterimage |
| weapon.W27.desc | 光の分身が突進軌道を追撃。Lvで機数と合計追撃威力が増える | Light echoes retrace your dash with a delay, sharing a portion of normal ram damage. Levels increase echo count and total follow-up damage. |
|  | ■ 特性（trait.&lt;ID&gt;） |  |
| trait.T01.name | 終端爆縮 | End Implosion |
| trait.T01.desc | 線の終点で爆発 | Explodes at the end of your line. |
| trait.T03.name | 余韻の渦 | Lingering Vortex |
| trait.T03.desc | 線の終点に、敵を吸い寄せる渦 | Leaves a vortex at the end of your line that pulls enemies in. |
| trait.T04.name | 満タン突撃 | Full-Charge Assault |
| trait.T04.desc | 満タンから使うと、装甲を無視して威力も上がる | Starting from a full gauge ignores armor and boosts damage. |
| trait.T05.name | 連鎖ソニック | Chain Sonic |
| trait.T05.desc | 1回で何体も倒すと衝撃波 | Defeating many enemies in one line releases a shockwave. |
| trait.T06.name | クリティカルランス | Critical Lance |
| trait.T06.desc | クリティカルのたびに前方へ貫くビーム | Every critical hit fires a piercing beam forward. |
| trait.T07.name | 急速充填 | Quick Charge |
| trait.T07.desc | ゲージが早く溜まる（充填速度 +25% ずつ） | The gauge fills faster (+25% charge speed each). |
| trait.T08.name | 大容量チャージ | High-Capacity Charge |
| trait.T08.desc | 1回で描ける長さが伸びる（容量 +20% ずつ） | Draw longer lines in one go (+20% capacity each). |
| trait.T09.name | クリティカル率 | Critical Rate |
| trait.T09.desc | 体当たりのクリティカルが出やすくなる（+5% ずつ） | Ram critical hits happen more often (+5% each). |
| trait.T10.name | 最高速度 | Top Speed |
| trait.T10.desc | 速くなり、描ける長さも伸びる（+12% ずつ） | Fly faster and draw longer lines (+12% each). |
| trait.T11.name | 攻撃力 | Attack Power |
| trait.T11.desc | すべての攻撃が強くなる（+20% ずつ） | All attacks get stronger (+20% each). |
| trait.T12.name | 広域回収 | Wide Pickup |
| trait.T12.desc | 遠くのアイテムも拾える（回収範囲 +30% ずつ） | Collect items from farther away (+30% pickup range each). |
| trait.T13.name | 反応波動 | Reactive Wave |
| trait.T13.desc | ダメージを受けたとき、周りを押し返す | Pushes nearby enemies away when you take damage. |
| trait.T14.name | 軌跡延長 | Trail Extension |
| trait.T14.desc | 描ける長さが伸びる（+25% ずつ） | Draw longer lines (+25% each). |
| trait.T31.name | 高速持続 | Extended Glide |
| trait.T31.desc | 突進後の高速状態が長く続く | Stay fast longer after a dash. |
|  | ■ 伝説のモジュール（legendary.&lt;ID&gt;） |  |
| legendary.legendary&#95;compass.name | 羅針盤のモジュール | Compass Module |
| legendary.legendary&#95;compass.desc | らしんばん座を解放したときに残された、錆びついたモジュール。 | A rusted module left behind when Pyxis was freed. |
| legendary.legendary&#95;keel.name | 竜骨のモジュール | Keel Module |
| legendary.legendary&#95;keel.desc | りゅうこつ座を解放したときに残された、錆びついたモジュール。 | A rusted module left behind when Carina was freed. |
| legendary.legendary&#95;sail.name | 帆のモジュール | Sail Module |
| legendary.legendary&#95;sail.desc | ほ座を解放したときに残された、錆びついたモジュール。 | A rusted module left behind when Vela was freed. |
| legendary.legendary&#95;stern.name | 船尾のモジュール | Stern Module |
| legendary.legendary&#95;stern.desc | とも座を解放したときに残された、錆びついたモジュール。 | A rusted module left behind when Puppis was freed. |
|  | ■ 機体の強化（meta.&lt;ID&gt;） |  |
| meta.atk.name | 衝角素材 | Ram Plating |
| meta.atk.desc | 攻撃力 +6% | Attack +6% |
| meta.charge.name | 充電効率 | Charge Efficiency |
| meta.charge.desc | ゲージの充填時間 -5% | Gauge charge time -5% |
| meta.hp.name | 機体フレーム | Hull Frame |
| meta.hp.desc | 最大 HP +20 | Max HP +20 |
| meta.pickup.name | 回収装置 | Collector |
| meta.pickup.desc | 回収範囲 +15% | Pickup range +15% |
| meta.reroll.name | 演算予備 | Spare Processor |
| meta.reroll.desc | 3択のリロール +1回 | Card rerolls +1 |
| meta.speed.name | 主推進器 | Main Thruster |
| meta.speed.desc | 最高速度 +5% | Top speed +5% |
| meta.xp.name | 学習回路 | Learning Circuit |
| meta.xp.desc | 経験値 +8% | XP +8% |
| meta.length.name | エンジンタンク | Engine Tank |
| meta.length.desc | 線の長さ +5% | Line length +5% |
|  | ■ ステージ（stage.&lt;番号&gt;） |  |
| stage.1.name | いっかくじゅう座の星系 | Monoceros System |
| stage.2.name | ケンタウルス座の星系 | Centaurus System |
| stage.3.name | おおいぬ座の星系 | Canis Major System |
| stage.4.name | うみへび座の星系 | Hydra System |
| stage.5.name | 元凶の待つ星系 | Where the Source Awaits |
| lab.message&#95;7474db4292 | 線には2点以上必要です | A route needs at least two points |
| lab.message&#95;26fa279ba2 | 出現 | Spawns |
| lab.message&#95;63d8f43c5b | 攻撃 | Attacks |
| lab.message&#95;1c155a99a1 | 被弾 | Damage |
| lab.message&#95;c3775f8a58 | 撃破 | Kills |
| lab.message&#95;72f1cf759c | 条件 | Conditions |
| lab.message&#95;d7d7ce790b | 配置 | Layout |
| lab.message&#95;fadf24dbc5 | 保存 | Files |
| lab.message&#95;fc23b9c287 | 変更はこの実験に適用されます。初期条件へ戻る操作は新しい実験です。 | Changes apply to this experiment. New experiment resets the initial conditions. |
| lab.message&#95;9e4c412d75 | 試遊中の無敵 | Invincible while playing |
| lab.message&#95;d79714f205 | 充填率 | Charge |
| lab.message&#95;cdff100dfe | 自機を表示中心へ移動・充填 | Move ship to view center and charge |
| lab.message&#95;c66777f550 | ステージ経過（実秒） | Stage time (real seconds) |
| lab.message&#95;54036730a6 | ステージ時計へ適用 | Set stage clock |
| lab.message&#95;568b393d89 | 復元した通常の出現 | Original stage roster |
| lab.message&#95;df7c5eeb44 | 追加版の出現（実験のみ） | Added roster (lab only) |
| lab.message&#95;ace6599b1c | 出現の時間帯を切替 | Switch phase roster |
| lab.message&#95;0c0e2d79f0 | 基礎攻撃力 | Base attack |
| lab.message&#95;0aee0183fd | 最高速度 | Maximum speed |
| lab.message&#95;017dfdb22a | 線の長さ | Drawing length |
| lab.message&#95;ec7bdd3fb0 | なぞりの当たり判定の太さ | Trace hit width |
| lab.message&#95;355273af8a | 描画中の世界の速さ | World speed while drawing |
| lab.message&#95;ab276f5393 | 描画の確定待ち時間 | Drawing confirmation delay |
| lab.message&#95;6384a9a6f0 | ボスの基礎HP | Boss base HP |
| lab.message&#95;391c98f217 | ボスの基礎装甲 | Boss base armor |
| lab.message&#95;761cc8db45 | 機体の強化レベル | Ship upgrade level |
| lab.message&#95;c2080e1bd3 | 機体の強化を適用 | Apply ship upgrade |
| lab.message&#95;6f0f16e0c0 | 武器 | Weapon |
| lab.message&#95;b62ed716e3 | 特性 | Trait |
| lab.message&#95;5c146b19a7 | 装備レベル | Equipment level |
| lab.message&#95;030e3f7f9b | 装備に追加 | Add equipment |
| lab.message&#95;c1f482ed04 | 装備を解除 | Clear equipment |
| lab.message&#95;7a50a34743 | 英雄なし | No hero |
| lab.message&#95;3b8a4d49ef | 英雄を発動 | Activate hero |
| lab.message&#95;e52adaaa4c | 追加版の分裂設定を適用 | Apply added splitter variant |
| lab.message&#95;e2074e817f | 攻撃の優先度管理を使う | Manage attack priorities |
| lab.message&#95;f4a90d8530 | 全体の重み付き上限 | Total weighted budget |
| lab.message&#95;e25e93d055 | 狙い弾 | Aimed shots |
| lab.message&#95;bbcc068b7e | 誘導弾 | Homing shots |
| lab.message&#95;437d9cf8d0 | 突進 | Dashes |
| lab.message&#95;421607de84 | ビーム | Beams |
| lab.message&#95;1133c374e7 | 遅延範囲 | Delayed areas |
| lab.message&#95;f3482a22c0 | 広がる輪 | Expanding waves |
| lab.message&#95;c04c40391d | 残留範囲 | Lingering areas |
| lab.message&#95;61bf2700ce | 枠 | Slots |
| lab.message&#95;d0fdf2aa39 | 重み | Weight |
| lab.message&#95;c7f2b1e003 | 間隔 | Gap |
| lab.message&#95;1a59dadeb6 | 表示中の敵を優先し、待った時間で優先度を上げます。攻撃元から残った弾・範囲への線をフィールドに表示します。 | Visible enemies get priority; waiting raises it. Lines connect attackers to their remaining shots and areas. |
| lab.message&#95;dc8d5ae40c | パレットで選んだ敵を、表示中心へ指定した時間から繰り返し出します。 | Repeat the selected enemy at the view center during the chosen time range. |
| lab.message&#95;5fdbd8f764 | 開始（実秒） | Start (real seconds) |
| lab.message&#95;51b9d6157a | 終了（実秒） | End (real seconds) |
| lab.message&#95;274c228534 | 間隔（実秒） | Interval (real seconds) |
| lab.message&#95;7c4fd18609 | 出現レーンに追加 | Add spawn lane |
| lab.message&#95;25c440c98a | 選択したレーンを削除 | Delete selected lane |
| lab.message&#95;0113c8102f | すべてのレーンを止める | Stop all lanes |
| lab.message&#95;d144e6855f | 線を描く時間（実秒） | Drawing duration (real seconds) |
| lab.message&#95;2fcfd99d3b | ルートに残す余裕幅 | Route clearance |
| lab.message&#95;e10ded50d8 | 開始時間の幅（対応モデルのみ） | Start window (supported models) |
| lab.message&#95;f7df32cd04 | 静止配置の掃引を確認 | Check static swept route |
| lab.message&#95;fb60080a99 | 描いた線を隔離して再生 | Replay route in isolation |
| lab.message&#95;6cc4ba4282 | 認証した開始時間幅を保護 | Protect certified start window |
| lab.message&#95;65f985536b | 対応モデルで開始時間幅を確認してから有効にしてください | Certify a supported start window before enabling protection. |
| lab.message&#95;47a613a504 | 指定した時間幅の間、新しい攻撃と自動出現を見送ります | New attacks and automatic spawns are deferred during the specified window. |
| lab.message&#95;93025fc5b1 | 線を比較対象として複製 | Duplicate route for comparison |
| lab.message&#95;0a50b49bd2 | 敵が動いてよい領域の半径 | Placement region radius |
| lab.message&#95;4855e0d71e | 現在の配置を生成規則にする | Capture layout as a generation rule |
| lab.message&#95;277d733b3c | 領域の中心をドラッグ。Alt＋ドラッグで半径。ルートを変えると規則を再取得してください。 | Drag a region center; Alt-drag changes its radius. Capture again after changing the route. |
| lab.message&#95;facbd979fc | 貫く群れ | Fodder to pierce |
| lab.message&#95;098b17ccc2 | 避ける対象 | Objects to avoid |
| lab.message&#95;1dafdf40bb | 選んだ領域の最小数 | Selected region minimum count |
| lab.message&#95;482249e12a | 選んだ領域の最大数 | Selected region maximum count |
| lab.message&#95;21716b1b31 | 選んだ領域の種類・役割・数を変更 | Apply selected enemy, role and counts |
| lab.message&#95;6ffb4b865c | ランダムに回す角度（度） | Random rotation (degrees) |
| lab.message&#95;2abddd7072 | 長さの最小倍率 | Minimum length scale |
| lab.message&#95;66086de6d6 | ルート上で貫く弱い敵の最小数 | Minimum fodder on route |
| lab.message&#95;d8cfb525ed | ランダム候補を3つ生成 | Generate three random candidates |
| lab.message&#95;a19b200d4f | 先に配置を生成規則にしてください | Capture a generation rule first. |
| lab.message&#95;f90284f87e | 選んだ候補を配置に追加 | Add selected candidate |
| lab.message&#95;4499d20c4e | 実験名 | Experiment name |
| lab.message&#95;3e46ee4fc1 | 配置・条件のプリセットを保存 | Save layout and condition preset |
| lab.message&#95;0a6f61cf06 | 再生履歴と分岐を保存 | Save replay and branches |
| lab.message&#95;c1df88bfc2 | JSONを読み込む | Load JSON |
| lab.message&#95;e419196088 | 本番へ反映する対象（書き出しに明記） | Production targets (included in export) |
| lab.message&#95;b8d712fc9b | 対象ステージ | Target stage |
| lab.message&#95;82b885c33d | 時間帯を限定しない | All phases |
| lab.message&#95;e98240632d | AI用フォルダを書き出す | Export folder for AI |
| lab.message&#95;5da55226e3 | 書き出しは敵の差分、配置規則、攻撃枠、再現条件、画像をまとめます。通常ステージへの採用は対象を指定して反映します。 | Export includes definition changes, placement rules, attack limits, replay conditions and images. Specify targets when adopting changes in normal stages. |
| lab.message&#95;5931a7be25 | 指定した探索範囲で候補を発見できませんでした | No candidate found within the search limits. |
| lab.message&#95;7b47f8fa60 | ルートを検証中 %d%% | Evaluating route %d%% |
| lab.message&#95;0db4675b27 | 候補を検査中 %d | Checking candidate %d |
| lab.message&#95;7591fff9f2 | 再構築中 %d%% | Reconstructing %d%% |
| lab.message&#95;60a1005be6 | 戻る | Back |
| lab.message&#95;922c39d8ac | 敵・ルート実験場 | Enemy &amp; Route Lab |
| lab.message&#95;c83172920b | ステージ %d | Stage %d |
| lab.message&#95;528e1c7048 | 空のフィールド | Empty field |
| lab.message&#95;bb051fda3b | 通常の自動出現 | Normal automatic spawns |
| lab.message&#95;dfa32d64eb | 新しい実験 | New experiment |
| lab.message&#95;bf1c2f34ef | ▶ 再生 | ▶ Play |
| lab.message&#95;2555a92b57 | ❚❚ 停止 | ❚❚ Pause |
| lab.message&#95;87b386148b | 1コマ | Step |
| lab.message&#95;e2ff3a1576 | 最初の時刻へ戻す（配置は残す） | Back to the start (keep placements) |
| lab.message&#95;8e4350198b | 選択・移動 | Select / move |
| lab.message&#95;7b82dc2a06 | 敵を配置 | Place enemies |
| lab.message&#95;096f45921a | 線を編集 | Edit route |
| lab.message&#95;605c5bd311 | 自機で試遊 | Play as ship |
| lab.message&#95;685d3cd5a7 | 線を消す | Clear route |
| lab.message&#95;31c4ccdbbf | 線の結果を確認 | Evaluate route |
| lab.message&#95;67847e89ae | 中止 | Cancel |
| lab.message&#95;97c3c6246b | 敵を消す | Clear enemies |
| lab.message&#95;fb93512f75 | 攻撃範囲 | Attack ranges |
| lab.message&#95;19e1e846a4 | 敵の名前・IDで検索 | Search enemy name or ID |
| lab.message&#95;da1f520c6f | 数 | Count |
| lab.message&#95;4db93d1888 | 選択情報 | Selection |
| lab.message&#95;69a0de30fa | 実験設定 | Experiment |
| lab.message&#95;e2160dc29a | 編集中：線の結果を確認してください | Editing: evaluate the route again. |
| lab.message&#95;c811c512d0 | 敵パレット | Palette |
| lab.message&#95;2041b03309 | 情報パネル | Inspector |
| lab.message&#95;25446d5b84 | 線編集：クリックで点を追加、点をドラッグ、右クリックで最後の点を削除 | Route: click to add, drag to move, right-click a point to delete. |
| lab.message&#95;787af9549a | 中ボタン：移動　ホイール：拡大縮小　配置してから再生してください | Middle-drag to pan; wheel to zoom. Place enemies, then play. |
| lab.message&#95;2e31753d0b | %s　%s<br>選択してフィールドをクリック | %s  %s<br>Select, then click the field |
| lab.message&#95;bd3455e23b | 通常 | Normal |
| lab.message&#95;cab5ef8006 | ボス | Boss |
| lab.message&#95;0033dbf5f7 | 調整待ち | To tune |
| lab.message&#95;e6152035cf | %s<br>%s ・%s | %s<br>%s / %s |
| lab.message&#95;30308e98b5 | ：配置する位置をクリック | : click to place |
| lab.message&#95;992b3b0d94 | 敵を選択してドラッグ移動 | Select an enemy and drag to move |
| lab.message&#95;d01d58488a | 配置する位置をクリック | Click a placement position |
| lab.message&#95;6959dce1bf | 線の点を追加・移動して結果を確認 | Add or move route points, then evaluate |
| lab.message&#95;e032c78766 | 通常の描画操作で試遊。再生を押してください | Use normal drawing controls. Press Play to begin. |
| lab.message&#95;549e9c3c03 | 分岐 %d | Branch %d |
| lab.message&#95;9ec7700849 | 静止配置で成立 | Valid in static layout |
| lab.message&#95;0df05349ff | 指定時間幅で成立 | Valid within the specified window |
| lab.message&#95;af33e7e17b | 時間幅の評価モデルが未対応 | Time-window model unsupported |
| lab.message&#95;3aee526f77 | この条件で成立する候補は未確認 | No valid candidate confirmed for these conditions |
| lab.message&#95;aa259c678f | 線の条件を確認 | Check route conditions |
| lab.message&#95;dd16bfc556 | この再生条件で成立 | Valid for this replay |
| lab.message&#95;b8f8f95d8c | この再生では終点到達・無被弾の条件を未達 | Endpoint or no-damage condition not met in this replay |
| lab.message&#95;94deee7e2e | 再確認が必要 | Recheck required |
| lab.message&#95;68dc5e1c46 | 編集中 | Editing |
| lab.message&#95;511972b218 | &#12288;撃破 %d　被ダメージ %.1f　残り充填 %.2f | &#32;&#32;Kills %d  Damage %.1f  Charge %.2f |
| lab.message&#95;198ce2dd32 | &#12288;衝突・未確認 %d箇所　余裕幅 %.0f | &#32;&#32;Collisions / unconfirmed %d  Clearance %.0f |
| lab.message&#95;c93b3203d0 | 線%d　%s　撃破%d | Route %d  %s  Kills %d |
| lab.message&#95;82b17798e4 | 候補%d　%s　Seed%d | Candidate %d  %s  Seed %d |
| lab.message&#95;e3178fc873 | 候補を選ぶと線と出現位置を重ねて表示します | Select a candidate to overlay its route and positions. |
| lab.message&#95;4949196244 | 候補が古いか未成立です。生成し直してください | Candidate is stale or invalid. Generate it again. |
| lab.message&#95;e104208879 | 保存できませんでした：%s | Could not save: %s |
| lab.message&#95;edf19cb8e9 | &#42;.json ; 実験のJSON | &#42;.json ; Experiment JSON |
| lab.message&#95;10ccd95682 | 基準データが違います。結果の再確認が必要です | Baseline differs. Re-evaluate the results. |
| lab.message&#95;0d4f7fc305 | 読み込みました | Loaded |
| lab.message&#95;6d49e93edd | 書き出しました： | Exported:&#32; |
| lab.message&#95;f6f81b6554 | 書き出しに失敗： | Export failed:&#32; |
| lab.message&#95;c2ddab60b8 | ❚❚ 再生中 | ❚❚ Playing |
| lab.message&#95;15d10dbb3a | %.2f 秒 / %.2f 秒　世界 %.2f 秒　敵 %d体　Seed %d | %.2f s / %.2f s  World %.2f s  Enemies %d  Seed %d |
| lab.message&#95;98f82d7b9f | 現在の分岐 | Current branch |
| lab.message&#95;91f8bdc328 | 再確認が必要：配置・装備・時間が変わっています | Recheck required: layout, equipment or time changed. |
| lab.message&#95;87b29ea1a5 | ファイルを読み込めません（上限16MB） | Cannot read file (16 MB limit). |
| lab.message&#95;d2cbd5f4c9 | JSON の形式を確認してください | Check the JSON format. |
| lab.message&#95;5aa5077c96 | 対応していない記録の版・種類です | Unsupported record version or kind. |
| lab.message&#95;03af38d54f | 初期条件・履歴の形式が違います | Invalid initial conditions or history format. |
| lab.message&#95;5411903cfb | 記録の上限を超えています | Record exceeds limits. |
| lab.message&#95;516be31176 | 未知の初期条件： | Unknown initial condition:&#32; |
| lab.message&#95;da5e2e784c | 未知のステージです | Unknown stage. |
| lab.message&#95;5023536a4b | 初期条件の形式が違います： | Invalid initial condition format:&#32; |
| lab.message&#95;c6f64ef280 | 自機の位置が不正です | Invalid ship position. |
| lab.message&#95;dcb428f285 | 装備のID・レベルが不正です | Invalid equipment ID or level. |
| lab.message&#95;97502315d3 | 線の形式・上限を確認してください | Check route format and point limit. |
| lab.message&#95;275c3dbb23 | 線の座標が不正です | Invalid route coordinates. |
| lab.message&#95;1ea25ab8b0 | 配置規則の形式が違います | Invalid placement rule format. |
| lab.message&#95;3b1b000e8b | 未知の調整値： | Unknown tuning value:&#32; |
| lab.message&#95;3fc0d7300b | 未知の敵： | Unknown enemy:&#32; |
| lab.message&#95;8cfee97b22 | 変更できない敵の項目： | Enemy property cannot be changed:&#32; |
| lab.message&#95;8c395a3b3b | 分岐の形式が違います | Invalid branch format. |
| lab.message&#95;2fa6cacf94 | 未知の命令・形式です | Unknown command or format. |
| lab.message&#95;884b1ef739 | 命令の時刻が範囲外です | Command time is out of range. |
| lab.message&#95;2a897624ac | 命令の位置が不正です | Invalid command position. |
| lab.message&#95;c547a6d3c5 | 入力の座標が不正です | Invalid input coordinates. |
| lab.message&#95;6b1292dfc2 | 敵の値が不正です | Invalid enemy value. |
| lab.message&#95;6d6845a8d1 | 命令の数値が不正です | Invalid command number. |
| lab.message&#95;e4cadb1cab | 許可していないラン命令です | Run command is not allowed. |
| lab.message&#95;3313855ba5 | 出現レーンの形式・上限を確認してください | Check spawn lane format and limits. |
| lab.message&#95;e33e75d642 | 出現レーンの形式が違います | Invalid spawn lane format. |
| lab.message&#95;f9993c711a | 出現レーンに未知の敵があります | Unknown enemy in spawn lane. |
| lab.message&#95;bb508ec943 | 出現位置の形式が違います | Invalid spawn position format. |
| lab.message&#95;b58910d240 | 出現レーンの数値が不正です | Invalid spawn lane number. |
| lab.message&#95;94331992ec | 出現間隔には正の値が必要です | Spawn interval must be positive. |
| lab.message&#95;1f862285cc | 定義の形式が違います | Invalid definition format. |
| lab.message&#95;3c66a49d71 | 未知の敵・定義です | Unknown enemy or definition. |
| lab.message&#95;2dac0fe5e5 | 攻撃の値の形式が違います | Invalid attack parameter format. |
| lab.message&#95;7241f95e31 | 未知の攻撃の値です | Unknown attack parameter. |
| lab.message&#95;00769fb623 | 変更できない定義の値です | Definition value cannot be changed. |
| lab.message&#95;7d67422141 | 大きさと強さには有効な正の値が必要です | Size and strength require valid positive values. |
| lab.message&#95;f111d0afe0 | 敵を選択すると情報を表示 | Select an enemy to inspect |
| lab.message&#95;479576c49c | 数値はこの実験の同じ種類に適用<br>本番データは書き換えません | Values apply to this enemy type in the experiment.<br>Production data stays unchanged. |
| lab.message&#95;a19e004551 | 姿・当たり判定・攻撃範囲を確認できます | Inspect appearance, collision and attack ranges. |
| lab.message&#95;6170cb0f1e | HP %.1f / %.1f<br>装甲 %.1f　自機の攻撃 %.1f<br>%s<br>状態：%s<br>位置 (%.0f, %.0f)　向き %.0f° | HP %.1f / %.1f<br>Armor %.1f  Ship attack %.1f<br>%s<br>State: %s<br>Position (%.0f, %.0f)  Angle %.0f° |
| lab.message&#95;6fb30df6c1 | 貫通できる | Can pierce |
| lab.message&#95;2c343fabe5 | 装甲で弾かれる | Blocked by armor |
| lab.message&#95;09a8e159ad | 予告中 | Telegraphing |
| lab.message&#95;d44a3e6526 | 移動／待機 | Moving / waiting |
| lab.message&#95;684f07d574 | エリート | Elite |
| lab.message&#95;597e81eb3a | 個体へ適用 | Apply to individual |
| lab.message&#95;341a7b515f | 基礎 HP | Base HP |
| lab.message&#95;7d629f79a9 | 基礎装甲 | Base armor |
| lab.message&#95;80c64a0375 | 基礎速度 | Base speed |
| lab.message&#95;b982dccaae | 基礎半径 | Base radius |
| lab.message&#95;4212b2ec66 | 攻撃・行動の設定 | Attack and behavior settings |
| lab.message&#95;eb3d91decb | 残留する攻撃の終了待ち | Waiting for lingering attacks to end |
| lab.message&#95;aa5d4e5983 | 優先順位の高い要求を先に処理 | Waiting for a higher-priority request |
| lab.message&#95;377bd2f0f5 | ：分類の枠待ち | : category slots full |
| lab.message&#95;49b3b4a997 | ：共通の開始間隔待ち | : shared start gap |
| lab.message&#95;9ce7705ba3 | 全体の攻撃量の上限 | Total attack budget reached |
| lab.message&#95;e98c560853 | 認証したルートの開始時間幅を保護中 | Protecting a certified route start window |
| lab.message&#95;ace1dcf08b | 描ける長さを超過 | Drawing length exceeded |
| lab.message&#95;fdee8bc433 | 外縁 | Outer boundary |
| lab.message&#95;409189caf0 | 地形の掃引 | Swept terrain |
| lab.message&#95;416deae061 | 特殊な倒し方は再生で確認 | Replay required for special defeat conditions |
| lab.message&#95;676b643ad5 | 通常攻撃での確実な撃破を未確認 | Guaranteed kill with normal attack unconfirmed |
| lab.message&#95;eaf4530ecf | 自機の自動攻撃・英雄・重力 | Automatic weapons, hero or gravity |
| lab.message&#95;feb890132f | ランダムな地形の追加 | Random terrain additions |
| lab.message&#95;8e84357015 | 敵弾 | Enemy shot |
| lab.message&#95;c977ed9a15 | 攻撃範囲の保守的な包絡 | Conservative attack envelope |
| lab.message&#95;d51f72362d | Encounter profile: 採用時の基準が異なるため無効 | Encounter profile disabled: adoption baseline differs. |
| lab.message&#95;5e0ec7996a | 現在の状態で適用できる候補が未発見 | No applicable candidate found in the current state. |
| lab.message&#95;461a6d1eec | 未知の敵です | Unknown enemy. |
| lab.range&#95;edit | 範囲・向き | Range / direction |
| lab.undo | 取り消す | Undo |
| lab.redo | やり直す | Redo |
| lab.names | 名前・ID | Names / IDs |
| lab.terrain | 天体 | Terrain |
| lab.rocks | 隕石・がれき | Rocks / debris |
| lab.gimmicks | フィールドの仕掛け | Field events |
| lab.route&#95;length | 線 %.0f / %.0f　消費 %.0f%% | Route %.0f / %.0f  Cost %.0f%% |
| lab.manual&#95;exception | 手動配置：地形や外縁と重なる例外を含みます | Manual layout includes terrain or boundary overlaps |
| lab.info&#95;categories | 攻撃 %s　優先度 %.1f　待機 %.2f秒<br>%s | Attacks %s  Priority %.1f  Wait %.2fs<br>%s |
| lab.spawn&#95;probability | 出現する確率（0〜1） | Spawn probability (0–1) |
| lab.spawn&#95;radius | 出現領域の半径 | Spawn region radius |
| lab.lane&#95;toggle | 選択したレーンをON/OFF | Toggle selected lane |
| lab.lane&#95;apply | 選択したレーンへ条件を適用 | Apply conditions to selected lane |
| lab.status&#95;active | 発動・予告 | Active / telegraph |
| lab.status&#95;residue | 残留 | Lingering |
| lab.status&#95;wait | 待機 | Waiting |
| lab.exit&#95;clearance | 抜けた先に残す余裕の半径 | Exit clearance radius |
| lab.min&#95;spacing | 敵中心どうしの最小距離 | Minimum distance between enemy centers |
| lab.attack&#95;legend | ■ 予告・発動　／ 残留　数値は 発動＋残留 | ■ Telegraph / active  / Lingering; active + lingering |
| lab.error&#95;b03790ec83 | 時間帯一覧の形式が違います | Invalid phase list |
| lab.error&#95;1ba7e23ea5 | 未知の時間帯です | Unknown phase ID |
| lab.error&#95;ea2fd16cf8 | 攻撃量の上限が不正です | Invalid attack budget |
| lab.error&#95;76545bdd1e | 攻撃管理の形式が違います | Invalid attack settings |
| lab.error&#95;141fdea6d8 | 攻撃分類の値が不正です | Invalid attack category value |
| lab.error&#95;b356dea242 | 配置規則の形式が違います | Invalid pattern |
| lab.error&#95;46cc43be42 | 候補一覧の形式が違います | Invalid candidates |
| lab.error&#95;f5899d482e | 候補の形式が違います | Invalid candidate |
| lab.error&#95;51df4a5681 | 候補の線の座標が不正です | Invalid candidate route |
| lab.error&#95;34dfb05e18 | 候補の命令一覧が不正です | Invalid candidate commands |
| lab.error&#95;f2c0bc8a77 | 候補の命令が不正です | Invalid candidate command |
| lab.error&#95;d1d25618ab | 配置規則の上限を超えています | Invalid pattern limits |
| lab.error&#95;59317e2e86 | 配置規則の線が不正です | Invalid pattern route |
| lab.error&#95;8a4eb2caa3 | 配置規則の数値が不正です | Invalid pattern number |
| lab.error&#95;956b200251 | 配置領域の形式が違います | Invalid placement region |
| lab.error&#95;1c4f35b1cc | 配置領域に未知の敵があります | Unknown placement enemy |
| lab.error&#95;28ac733ef0 | 配置領域の数値が不正です | Invalid placement number |
| lab.low&#95;charge | 線を描くための充填が不足しています | Insufficient charge to draw a route |
| lab.trace&#95;in&#95;progress | 実行中の線は開始前へ戻して評価してください | Rewind to before the active trace to evaluate another route |
| lab.initial&#95;branch | 初期実験 | Initial experiment |
| lab.ship&#95;level | 機体のレベル | Ship level |
| lab.reload&#95;data | 本番データを再読込して新しい実験 | Reload production data and start a new experiment |
| lab.data&#95;reloaded | 敵・ボス・時間帯・共通値を読み直しました | Reloaded enemies, bosses, phases and shared values |
| lab.reload&#95;failed | 本番データの再読込に失敗しました。ファイルの形式を確認してください | Could not reload production data. Check the resource files. |
| lab.ui.conditions | 実験条件 | Conditions |
| lab.ui.random | ランダム配置 | Random layouts |
| lab.ui.files | 保存 | Save |
| lab.ui.help | 操作のヒント | Controls |
| lab.ui.help&#95;text | 中ドラッグで移動・ホイールで拡大縮小。Spaceで再生／停止。選択した敵はDeleteで削除、Q／Eで回転。 | Middle-drag to pan; wheel to zoom. Space to play/pause. Delete removes selected enemies; Q/E rotates them. |
| lab.ui.enemies | 敵 | Enemies |
| lab.ui.search | 敵を検索 | Find an enemy |
| lab.ui.all | すべて | All enemies |
| lab.ui.drag&#95;hint | ドラッグして配置 | Drag onto the field |
| lab.ui.select | 選択 | Select |
| lab.ui.place | 配置 | Place |
| lab.ui.route | ルート | Route |
| lab.ui.try | 試遊 | Play as ship |
| lab.ui.range | 範囲 | Range |
| lab.ui.view | 表示する情報 | Display options |
| lab.ui.center | 自機を中心に表示 | Center on ship |
| lab.ui.edit&#95;more | 消去メニュー | Clear menu |
| lab.ui.evaluate | ルートを試す | Try route |
| lab.ui.tune | 敵を調整 | Tune enemy |
| lab.ui.close | 閉じる | Close |
| lab.ui.field | フィールド | Field |
| lab.ui.field&#95;objects | 地形・仕掛け | Terrain and events |
| lab.ui.data | データの再読込 | Reload data |
| lab.ui.play | 再生 | Play |
| lab.ui.pause | 停止 | Pause |
| lab.ui.history | 履歴 | History |
| lab.ui.transport&#95;status | %.2f / %.2f 秒   敵 %d体 | %.2f / %.2f s   %d enemies |
| lab.ui.select&#95;hint | 敵をドラッグして移動 | Drag an enemy to move it |
| lab.ui.place&#95;hint | フィールドをクリックして配置 | Click the field to place enemies |
| lab.ui.route&#95;hint | クリックで点を追加・ドラッグで線を調整 | Click to add points; drag points to edit |
| lab.ui.try&#95;hint | 再生して自機を操作 | Press Play to control the ship |
| lab.ui.range&#95;hint | 選んだ敵からドラッグして範囲・向きを調整 | Drag from the selected enemy to adjust range and direction |
| lab.ui.enemy&#95;tooltip | %s（%s）<br>ドラッグして配置／クリックして連続配置 | %s (%s)<br>Drag to place / click for repeated placement |
| lab.ui.basic | 基本 | Basics |
| lab.ui.attack&#95;details | 攻撃・行動の詳細 | Attack and behavior details |
| lab.ui.individual | この個体 | This instance |
| lab.ui.live&#95;details | 詳しい状態 | Live details |
| lab.ui.type&#95;values | 同じ種類の敵に適用 | Applies to this enemy type |
| lab.ui.hp | HP %.0f / %.0f | HP %.0f / %.0f |
| lab.ui.player | 自機 | Ship |
| lab.ui.player&#95;stats | 自機・ボスの数値 | Ship and boss values |
| lab.ui.loadout | 装備・英雄 | Loadout and hero |
| lab.ui.stage&#95;time | 時間帯 | Stage phases |
| lab.ui.formation | 敵の組み合わせ | Enemy formations |
| lab.attack.jitter | 待ち方のばらつき（秒） | Wait jitter (s) |
| lab.attack.danger | 攻撃の重さ（強敵と大物） | Attack weight (strong and big enemies) |
| lab.attack.used | 重さ %.1f / %.1f | Weight %.1f / %.1f |
| lab.formation.layout | 配置 | Layout |

```csv-compat
lab.toughness,HP の属性（-1 柔らかめ・0 標準・1 硬め）,HP class (-1 soft, 0 standard, 1 hard)
```

| keys | ja | en |
| --- | --- | --- |
| lab.formation.entry | 出現位置 | Entry |
| lab.formation.place | 機体のまわりに並べる | Place around the ship |
| lab.ui.attack&#95;limits | 分類ごとの制限 | Limits by category |
| lab.ui.route&#95;settings | 検証条件 | Validation settings |
| lab.ui.route&#95;comparisons | 比較したルート | Route comparisons |
| lab.ui.pattern&#95;settings | 配置のランダム化 | Randomize layout |
| lab.ui.production&#95;export | AI用の書き出し | Export for AI |
| lab.ui.empty&#95;field | 左の敵をここへドラッグ | Drag an enemy here from the palette |
| lab.ui.resize&#95;panel | 境界をドラッグしてパネルの大きさを変更 | Drag the divider to resize the panels |
| lab.ui.collapse&#95;left | 左の一覧を折りたたむ | Collapse the left list |
| lab.ui.expand&#95;left | 左の一覧を開く | Expand the left list |
| lab.ui.collapse&#95;right | 右のパネルを折りたたむ | Collapse the right panel |
| lab.ui.expand&#95;right | 右のパネルを開く | Expand the right panel |
| lab.ui.zoom&#95;in | 時間軸を拡大 | Zoom in on the timeline |
| lab.ui.zoom&#95;out | 時間軸を縮小 | Zoom out on the timeline |
| lab.ui.show&#95;all | 時間軸の全体を表示 | Show the entire timeline |
| lab.ui.track&#95;help | ホイールで時間軸を拡大縮小・中ドラッグで横移動・クリックで時刻を移動 | Wheel to zoom; middle-drag to pan; click to seek |
| lab.ui.track&#95;time | %s秒 | %ss |
| lab.ui.show&#95;hud | HP・装備などの表示 | HUD (HP and loadout) |
| lab.ui.show&#95;minimap | ミニマップ | Minimap |
| lab.ui.show&#95;background | 背景の星 | Background stars |
| lab.ui.clear&#95;route | 線を消す | Clear route |
| lab.ui.pin&#95;ship | 機体を固定 | Pin ship |
| lab.ui.pin&#95;ship&#95;help | 機体を今の位置に止め、敵だけを動かす（もう一度押すと解除） | Hold the ship in place so only enemies move (press again to release) |
| lab.ui.class&#95;fodder | 雑魚（星1） | Fodder (1 star) |
| lab.ui.class&#95;tough | 硬めの敵（星2） | Tough (2 stars) |
| lab.ui.class&#95;strong | 強敵（星3〜5） | Strong (3-5 stars) |
| lab.ui.class&#95;big | 大物（星6〜10） | Big (6-10 stars) |
| lab.ui.class&#95;field | 障害物・仕掛け | Obstacles and gimmicks |
| lab.field.planet&#95;small | 惑星（小） | Planet (small) |
| lab.field.planet | 惑星（中） | Planet (medium) |
| lab.field.planet&#95;large | 惑星（大） | Planet (large) |
| lab.field.comet | 彗星 | Comet |
| lab.field.gravity | 重力 | Gravity well |
| lab.field.warp | ワープホール | Warp hole |
| lab.field.gem | 経験値の結晶 | Experience crystals |
| lab.ui.class&#95;boss | ボス | Bosses |
| lab.ui.class&#95;other | 出現から外した敵 | Retired enemies |
| lab.ui.stars&#95;all | 星：すべて | Stars: all |
| lab.ui.stars&#95;help | 星の数で絞り込む | Filter by star count |
| lab.ui.reset | リセット | Reset |
| lab.ui.reset&#95;help | 再生を始めた時の状態に戻す（配置は残す。それ以降の記録は分岐として残す） | Back to when playback started (keeps placements; later records stay as a branch) |
| lab.ui.how&#95;moves | 動き | Behavior |
| lab.ui.how&#95;to&#95;kill | 倒し方 | How to defeat |
| lab.enemy.drifter.move | 追ってくる。ときどき画面の中を広く回る | Chases you and sometimes roams widely across the screen |
| lab.enemy.drifter.kill | HP を削る（体当たり・武器） | Wear down its HP (ram or weapons) |
| lab.enemy.swarm.move | 小さな体で群れになって追ってくる | Small bodies that chase you in packs |
| lab.enemy.swarm.kill | HP を削る | Wear down its HP |
| lab.enemy.darter.move | 近づくと構えてから突進し、突進のあとしばらく止まる | Winds up when close then dashes and stops for a while |
| lab.enemy.darter.kill | HP を削る。止まっている間が狙いどき | Wear down its HP. Strike while it is stopped |
| lab.enemy.armored.move | 硬い装甲で追ってくる | Chases you behind heavy armor |
| lab.enemy.armored.kill | 攻撃力が装甲以上なら貫ける。背面に当てると必ずクリティカル | Pierce it when your attack meets its armor. Hits on its back always crit |
| lab.enemy.splitter.move | 経験値が詰まった体で機体を追う。生きている間は増えない | Chases the ship with a body full of experience. It does not multiply while alive |
| lab.enemy.splitter.kill | 倒すと経験値をその場に全部落とし、小さく速い分裂体2体に分かれる | Defeating it drops all its experience on the spot and splits it into two small fast splitlings |
| lab.enemy.splitling.move | 小さく速い体で追ってくる。それ以上は分かれない | A small fast body that chases you. It does not split further |
| lab.enemy.splitling.kill | HP を削る | Wear down its HP |
| lab.enemy.gunner.move | 距離を保って回り込み、光ってから弾を撃つ | Keeps its distance and circles then fires after a flash |
| lab.enemy.gunner.kill | HP を削る | Wear down its HP |
| lab.enemy.missile.move | 遠い距離を保ち、予告のあとホーミングミサイルを撃つ | Keeps far away and fires homing missiles after a warning |
| lab.enemy.missile.kill | HP を削る | Wear down its HP |
| lab.enemy.titan.move | 大きな体で追ってくる。大きさは毎回変わる | A large chaser whose size varies each time |
| lab.enemy.titan.kill | HP が多い。何度も貫く | High HP. Pierce it many times |
| lab.enemy.battleship.move | 追ってきて、予告のあと扇状に弾を撃つ | Chases you and fires a fan of bullets after a warning |
| lab.enemy.battleship.kill | HP を削る。背面が弱点 | Wear down its HP. Its back is the weak point |
| lab.enemy.rocket.move | 出た向きのまま一直線に飛び、機体に近づくと爆発する。少しすると消える | Flies straight in its spawn direction and explodes near you then fades |
| lab.enemy.rocket.kill | HP を削る | Wear down its HP |
| lab.enemy.bomber.move | 追ってきて、近づくとカウントダウンに入り、止まらずに詰め寄る。2回明滅し終わると爆発する | Chases you and starts a countdown when close then keeps closing in. It explodes after blinking twice |
| lab.enemy.bomber.kill | 明滅し終わる前に貫けば、爆発させずに倒せる | Pierce it before it finishes blinking to defeat it without an explosion |
| lab.enemy.biter.move | 全ステージ共通の雑魚（見た目はステージごと。うみへび座のステージではヘビ）。追ってきて、近づくと一瞬光ってから、その場で小さく噛みつく。弾は出さない | A small fry shared by every stage (its look changes per stage; a snake in the Hydra stage). Chases you and when close flashes for an instant, then snaps right where it is. It never shoots |
| lab.enemy.biter.kill | 普通に倒せる。群れの中で止まらずに駆け抜ける | Falls to ordinary attacks. Keep moving through the crowd instead of stopping |
| lab.enemy.volatile.move | 追ってくる。倒すと少し遅れて爆発し、周りの敵も機体も巻き込む（連鎖する） | Chases you. Explodes shortly after defeat and catches enemies and you (chains) |
| lab.enemy.volatile.kill | HP を削る。倒したら爆発から離れる | Wear down its HP then get clear of the blast |
| lab.enemy.beamer.move | 距離を保ち、止まって砲口に光を集めてからビームを撃つ | Keeps its distance and stops to charge its muzzle before firing a beam |
| lab.enemy.beamer.kill | HP を削る | Wear down its HP |
| lab.enemy.pulser.move | 距離を保ち、止まって届く距離の短い輪を1枚出す | Keeps its distance and stops to emit one short-range ring |
| lab.enemy.pulser.kill | HP を削る | Wear down its HP |
| lab.enemy.spreader.move | 追ってきて、予告のあと扇状に弾をばらまく | Chases you and sprays a fan of bullets after a warning |
| lab.enemy.spreader.kill | HP を削る | Wear down its HP |
| lab.enemy.pump.move | 機体を追いながら周りの敵を吸い込んで膨らむ。満タンになると構え、圧縮した敵を巨大な弾にして撃つ。弾は直進して一定の距離で破裂する | Chases the ship while swallowing nearby enemies and swelling. When full it braces and fires them as one huge shell that bursts after a set distance |
| lab.enemy.pump.kill | HP を削る。倒すと溜めていた敵が飛び散り、周りの敵を薙ぎ倒す。溜めているほど派手になる | Wear down its HP. Defeating it releases the compressed enemies and mows down those nearby. The fuller it is the bigger the burst |
| lab.enemy.telescope.move | 距離を保ち、機体のいる方を左右に振って探すサーチライトの帯を伸ばす。帯の中にいると追われて狙いが溜まり、帯が細く赤くなる。溜まりきると一瞬溜めてから、レンズから機体の方へ太いレーザーを撃つ。光とレーザーは隕石で遮られる | Keeps its distance and swings a searchlight band back and forth around where the ship is. Inside the band it tracks you and locks on as the band narrows and turns red. Once the lock is full it charges for a moment then fires a thick laser at the ship. Rocks block both the light and the laser |
| lab.enemy.telescope.kill | HP を削る。速く横切れば狙いは溜まらない | Wear down its HP. Crossing the band quickly barely builds the lock |
| lab.enemy.triangle.move | 3つの星の間に光の膜を張り、膜の中の砲台が距離を保って撃ってくる。膜に触れると被弾する | A turret inside a light membrane between three stars keeps its distance and shoots. Touching the membrane hurts |
| lab.enemy.triangle.kill | 先に頂点の星を1つ倒して膜を消し、次に中の砲台を倒す | First destroy a corner star to drop the membrane then destroy the turret inside |
| lab.enemy.triangle&#95;star.move | みなみのさんかく座の頂点の星。核と一緒に動く | A corner star of the Southern Triangle that moves with the core |
| lab.enemy.triangle&#95;star.kill | 倒すと膜が消える | Destroy it to drop the membrane |
| lab.enemy.shield.move | 機体を追ってゆっくり向き直り、前面の盾で弾を反射する | Approaches while slowly turning toward you. Its front shield reflects shots |
| lab.enemy.shield.kill | 正面に触れると隕石のように押し戻される。側面・背面は通常攻撃が通る。装甲を破って背面を高速で貫くと一撃で倒れ、一定時間攻撃を防ぐ盾を奪える | Touching its front pushes you back like a meteor. Attack the exposed sides or rear. Pierce the rear through its armor at high speed to defeat it and steal temporary protection against enemy attacks |
| lab.enemy.ruler.move | 1体で現れ、二つに分かれて機体を左右（上下）から挟む位置へ展開する。照射の向きを予告してから、それぞれ長いビームを出し続ける。ビームは発射元につながり、壁になって移動を止める | Appears as one ruler then splits in two and spreads to flank the ship. After marking where it will fire each half keeps a long beam on. The beams stay tied to their emitters and act as walls that stop movement |
| lab.enemy.ruler.kill | 分かれた2体をそれぞれ普通に倒す。倒した側のビームが止まり、そちらへ動けるようになる | Defeat each half normally. Its beam stops and that side opens up |
| lab.enemy.crow.move | 4羽の群れで隊列を組み、機体を追わずに一直線に戦場を横断する。横を通り過ぎた経験値を1羽ずつ拾い、画面の外へ持ち去る。攻撃はしない | Four birds fly in formation straight across the field without chasing. Each picks up experience it passes on either side and carries it off screen. They never attack |
| lab.enemy.crow.kill | 1羽ずつもろく、普通に当てれば倒れる。退場する前に倒すと、その1羽が回収した経験値をその場にまとめて落とす | Each bird is fragile and falls to any hit. Defeat one before it leaves to drop the experience it collected in one spot |
| lab.enemy.lynx.move | 距離を保ち、潰れた弧の3本の爪痕の斬撃を左右交互に飛ばし続ける。斬撃は真ん中の少し先から外側へ伸び、外側で本体の方へ反り上がる。機体の方へ形を保って直進し、追尾しない | Keeps its distance and keeps hurling slashes of three flattened claw arcs on alternating sides. Each reaches just past the middle and sweeps outward curling back toward the lynx. They fly straight toward the ship keeping their shape without homing |
| lab.enemy.lynx.kill | 内側の端を左右交互によけながら真ん中を抜けて近づき、本体を普通に倒す。外側からは回り込みにくい | Weave past the inner tips through the middle to close in and defeat the body normally. Going around the outside is hard |
| lab.enemy.reticle.move | 近くのぼうえんきょう座に付き従う支援機。ぼうえんきょう座と機体の間で視線を遮る小隕石に照準を出し、ビームで壊す。機体は直接攻撃しない。支援先がいなければ退却する | A support craft that follows the nearest telescope. It marks small rocks that block the telescope’s line of sight to the ship and breaks them with a beam. It never attacks the ship directly and retreats when it has no telescope to support |
| lab.enemy.reticle.kill | 本体を普通に倒して岩陰を守るか、先にぼうえんきょう座を倒して連携を崩す | Defeat it normally to keep your cover or take down the telescope first to break up the pair |
| lab.enemy.cross.move | 動き回り、機体と縦か横にそろう位置で止まって、予告してから十字のレーザーを撃つ | Roams then stops where it lines up with the ship vertically or horizontally and fires a cross of lasers after a telegraph |
| lab.enemy.cross.kill | HP を削る。止まって構えている間が狙い目 | Wear down its HP. It is open while it stops to charge |
| lab.enemy.clock.move | 長針と短針が刃として回り続ける。2本の速さが違う | Its long and short hands spin as blades at different speeds |
| lab.enemy.clock.kill | 針の隙間から本体を狙う | Hit the body through the gap between the hands |
| lab.enemy.dolphin.move | 距離を保ち、構えて撃つ向きを予告してから、機体の方へ数層の弧の大きな扇の波動を撃つ。当たるのは先頭の1枚だけで、機体にもほかの敵にも当たる。追尾しない | Keeps its distance and after marking its aim fires a big fan of layered arcs toward the ship. Only the leading arc hits and it hits the ship and other enemies alike. It does not home |
| lab.enemy.dolphin.kill | 群れを射線に挟んで撃たせ、自分は離れる。本体は普通に倒す | Put a crowd in its line of fire then slip away. Defeat the body normally |
| lab.enemy.crab.move | 近づいてハサミを開き、前方を挟む | Approaches and opens its claws then pinches in front |
| lab.enemy.crab.kill | 背面から倒す。挟んだ直後（ハサミが開いたまま）は正面からでも倒せる | Defeat it from behind. Right after a pinch (claws still open) it breaks even from the front |
| lab.enemy.marlin.move | 距離を保ち、光ってから高速で泳ぎ抜け、左右へしぶきを撒く | Keeps its distance then flashes and darts past you spraying both sides |
| lab.enemy.marlin.kill | HP を削る | Wear down its HP |
| lab.enemy.auriga.move | 大きく旋回しながら走り、車輪の跡が燃えて残る | Drives in wide turns leaving burning wheel tracks |
| lab.enemy.auriga.kill | HP を削る | Wear down its HP |
| lab.enemy.corona.move | 近くの雑魚を小さな渦で率いて近づき、予告した個体を旋回の進行方向へ投げる | Approaches with nearby enemies in a compact vortex and throws a marked enemy along its orbit |
| lab.enemy.corona.kill | 渦の群れを突き抜けて倒すと投擲の弾薬が減る。投げた個体の赤い頭だけが攻撃判定を持つ | Pierce the orbiting enemies to remove ammunition. Only a thrown enemy’s red head carries attack damage |
| lab.enemy.phoenix.move | 機体の周りを旋回し、飛んだ跡に炎を残す | Circles you and leaves a trail of fire |
| lab.enemy.phoenix.kill | HP を削る。倒すと周りを焼き払い、近いと自分も焼かれる | Wear down its HP. Defeat scorches the area and burns you if close |
| lab.enemy.cepheus.move | 距離を保ち、専用の兵を召喚して隊列を組ませる。時間とともに3体の横一列→5体の扇形→7体の千鳥の二重隊列へ増援し、そのときだけ組み直す。兵は配置で止まって細長い光弾を撃つ | Keeps its distance and summons soldiers into formation. Reinforcements grow it from a line of three to a fan of five to a staggered double rank of seven and it only reforms then. Soldiers hold their posts and fire long light bolts |
| lab.enemy.cepheus.kill | 隊列を抜けて王を倒すと、召喚と兵の攻撃が止まり、残った兵は撃ち合って崩れる | Break through the ranks and defeat the king. Summoning and the soldiers’ attacks stop and the rest turn on each other and fall apart |
| lab.enemy.cepheus&#95;soldier.move | ケフェウス座が召喚する兵。王が決めた隊列の位置で止まり、王の号令で決まった向きへ細長い光弾を撃つ。追尾しない | A soldier summoned by Cepheus. It holds the post the king assigns and fires long light bolts in a fixed direction on the king’s command. They do not home |
| lab.enemy.cepheus&#95;soldier.kill | 普通に倒せる。倒した穴は次の増援まで空く | Falls to ordinary attacks. The gap stays until the next reinforcement |
| lab.enemy.aquarius.move | 瓶の口を機体へ向けたまま近づき、止まって溜めながら通り道に水の流れを流して予告し、先へ行くほど広がる水のビームを全方位へ6本、一斉に照射する | Closes in with its jar aimed at the ship, stops and charges while ripples flow along the beam paths, then fires six widening water beams in every direction at once |
| lab.enemy.aquarius.kill | HP を削る | Wear down its HP |
| lab.enemy.aquila.move | 大きく旋回して飛び、通り道に雷を落とす | Flies in wide turns dropping lightning along its path |
| lab.enemy.aquila.kill | HP を削る | Wear down its HP |
| lab.enemy.meteor.move | 固い障害物。止まっているものと、ゆっくり漂うものがある | A solid obstacle. Some stay still and some drift slowly |
| lab.enemy.meteor.kill | 攻撃力が装甲以上の体当たりで砕く。普段の速さで触れると跳ね返る | Smash it with a ram that meets its armor. Touching it at normal speed bounces you |
| lab.enemy.iron.move | 動かない固い障害物（鉄のがれき） | An immovable solid obstacle (iron debris) |
| lab.enemy.iron.kill | 装甲がとても高い。十分な攻撃力の体当たりで割れる | Very high armor. A strong enough ram breaks it |
| lab.enemy.saw.move | その場で回る丸鋸 | A saw blade spinning in place |
| lab.enemy.saw.kill | 壊すのではなく、触れて飛ばす。進んでいた向きへ飛び、先の敵を巻き込む | Launch it by touching it rather than destroying it. It flies your way and cuts through enemies |
| lab.enemy.hydra&#95;bite.move | うみへび座の噛みつく首。狙いを固定して突き噛みし、近くでは横に薙ぐ | A Hydra bite head. Locks its lunge or sweeps nearby space |
| lab.enemy.hydra&#95;bite.kill | 頭を削って落とす（本体の体力も減る）。落ちた頭は生え直す | Wear the head down (also hurts the body). Lost heads regrow |
| lab.enemy.hydra&#95;vortex.move | 風の帯で遅い機体を押し返し、首を振って三日月の風刃を3枚撃つ | Pushes slow ships away with a wind band and swings to launch three crescent blades |
| lab.enemy.hydra&#95;vortex.kill | 頭を削って落とす。落ちた頭は生え直す | Wear the head down. Lost heads regrow |
| lab.enemy.hydra&#95;debris.move | 硬い瓦礫の塊を投げる。近めの距離では扇状に散らす | Throws hard rubble chunks or scatters them in a fan at closer range |
| lab.enemy.hydra&#95;debris.kill | 頭を削って落とす。落ちた頭は生え直す | Wear the head down. Lost heads regrow |
| lab.enemy.hydra&#95;beam.move | 1本の射線を固定して照射する。有限長の光弾も撃つ | Holds one fixed beam or launches a finite light bolt |
| lab.enemy.hydra&#95;beam.kill | 頭を削って落とす。落ちた頭は生え直す | Wear the head down. Lost heads regrow |
| lab.enemy.hydra&#95;thunder.move | 帯電して頭突きし、到達時に放電する。遠くでは進行先へ落雷を予告する | Charges a headbutt with an arrival discharge, or marks lightning ahead at range |
| lab.enemy.hydra&#95;thunder.kill | 頭を削って落とす。合体中は再生し、分離後は撃破できる | Wear the head down. Regrows while combined; stays defeated after separation |
| lab.enemy.hydra&#95;immortal.move | 羅針盤を抱えて逃げる蛇。単独では振り返って噛みつく | The compass bearer flees, then turns to bite when alone |
| lab.enemy.hydra&#95;immortal.kill | 護衛が残っていても直接攻撃できる。倒すと羅針盤を解放する | Can be damaged directly while guards remain. Defeat it to free the compass |
| lab.enemy.hydra&#95;rubble.move | うみへび座が吐いた瓦礫。漂って、少しすると消える | Debris spat by the Hydra. Drifts and vanishes after a while |
| lab.enemy.hydra&#95;rubble.kill | 体当たりは弾かれる。武器で壊せる | Rams bounce off. Weapons break it |
| lab.enemy.provisional.move | 機体を直接追い、予告のあと扇状に弾を撃つ | Chases you directly and fires a fan of bullets after a warning |
| lab.enemy.provisional.kill | HP を削る。背面が弱点 | Wear down its HP. Its back is the weak point |
| lab.enemy.hydra.move | 中央を守る首が3・5・8本へ増え、羅針盤で大技を予告する。瓦礫を壊すと蛇が分離する | Heads defend the core and grow from three to five to eight. The compass warns of major attacks. Breaking the rubble separates the snakes |
| lab.enemy.hydra.kill | 中央の瓦礫を削る。全頭ダウンは攻めどき。分離後は羅針盤を持つ蛇を倒す | Damage the central rubble. Downing every head opens a chance. After separation, defeat the compass bearer |
| lab.ui.freehand | 自由に描く | Freehand |
| lab.ui.edit&#95;points | 点を編集 | Edit points |
| lab.ui.route&#95;tool&#95;help | 自由描画と点ごとの編集を切り替え | Switch between freehand drawing and editing points |
| lab.ui.freehand&#95;hint | クリックで描き始め・もう一度クリックで確定（ドラッグ描画も可） | Click to start and click again to finish; dragging also works |
| lab.ui.drawing&#95;route | 描画中：クリックで確定・右クリック／Escで取り消し | Drawing: click to finish; right-click or Esc to cancel |
| lab.ui.collapse&#95;bottom | 下のバー全体を折りたたむ | Collapse the entire bottom bar |
| lab.ui.expand&#95;bottom | 下のバーを開く | Expand the bottom bar |
| lab.appearance.title | 外観 | Appearance |
| lab.appearance.help | 本番と同じ描画で確認します。拡大後もホイールで倍率、中央ドラッグで視点を変更できます。 | Inspect the production renderer. Use the wheel to zoom and middle-drag to pan. |
| lab.appearance.bomber | 自爆型を配置して拡大 | Place and magnify a bomber |
| lab.appearance.focus | 選択中の敵を拡大 | Magnify selected enemy |
| lab.appearance.rotation | 敵の回転（度） | Enemy rotation (degrees) |
| lab.appearance.key&#95;energy | 主光の強さ（左上） | Key energy (upper left) |
| lab.appearance.fill&#95;energy | 補助光の強さ（右下） | Fill energy (lower right) |
| lab.appearance.key&#95;angle | 主光の角度（度） | Key angle (degrees) |
| lab.appearance.fill&#95;angle | 補助光の角度（度） | Fill angle (degrees) |
| lab.appearance.height | 光の高さ（0=横、1=正面） | Light height (0=side 1=front) |
| lab.appearance.ambient | 環境光（影の明るさ） | Ambient (shadow brightness) |
| lab.appearance.normal&#95;strength | 法線の強調度（0=平面） | Normal strength (0=flat) |
| lab.appearance.light&#95;help | 主光を下げると白飛びを抑えられます。補助光と環境光を下げると陰影が強まり、光の高さを下げると横から照らします。変更は即時反映され、保存すると次の本番ステージにも使います。 | Lower key energy to reduce clipping. Lower fill or ambient for stronger contrast. Lower height for side lighting. Changes apply immediately; save to use them in future runs. |
| lab.appearance.reset | 初期の照明へ戻す | Reset lighting |
| lab.appearance.save | 照明をプロジェクトへ保存 | Save lighting to project |
| lab.appearance.saved | 照明を enemy&#95;lighting.tres に保存しました | Lighting saved to enemy&#95;lighting.tres |
| lab.appearance.select&#95;enemy | 確認する敵を選択してください | Select an enemy to inspect |
| lab.appearance.scale | サイズ倍率（見た目・当たり判定） | Size multiplier (visual and collision) |
| lab.appearance.type&#95;help | 選択した種類の全個体へ即時反映します。サイズは見た目と当たり判定の両方に適用します。保存すると全ステージの同じ種類に使います。照明は法線画像を持つ敵だけ調整できます。 | Edits apply to all instances of the selected type. Size changes visuals and collision. Save to use settings in every stage. Lighting requires a normal map. |
| lab.appearance.restore&#95;saved | この種類を保存済みの外観へ戻す | Restore saved appearance for this type |
| lab.appearance.save&#95;type | この種類の設定をステージへ保存 | Save this type for all stages |
| lab.appearance.select&#95;type | 配置した通常敵またはパーツを選択してください（ボス・地形は対象外） | Select a placed enemy or part (bosses and terrain are excluded). |
| lab.appearance.target | {name} [{id}] — {state} | {name} [{id}] — {state} |
| lab.appearance.unsaved | 未保存 | Unsaved |
| lab.appearance.saved&#95;state | 保存済み | Saved |
| lab.appearance.save&#95;failed | 外観を保存できませんでした | Could not save appearance |
| lab.appearance.file&#95;changed | 敵データが外部で変更されています。実験場を開き直してから保存してください。 | Enemy data changed externally. Reopen the lab before saving. |
| lab.appearance.saved&#95;type | {name} の外観を保存しました。次のステージ開始から使います。 | Saved appearance for {name}. New runs will use these settings. |
<!-- csv:end -->

### 互換行

`csv-compat` ブロックは、既存 CSV の余剰列を含む行を列順ごと保持する。`lab.toughness` は英語のカンマが列を分け、先頭の英語セルと余剰2セルを持つ。通常の追加・編集には3列の表を使う。

## リソース表示名

この表は既存の単言語の `display_name` を保持する。生成ツールは指定ファイルの `[resource]` の表示名だけを更新する。翻訳キーを持つ武器・特性・ステージの名前は上の翻訳文を使う。

<!-- resources:start -->
| resource | display_name |
| --- | --- |
| enemies/aquarius.tres | みずがめ座 |
| enemies/aquila.tres | わし座 |
| enemies/armored.tres | 装甲型 |
| enemies/auriga.tres | ぎょしゃ座 |
| enemies/battleship.tres | 戦艦 |
| enemies/beamer.tres | ビームの敵 |
| enemies/biter.tres | 噛みつく雑魚 |
| enemies/bomber.tres | 自爆する雑魚 |
| enemies/cepheus.tres | ケフェウス座 |
| enemies/cepheus&#95;soldier.tres | ケフェウス座の兵 |
| enemies/clock.tres | とけい座 |
| enemies/corona.tres | みなみのかんむり座 |
| enemies/crab.tres | かに座 |
| enemies/cross.tres | みなみじゅうじ座 |
| enemies/crow.tres | からす座 |
| enemies/darter.tres | ダーター |
| enemies/dolphin.tres | いるか座 |
| enemies/drifter.tres | ドリフター |
| enemies/gunner.tres | 射撃型 |
| enemies/hydra&#95;beam.tres | うみへび座のビームの首 |
| enemies/hydra&#95;bite.tres | うみへび座の噛みつく首 |
| enemies/hydra&#95;debris.tres | うみへび座の瓦礫の首 |
| enemies/hydra&#95;thunder.tres | うみへび座の雷の首 |
| enemies/hydra&#95;immortal.tres | うみへび座の不死の首 |
| enemies/hydra&#95;rubble.tres | うみへび座の瓦礫 |
| enemies/hydra&#95;vortex.tres | うみへび座の渦の首 |
| enemies/iron.tres | 鉄のがれき |
| enemies/lynx.tres | やまねこ座 |
| enemies/marlin.tres | かじき座 |
| enemies/meteor.tres | 隕石 |
| enemies/missile.tres | ホーミングミサイルの敵 |
| enemies/phoenix.tres | ほうおう座 |
| enemies/pulser.tres | 波動の敵 |
| enemies/pump.tres | ポンプ座 |
| enemies/reticle.tres | レチクル座 |
| enemies/rocket.tres | ミサイル |
| enemies/ruler.tres | じょうぎ座 |
| enemies/saw.tres | 回る丸鋸 |
| enemies/shield.tres | たて座 |
| enemies/splitling.tres | 分裂体 |
| enemies/splitter.tres | 分裂する雑魚 |
| enemies/spreader.tres | 拡散弾の敵 |
| enemies/swarm.tres | スウォーム |
| enemies/telescope.tres | ぼうえんきょう座 |
| enemies/titan.tres | タイタン |
| enemies/triangle.tres | みなみのさんかく座 |
| enemies/triangle&#95;star.tres | みなみのさんかく座の星 |
| enemies/volatile.tres | 誘爆する雑魚 |
| heroes/gemini.tres | ふたご座 |
| heroes/hercules.tres | ヘルクレス座 |
| heroes/leo.tres | しし座 |
| heroes/perseus.tres | ペルセウス座 |
| bosses/hydra.tres | うみへび座 |
| bosses/provisional.tres | ボス戦艦（仮） |
<!-- resources:end -->
