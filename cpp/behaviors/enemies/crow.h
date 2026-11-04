#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct CrowCargo {uint32_t count=0;double amount=0;};
class CrowBehavior {
public:
    static void spawned(RunRuntime &,EnemyHandle,bool member);
    static void step(RunRuntime &,uint32_t row);
    static void gather(RunRuntime &,double dt);
    static CrowCargo cargo(const RunRuntime &,EnemyHandle);
};
}
