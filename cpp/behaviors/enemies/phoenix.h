#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct DeathContext;
class PhoenixBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static void cancel(RunRuntime &,EnemyHandle);
    static void died(RunRuntime &,const DeathContext &);
};
}
