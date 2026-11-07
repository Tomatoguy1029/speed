#pragma once
#include "technique.h"
#include "../../state/boss_states.h"
#include "state.h"
namespace speed {class DracoBreath {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &,double);
    static void active(RunRuntime &,TechniqueState &,double);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void recover(RunRuntime &,TechniqueState &);
    static bool validate(const DracoBreathState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
