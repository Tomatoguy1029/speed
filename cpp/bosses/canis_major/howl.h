#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class CanisHowl {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static void ring_tick(RunRuntime &,BossBodyState &);
    static bool in_ring(const BossBodyState &,EnemyHandle);
    static double radius(const RunRuntime &,const BossBodyState &);
    static bool validate(const TechniqueState &);
    static bool validate_ring(const BossBodyState &,const ContentBundle &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
    static void body_snapshot(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
};}
