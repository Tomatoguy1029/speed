#pragma once
#include "technique.h"
namespace speed {class DracoCharge {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &,double);
    static void active(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void recover(RunRuntime &,TechniqueState &);
    static bool validate(const DracoChargeState &);
    static godot::Dictionary snapshot(const TechniqueState &);
};}
