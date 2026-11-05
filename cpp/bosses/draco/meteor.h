#pragma once
#include "breath.h"
#include "../../state/boss_states.h"
namespace speed {class DracoMeteor {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void clear_placed(RunRuntime &,BossBodyState &);
};}
