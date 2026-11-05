#pragma once
#include "technique.h"
#include "../../state/boss_states.h"
#include "state.h"
namespace speed {class DracoTailSweep {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &);
    static void active(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void recover(RunRuntime &,TechniqueState &);
    static bool validate(const DracoTailSweepState &);
    static godot::Dictionary snapshot(const TechniqueState &);
};}
