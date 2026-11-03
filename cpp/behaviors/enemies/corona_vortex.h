#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class CoronaVortex {
public:
    static void tick(RunRuntime &,double,const std::vector<EnemyHandle> &);
    static bool hit_thrown(RunRuntime &);
    static void release(RunRuntime &,EnemyHandle);
    static void death_marked(RunRuntime &,const DeathContext &);
};
}
