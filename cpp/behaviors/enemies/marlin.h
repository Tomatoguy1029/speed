#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class MarlinBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static void before_move(RunRuntime &,EnemyHandle,double);
    static void after_tick(RunRuntime &,const std::vector<EnemyHandle> &);
};
}
