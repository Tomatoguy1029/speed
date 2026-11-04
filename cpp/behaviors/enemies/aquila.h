#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class AquilaBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static void cruise(RunRuntime &,uint32_t,double);
    static void before_move(RunRuntime &,EnemyHandle,double);
    static void after_move(RunRuntime &,EnemyHandle);
};
}
