#pragma once
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
struct LeoDefinition;
// しし座：効いている間、機体は星の獅子になる。なぞり・武器・特性は止まり、被弾しない。
// 機体は一定の速さで駆け、獅子の体（向きにそった太い線分）に触れた敵へ間隔を置いて当たる。
class LeoBehavior {
public:
    // 効いているときだけ定義を返す
    static const LeoDefinition *active(const RunRuntime &);
    // 獅子の体に触れた敵へ当たり、障害物を砕き、敵の弾を消す。from・to は機体の移動の前後
    static void contact(RunRuntime &,godot::Vector2 from,godot::Vector2 to);
};
}
