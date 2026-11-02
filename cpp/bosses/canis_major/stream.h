#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisStream {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double attack_length(const RunRuntime &,EnemyHandle,uint32_t);
    static void start(RunRuntime &,TechniqueState &,CanisStreamState &,uint32_t);
    static bool advance(RunRuntime &,TechniqueState &,CanisStreamState &,double);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
