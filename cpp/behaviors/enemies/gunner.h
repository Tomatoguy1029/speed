#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class GunnerTiming {
public:
    static bool advance(double &remaining,double &charge,double dt,double warn,double interval);
};
class GunnerBehavior {
public:
    static void step(RunRuntime &,uint32_t row,double dt);
};
}
