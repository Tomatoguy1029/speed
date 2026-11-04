#pragma once
#include "beam.h"
namespace speed {
class FloodSystem {
public:
    static AttackHandle emit(RunRuntime &,const BeamParams &);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
    static void end_visual(RunRuntime &,const FloodTailState &,int64_t id);
};
}
