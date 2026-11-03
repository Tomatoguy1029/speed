#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisCommand {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void command(RunRuntime &,TechniqueState &,TechniqueCommand);
    static void cancel(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &);
};}
