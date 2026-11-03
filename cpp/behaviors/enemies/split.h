#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class SplitBehavior {
public:
    static void step(RunRuntime &,uint32_t row,double dt);
    static void died(RunRuntime &,const DeathContext &);
};
}
