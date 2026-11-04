#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class CanisBay {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double attack_length(const RunRuntime &,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static bool owns(const RunRuntime &,const BossBodyState &,EnemyHandle);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static double progress(const RunRuntime &,const TechniqueState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
