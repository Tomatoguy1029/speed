#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisTechnique {public:
    static void cue(RunRuntime &,const TechniqueState &,const char *);
    static void face(RunRuntime &,TechniqueState &,godot::Vector2,double,double);
    static void lock_aim(RunRuntime &,TechniqueState &,bool direction_only,double overshoot=0);
    static bool touches(const RunRuntime &,const TechniqueState &,godot::Vector2,godot::Vector2,double);
    static void hit(RunRuntime &,TechniqueState &,double,Cause);
};}
