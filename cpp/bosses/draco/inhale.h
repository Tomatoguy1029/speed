#pragma once
#include "technique.h"
namespace speed {class DracoInhale {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &);
    static void active(RunRuntime &,TechniqueState &,double);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void recover(RunRuntime &,TechniqueState &);
    static bool validate(const DracoInhaleState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
};}
