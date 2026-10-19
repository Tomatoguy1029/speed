## 攻撃の組み合わせ
## 強敵と大物（星3以上）の攻撃が重なって避けられなくならないための決まり。強敵の全体で同時にいてよい数と、
## 種類どうしの攻撃の組み合わせの表を持つ。種類ごとの同時にいてよい数は、敵の定義の max_alive。
## 雑魚と硬めの敵は数だけで抑え、この表は使わない。
## ---
## 値の正は res://data/attack_rules.tres。設定（config.attack_rules）から参照する。
class_name AttackRules
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 6

## 強敵の上限
## 強敵と大物（星3以上）が、全体で同時にいてよい数。0 なら上限なし。
## 単位：体
@export var strong_cap: int
## 種類どうしの組み合わせ
## キーは2つの type ID を「/」でつないだもの（並びは問わない。例 telescope/lynx。同じ種類どうしは telescope/telescope）。
## 値は、片方の攻撃が終わってから、もう片方が攻撃を始めるまで空ける時間。0 なら同時には撃たない。
## 載っていない組み合わせは、同時に撃ってよい。
## 単位：実秒
@export var pairs: Dictionary[String, float] = {}

## 2つの種類の組み合わせのキー（並びをそろえる）。
static func key(a: StringName, b: StringName) -> String:
	return "%s/%s" % ([a, b] if String(a) <= String(b) else [b, a])

## a の攻撃が終わってから b が攻撃を始めるまで空ける時間。同時に撃ってよい組み合わせなら -1。
func gap(a: StringName, b: StringName) -> float:
	var k := key(a, b)
	if pairs.has(k):
		return pairs[k]
	# 並びを逆に書いたキーも受け付ける
	var r := "%s/%s" % [b, a] if k == "%s/%s" % [a, b] else "%s/%s" % [a, b]
	return pairs.get(r, -1.0)

## 表の中で一番長い空ける時間（終わった攻撃をいつまで覚えておくかに使う）。
func longest_gap() -> float:
	var m := 0.0
	for v in pairs.values():
		m = maxf(m, float(v))
	return m
