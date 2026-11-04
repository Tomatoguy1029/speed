#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CentaurusSail {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void release(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
