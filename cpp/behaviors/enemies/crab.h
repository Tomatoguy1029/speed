#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class CrabBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static void steer(RunRuntime &,uint32_t);
    static void clear(RunRuntime &,EnemyHandle);
    static void died(RunRuntime &,const DeathContext &);
};
}
