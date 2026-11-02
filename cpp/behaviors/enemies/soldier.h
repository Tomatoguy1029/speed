#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class SoldierBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static bool configure(RunRuntime &,EnemyHandle,EnemyHandle,uint32_t,const SoldierFormation &,bool moving);
    static void start_mutiny(RunRuntime &,EnemyHandle,double);
    static AttackHandle fire(RunRuntime &,EnemyHandle,BudgetToken={});
};
}
