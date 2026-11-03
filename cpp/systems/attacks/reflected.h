#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class ReflectedSystem {
public:
    static void reflect(RunRuntime &,EnemyHandle source,godot::Vector2 impact,godot::Vector2 velocity,double radius);
};
}
