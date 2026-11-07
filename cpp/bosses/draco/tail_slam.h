#pragma once
#include "technique.h"
#include "../../state/boss_states.h"
#include "state.h"
namespace speed {class DracoTailSlam {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &);
    static void active(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void recover(RunRuntime &,TechniqueState &);
    static bool in_reach(const RunRuntime &,const BossBodyState &,uint32_t);
    static bool validate(const DracoTailSlamState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
