## みなみのさんかく座の見た目。中心は描かず、辺を動く星の後ろに赤いレーザーの軌跡を描く。
extends EnemyVisual

## 軌跡の色（外側の暗い縁、本体、中心の明るい芯）
const TRAIL_EDGE := Color("#7a0c1a")
const TRAIL_BODY := Color("#ff2b3d")
const TRAIL_CORE := Color("#ffd2d2")
## 軌跡を太さの違う何段に分けて描くか（ピクセルアートらしい段差）
const TRAIL_STEPS := 6
## 後ろの端の太さ（星の側に対する割合）
const TRAIL_TAIL := 0.4
