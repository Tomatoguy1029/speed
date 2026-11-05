#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct AquariusPose {godot::Vector2 position;double facing=0;};
class AquariusBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static double visual_time(const RunRuntime &,uint32_t);
    static AquariusPose visual_pose(const RunRuntime &,uint32_t,godot::Vector2,double,double);
    static godot::Vector2 claw_tip(const RunRuntime &,uint32_t,const AquariusPose &);
    static void after_move(RunRuntime &,EnemyHandle,double);
};
}
