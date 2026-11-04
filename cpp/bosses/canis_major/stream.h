#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class CanisStream {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double attack_length(const RunRuntime &,EnemyHandle,uint32_t);
    static double order_start(const ContentBundle &,uint32_t,double);
    static double hound_warning(const ContentBundle &,uint32_t,double);
    static void start(RunRuntime &,TechniqueState &,CanisStreamState &,uint32_t);
    static bool advance(RunRuntime &,TechniqueState &,CanisStreamState &,double,bool manual_retained=false);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static bool validate(const CanisStreamState &,const ContentBundle &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
    static godot::Dictionary snapshot(const RunRuntime &,EnemyHandle,const CanisStreamState &);
};}
