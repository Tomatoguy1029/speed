#pragma once
#include "../state/entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
struct BossImageCut { godot::Vector2 enter,exit; };
class BossImageSystem {
public:
    static void refresh(RunRuntime &);
    static bool available(const RunRuntime &,EnemyHandle);
    static bool cut(const RunRuntime &,EnemyHandle,godot::Vector2 from,godot::Vector2 direction,BossImageCut &);
};
}
