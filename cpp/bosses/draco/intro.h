#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {class DracoIntro {public:
    static void begin(RunRuntime &,BossBodyState &);
    static bool tick(RunRuntime &,BossBodyState &,double);
    static void end(RunRuntime &,BossBodyState &,bool interrupted=false);
    static bool validate(const godot::RunState &,const BossBodyState &);
    static void snapshot(const BossBodyState &,godot::Dictionary &);
};}
