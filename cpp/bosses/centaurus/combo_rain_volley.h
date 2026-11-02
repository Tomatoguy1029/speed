#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CentaurusCombo {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static bool cooldown_ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void started(RunRuntime &,TechniqueState &,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static bool advance(RunRuntime &,TechniqueState &,double);
    static void transition(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &,const ContentBundle &);
};}
