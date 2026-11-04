#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class CanisSiriusFlame {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double attack_length(const RunRuntime &,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static bool validate(const TechniqueState &);
    static double progress(const TechniqueState &,const BossTechniqueDefinition &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
