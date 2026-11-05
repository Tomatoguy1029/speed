#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {class DracoFinale {public:
    static bool begin(RunRuntime &,BossBodyState &);
    static bool tick(RunRuntime &,double,const InputFrame &,godot::Vector2);
    static void dispose(RunRuntime &,BossBodyState &);
    static bool validate(const BossBodyState &);
    static void snapshot(const BossBodyState &,godot::Dictionary &);
};}
