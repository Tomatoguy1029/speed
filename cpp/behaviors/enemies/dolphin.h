#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class DolphinBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
};
}
