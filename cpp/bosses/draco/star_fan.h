#pragma once
#include "technique.h"
#include "../../state/boss_states.h"
#include "state.h"
namespace speed {class DracoStarFan {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &);
    static void active(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &);
    static bool validate(const DracoStarFanState &);
    static godot::Dictionary snapshot(const TechniqueState &);
};}
