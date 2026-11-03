#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class PartBehavior {
public:
    static void step(RunRuntime &,uint32_t row);
};
}
