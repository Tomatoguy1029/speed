## 時間帯
## ランの時間を区切った区間ごとの、敵の数・強さ・種類の出方。名前は作り手用で、ゲーム画面には出さない。
## 時間帯は開始の時刻だけを持ち、次の時間帯の開始まで続く（最後の時間帯はボスの出現時刻まで）。
## 敵の数とレベルは、区間の開始の値から終わりの値へ時間とともに変わる。
## ---
## 値の正は res://data/phases/*.tres と、ステージに埋め込んだ時間帯。使う時間帯はステージのデータで決める。
class_name PhaseDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 4

## 開始の時刻
## ラン開始からこの時刻に、この時間帯が始まる。次の時間帯の開始まで続く。
## 単位：実秒
@export var start: float
## 敵の数（開始時）
## 時間帯の始めに、フィールドにいてほしい敵の数。調整値の「敵の密度倍率」が掛かる。
## 単位：体
@export var pop_from: float
## 敵の数（終了時）
## 時間帯の終わり（次の時間帯の開始）に、フィールドにいてほしい敵の数。
## 単位：体
@export var pop_to: float
## 補充の速さ
## 敵が足りないとき、1秒に補充する数。調整値の「敵の密度倍率」が掛かる。
## 単位：体/秒
@export var rate: float
## 経験値の倍率
## この時間帯に倒した敵の経験値に掛ける。0 は 1 倍として扱う。
## 単位：倍
@export var xp_bonus: float
## 群れの間隔
## この間隔ごとに、群れの種類の敵をまとめて出す。0 なら出さない。
## 単位：実秒
@export var wave_interval: float
## 群れの種類
## 群れとしてまとめて出す敵の ID。
## 単位：文字
@export var wave_type: StringName
## 攻撃の予算
## 強敵の攻撃が同時に使ってよい、群れごとの value の合計。0 なら新しい攻撃を待たせる。タイムラインで編集する。
## 単位：整数
@export_range(0, 1000, 1, "or_greater") var attack_budget: int
## 出力コアを出す
## オンにすると、この時間帯にフィールドの中心付近へ出力コアが出る。
## 単位：オン／オフ
@export var cores: bool
## 出現の重み
## 敵の種類ごとの出やすさ。大きいほどよく出る（全体に対する比で決まる）。
## 単位：重み
@export var mix: Dictionary

@export_group("強化内容（-1：共通設定）")
## 強化の間隔
## ON区間で1段強化されるまでの秒数。負の値は共通設定を使う。
## 単位：実秒
@export var surge_interval: float = -1.0
## 1段ごとの敵の数の増加
## 強化1段につき、目標の敵数へ加える割合。負の値は共通設定を使う。
## 単位：割合
@export var surge_pop: float = -1.0
## 1段ごとの撃つ敵の出やすさ
## 強化1段につき、撃つ敵の出現の重みへ加える割合。負の値は共通設定を使う。
## 単位：割合
@export var surge_ranged: float = -1.0
## 1段ごとのエリート確率の増加
## 強化1段につき、エリートになる確率へ加える値。負の値は共通設定を使う。
## 単位：確率
@export var surge_elite: float = -1.0

## 見分けるための ID と、画面に出る名前・説明
@export_group("名前と ID")
## ID
## 時間帯を見分ける名前。ステージのデータがこの時間帯を指すのに使う。
## 単位：文字
@export var id: StringName
## 名前
## 作り手用の名前。ゲーム画面には出さない。
## 単位：文字
@export var display_name: String

func surge_value(property: String, cfg: GameConfig) -> float:
	var own := float(get(property))
	return own if own >= 0.0 else float(cfg.get(property))
