#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct LightLanceParams {godot::Vector2 position,direction;double length=0,width=0,damage=0,knock=0;};
class LightLancesSystem {
public:
    static std::vector<uint64_t> fire(RunRuntime &,const LightLanceParams &);
    static void step(RunRuntime &,double world_dt);
};
}
