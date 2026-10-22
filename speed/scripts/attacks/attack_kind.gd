## 攻撃の生成の入口。種類ごとに、型付きのspawn(ps, ...)を実装する。
## 生成した行の更新・当たりはHostileShape / HazardShape / FriendShapeが、表示はAttackVisualが持つ。
## 複合攻撃は既存の形を組み合わせるので、ProjectileSystemの種類表を変更せず追加できる。
class_name AttackKind
extends RefCounted

func emit(ps: ProjectileSystem, args: Array) -> Variant:
	return callv(&"spawn", [ps] + args)
