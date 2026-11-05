#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {class CanisTechnique {public:
    static void cue(RunRuntime &,const TechniqueState &,const char *,EnemyHandle actor={},double radius=-1,uint32_t profile=0,double initial_age=0);
    static void remember_usage(RunRuntime &,const TechniqueState &,const char *);
    static void face(RunRuntime &,TechniqueState &,godot::Vector2,double,double);
    static void lock_aim(RunRuntime &,TechniqueState &,bool direction_only,double overshoot=0);
    static bool touches(RunRuntime &,const TechniqueState &,godot::Vector2,godot::Vector2,double);
    static void hit(RunRuntime &,TechniqueState &,double,Cause);
};}
