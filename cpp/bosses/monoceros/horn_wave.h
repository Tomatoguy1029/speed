#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class MonocerosHornWave {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static bool validate(const TechniqueState &);
    static void advance_waves(RunRuntime &,double);
    static godot::Array waves(const RunRuntime &,EnemyHandle);
    static godot::PackedVector2Array horn(const RunRuntime &,const TechniqueState &);
};}
