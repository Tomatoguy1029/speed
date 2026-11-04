#pragma once
#include "../state/entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <cstdint>
namespace speed {
class RunRuntime;
struct BossLandingContact {
    EnemyHandle actor;
    godot::Vector2 center;
    double radius=0;
    uint32_t technique=0;
    int64_t observation=0;
    bool attempted=false;
};
class BossContactSystem {
public:
    // 着地のnative更新だけ有効。飛行中には登録しない。
    static void register_landing(RunRuntime &,EnemyHandle,godot::Vector2 center,double radius,uint32_t technique,int64_t observation);
    static void clear_landings(RunRuntime &);
    static void knock_back(RunRuntime &,EnemyHandle);
    static bool resolve(RunRuntime &,godot::Vector2 from,godot::Vector2 to,double ship_radius);
};
}
