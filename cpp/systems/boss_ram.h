#pragma once
#include "../state/entity_store.h"
#include "boss_image.h"
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
class BossRamSystem {
public:
    static bool begin(RunRuntime &,EnemyHandle,const BossImageCut &,godot::Vector2 direction,double ship_radius);
    static void advance(RunRuntime &,double real_dt);
    static void cancel_invalid(RunRuntime &);
};
}
