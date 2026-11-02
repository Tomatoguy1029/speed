#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisFlames {public:
    static AttackHandle begin(RunRuntime &,BossBodyState &,uint32_t,EnemyHandle target={},int64_t observation=0,uint32_t technique=0);
    static void step(RunRuntime &,BossBodyState &,double);
    static bool validate(const godot::RunState &,const ContentBundle &);
    static godot::Array snapshot(const RunRuntime &,const BossBodyState &);
};}
