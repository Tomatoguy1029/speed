#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {class DracoCycle {public:
    static bool begin_initial(RunRuntime &,BossBodyState &);
    static bool begin_deep(RunRuntime &,BossBodyState &);
    static bool tick(RunRuntime &,BossBodyState &,double);
    static void cancel(RunRuntime &,BossBodyState &);
    static bool validate(const BossBodyState &);
    static void snapshot(const BossBodyState &,godot::Dictionary &);
};}
