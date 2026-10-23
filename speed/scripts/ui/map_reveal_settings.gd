## GFX-002 の視覚調整用。値は完成アートの基準ではなく試作の初期値。
extends Resource

@export_group("接続線と点灯")
## 線が先端まで伸びる時間。0 は即時表示。
@export_range(0.0, 2.0, 0.01, "suffix:s") var line_duration := 0.22
## 1 は等速。大きいほど線の先端がゆっくり止まる。
@export_range(1.0, 4.0, 0.1) var line_ease := 1.6
## 線が伸び切ってから情報が点灯し始めるまでの間。
@export_range(0.0, 1.0, 0.01, "suffix:s") var information_delay := 0.035
## 情報が透明から通常の明るさになるまでの時間。
@export_range(0.0, 2.0, 0.01, "suffix:s") var fade_duration := 0.28
## 点灯途中に重ねる一時的な発光。0 で発光を加えない。
@export_range(0.0, 1.0, 0.01) var glow_strength := 0.22
@export_group("モニター効果")
## 固定走査線・画素マスク・周辺減光・弱い光のにじみの強さ。
@export_range(0.0, 1.0, 0.01) var crt_strength := 0.25
@export_group("波形")
## 各棒のアタック・保持・減衰を一緒に伸縮する速度。0.1〜0.2 を調整の目安にする。
@export_range(0.0, 5.0, 0.05) var spectrum_speed := 0.15
## 持続する「ゴォー」という音の通常の高さ。振幅の変化量とは独立して扱う。
@export_range(0.0, 1.0, 0.01) var spectrum_base_height := 0.45
## 通常の高さを中心に変動する幅。活動量・帯域・個々の強弱は別々の時間スケールで変わる。
@export_range(0.0, 1.0, 0.01) var spectrum_motion := 0.85
## 近い帯域の反応を混ぜる量。全体ピークの頻度は別に扱う。
@export_range(0.0, 1.0, 0.01) var spectrum_correlation := 0.18
## 大きな音が全体に重なる頻度。1 は秒に1回程度、0 は無効。
@export_range(0.0, 1.0, 0.01, "suffix:Hz") var spectrum_peak_frequency := 0.08
## 大きな音が重なったときの高さ。頻度・帯域の同期度とは別に調整する。
@export_range(0.0, 1.0, 0.01) var spectrum_peak_strength := 0.95
@export_group("天球図")
## 中心と軌道を固定し、軌道上の光だけを異なる周期で巡らせる速度。0 で静止。
@export_range(0.0, 0.2, 0.005) var orbit_speed := 0.025
