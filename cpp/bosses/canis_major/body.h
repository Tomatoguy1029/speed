#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisMajorBody {public:
    static const CanisBodyDefinition &rule(const RunRuntime &,const BossBodyState &);
    static EnemyHandle spawn(RunRuntime &,uint32_t,godot::Vector2,bool);
    static void step(RunRuntime &,BossBodyState &,double);
    static void call_tick(RunRuntime &,BossBodyState &,double);
    static void lead(RunRuntime &,BossBodyState &,double);
    static void release(RunRuntime &,BossBodyState &);
    static bool validate(const godot::RunState &,const ContentBundle &,const BossBodyState &);
    static godot::Color color(const RunRuntime &,EnemyHandle,godot::Color);
    static void snapshot(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
};}
