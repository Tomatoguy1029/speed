#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct LynxPose {godot::Vector2 position;double facing=0;};
class LynxBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static LynxPose visual_pose(const RunRuntime &,uint32_t,godot::Vector2,double,double);
};
}
