#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class BattleshipBehavior {
public:
    static void step(RunRuntime &,uint32_t row,double dt);
};
}
