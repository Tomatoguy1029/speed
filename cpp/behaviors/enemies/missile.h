#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class MissileBehavior {
public:
    static void step(RunRuntime &,uint32_t row,double dt);
};
}
