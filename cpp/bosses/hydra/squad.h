#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
namespace speed {class HydraSquad {public:
    static const HydraSquadDefinition &rule(const RunRuntime &,const BossBodyState &);
    static HydraSquadRole profile(const HydraNeckState &);
    static void init(RunRuntime &,BossBodyState &);
    static void tick(RunRuntime &,BossBodyState &,double);
    static void tick_bearer(RunRuntime &,BossBodyState &,double);
    static void watch_player(RunRuntime &,BossBodyState &,HydraNeckState &,HydraSquadRole);
    static void update_look(RunRuntime &,BossBodyState &,HydraNeckState &,double,HydraSquadRole,bool);
    static void replan(RunRuntime &,BossBodyState &);
    static void tactic(RunRuntime &,BossBodyState &,double);
    static void counter(RunRuntime &,BossBodyState &,double);
    static void block(RunRuntime &,BossBodyState &);
    static godot::Vector2 attack_slot(const RunRuntime &,const BossBodyState &,const HydraNeckState &,uint32_t,double);
    static void started(BossBodyState &,HydraNeckState &);
    static double range(const HydraSquadDefinition &,HydraHeadKind);
    static bool custom_owns(const RunRuntime &,const BossBodyState &,const HydraNeckState &);
    static bool validate(const HydraBodyState &);
};}
