#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class MonocerosCharge {
public:
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double dt);
    static void command(RunRuntime &,TechniqueState &,TechniqueCommand);
    static godot::PackedVector2Array horn(const RunRuntime &,const TechniqueState &,bool warning=false);
};
}
