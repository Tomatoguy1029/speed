#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class PulserBehavior {
public:
    static void step(RunRuntime &,uint32_t,double);
    static double ring_radius(const RunRuntime &,uint32_t);
};
}
