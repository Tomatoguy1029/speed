#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {class CentaurusFinish {public:
    static void leap(RunRuntime &,BossBodyState &);
    static bool idle(RunRuntime &,BossBodyState &);
    static void leap_tick(RunRuntime &,BossBodyState &,double);
};}
