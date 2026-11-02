#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class MonocerosCharge {
public:
    static godot::Vector2 aim(const RunRuntime &,const TechniqueState &);
    static bool advance(RunRuntime &,TechniqueState &,double,const godot::PackedVector2Array &,godot::Vector2);
    static bool in_reach(const RunRuntime &,EnemyHandle,uint32_t);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t definition);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double dt);
    static void command(RunRuntime &,TechniqueState &,TechniqueCommand);
    static godot::PackedVector2Array horn(const RunRuntime &,const TechniqueState &,bool warning=false);
};
}
