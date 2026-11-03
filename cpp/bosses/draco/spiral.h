#pragma once
#include "technique.h"
namespace speed {class DracoSpiral {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &,double);
    static void active(RunRuntime &,TechniqueState &,double);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void recover(RunRuntime &,TechniqueState &);
    static bool validate(const DracoSpiralState &);
    static godot::Dictionary snapshot(const TechniqueState &);
};}
