#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class PumpBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static void after_tick(RunRuntime &);
    static void gone(RunRuntime &,EnemyHandle,bool discard);
    static void death_marked(RunRuntime &,const DeathContext &);
    static void died(RunRuntime &,const DeathContext &);
};
}
