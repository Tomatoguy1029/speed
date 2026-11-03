#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class DracoCinematic {public:
    static void capture(RunRuntime &,DracoCinematicState &);
    static void restore(RunRuntime &,DracoCinematicState &);
    static void frame(RunRuntime &,godot::Vector2,double);
};}
