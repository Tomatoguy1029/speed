#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisRelay {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double attack_length(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static double progress(const RunRuntime &,const TechniqueState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
    static bool tinted(const RunRuntime &,const BossBodyState &,EnemyHandle);
};}
