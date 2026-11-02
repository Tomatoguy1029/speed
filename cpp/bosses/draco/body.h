#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class DracoBody {public:
    static const DracoBodyDefinition &rule(const RunRuntime &,const BossBodyState &);
    static EnemyHandle spawn(RunRuntime &,uint32_t,godot::Vector2,bool);
    static void step(RunRuntime &,BossBodyState &,double);
    static void update(RunRuntime &,BossBodyState &);
    static void cancel(RunRuntime &,BossBodyState &);
    static void damaged(RunRuntime &,BossBodyState &);
    static bool validate(const godot::RunState &,const ContentBundle &,const BossBodyState &);
    static void snapshot(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
};}
