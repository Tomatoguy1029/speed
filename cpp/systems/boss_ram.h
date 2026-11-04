#pragma once
#include "../state/entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
class BossRamSystem {
public:
    static bool begin(RunRuntime &,EnemyHandle,godot::Vector2 contact,godot::Vector2 direction,double ship_radius);
    static void advance(RunRuntime &,double real_dt);
    static void cancel_invalid(RunRuntime &);
};
}
