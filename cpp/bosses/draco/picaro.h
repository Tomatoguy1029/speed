#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class DracoPicaro {public:
    static EnemyHandle spawn(RunRuntime &,BossBodyState &,uint32_t,godot::Vector2);
    static void spawned(RunRuntime &,EnemyHandle);
    static bool adopt_clone(RunRuntime &,BossBodyState &,EnemyHandle,const std::vector<EnemyHandle> &,double,uint32_t);
    static void tick(RunRuntime &,BossBodyState &);
    static void pause(RunRuntime &,BossBodyState &,bool);
    static void clear(RunRuntime &,BossBodyState &);
    static bool validate(const godot::RunState &,const ContentBundle &,const BossBodyState &);
    static godot::Array snapshot(const RunRuntime &,const BossBodyState &);
};}
