#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class TriangleStarBehavior {
public:
    static void step(RunRuntime &,uint32_t);
    static bool passes(const RunRuntime &,EnemyHandle);
};
}
