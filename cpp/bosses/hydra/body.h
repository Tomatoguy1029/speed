#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class HydraBody {public:
    static const HydraBodyDefinition &rule(const RunRuntime &,const BossBodyState &);
    static EnemyHandle spawn(RunRuntime &,uint32_t,godot::Vector2,bool);
    static void spawned(RunRuntime &,BossBodyState &);
    static godot::Vector2 neck_base(const RunRuntime &,const BossBodyState &,const HydraNeckState &);
    static godot::Vector2 head_position(const RunRuntime &,const BossBodyState &,const HydraNeckState &);
    static void follow_neck(RunRuntime &,BossBodyState &,HydraNeckState &,double);
    static void step(RunRuntime &,BossBodyState &,double);
    static void finish_frame(RunRuntime &,double);
    static void release(RunRuntime &,BossBodyState &);
    static void part_defeated(RunRuntime &,const DeathContext &);
    static bool validate(const godot::RunState &,const ContentBundle &,const BossBodyState &);
    static void snapshot(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
    static bool passes(const RunRuntime &,EnemyHandle);
    static bool owns_part(const RunRuntime &,EnemyHandle);
};}
