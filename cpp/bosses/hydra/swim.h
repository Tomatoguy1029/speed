#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class HydraSwim {public:
    static const HydraSwimDefinition &rule(const RunRuntime &,const BossBodyState &);
    static bool begin(RunRuntime &,BossBodyState &);
    static bool step(RunRuntime &,BossBodyState &,double);
    static void follow(RunRuntime &,BossBodyState &,HydraNeckState &,double);
    static void steer(RunRuntime &,BossBodyState &,HydraNeckState &,godot::Vector2,double,double=1,bool=false);
    static void finish_step(RunRuntime &,BossBodyState &,HydraNeckState &,godot::Vector2,double);
    static godot::Vector2 destination(const RunRuntime &,const BossBodyState &,const HydraNeckState &,godot::Vector2,bool);
    static bool bearer_defeated(RunRuntime &,const DeathContext &);
};}
