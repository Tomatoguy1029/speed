#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class MonocerosReturn {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static bool validate(const TechniqueState &);
    static godot::PackedVector2Array horn(const RunRuntime &,const TechniqueState &,bool warning=false);
};}
