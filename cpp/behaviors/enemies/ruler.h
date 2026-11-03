#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class RulerBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static godot::Vector2 beam_origin(const RunRuntime &,uint32_t);
};
}
