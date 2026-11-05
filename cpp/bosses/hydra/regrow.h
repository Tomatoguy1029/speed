#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
namespace speed {class HydraRegrow {public:
    static const HydraRegrowDefinition &rule(const RunRuntime &,const BossBodyState &);
    static bool alive(const RunRuntime &,const HydraNeckState &);
    static void set_count(RunRuntime &,BossBodyState &,uint32_t);
    static void damaged(RunRuntime &,BossBodyState &);
    static bool growth_tick(RunRuntime &,BossBodyState &,double);
    static void chance_tick(RunRuntime &,BossBodyState &,double);
    static bool tick_dead(RunRuntime &,BossBodyState &,HydraNeckState &,double);
    static void part_defeated(RunRuntime &,const DeathContext &);
    static bool validate(const BossBodyState &);
};}
