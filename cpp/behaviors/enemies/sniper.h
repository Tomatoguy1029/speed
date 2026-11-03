#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class SniperBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static godot::Vector2 lens(const Enemy &);
    static double half(const RunRuntime &,uint32_t);
    static double reach(const RunRuntime &,uint32_t,double);
    static int sight(const RunRuntime &,uint32_t,godot::Vector2);
    static bool aiming(const RunRuntime &,uint32_t);
    static void died(RunRuntime &,const DeathContext &);
};
}
