#pragma once
#include "input_frame.h"
namespace godot {class SpeedRunCore;}
namespace speed {
class RunRunner {
public:
    static bool step_play(godot::SpeedRunCore &core,double dt,const InputFrame &input,godot::Vector2 logical_size);
    static void enter_bonus(godot::SpeedRunCore &core);
    static void leave_bonus(godot::SpeedRunCore &core);
    static void camera(godot::SpeedRunCore &core,double dt,godot::Vector2 logical_size);
};
}
