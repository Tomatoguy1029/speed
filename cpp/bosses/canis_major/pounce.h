#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
namespace speed {class CanisPounce {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double cooldown(const RunRuntime &,EnemyHandle,uint32_t);
    static double flight_time(const RunRuntime &,uint32_t);
    static double attack_length(const RunRuntime &,EnemyHandle,uint32_t);
    static void start(RunRuntime &,TechniqueState &,CanisPounceState &,uint32_t definition,int64_t count=1);
    static bool advance(RunRuntime &,TechniqueState &,CanisPounceState &,double);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static bool validate(const CanisPounceState &,const ContentBundle &);
    static double progress(const CanisPounceState &);
    static godot::Dictionary motion_snapshot(const RunRuntime &,const CanisPounceState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
