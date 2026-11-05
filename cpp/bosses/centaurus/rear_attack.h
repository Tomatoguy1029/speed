#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {
class CentaurusRear {
public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void command(RunRuntime &,TechniqueState &,TechniqueCommand);
};
}
