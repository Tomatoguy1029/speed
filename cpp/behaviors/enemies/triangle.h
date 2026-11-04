#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class TriangleBehavior {
public:
    static void spawned(RunRuntime &,EnemyHandle);
    static void step(RunRuntime &,uint32_t,double);
    static void after_tick(RunRuntime &,const std::vector<EnemyHandle> &);
};
}
