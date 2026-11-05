#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class CanisBlaze {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double attack_length(const RunRuntime &,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static bool validate(const TechniqueState &);
    static double progress(const TechniqueState &,const BossTechniqueDefinition &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
    static bool burning(const BossBodyState &,EnemyHandle);
    static void burning_tick(RunRuntime &,BossBodyState &,double);
    static void clear(RunRuntime &,BossBodyState &);
    static bool validate_body(const godot::RunState &,const ContentBundle &,const BossBodyState &);
    static void body_snapshot(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
};}
