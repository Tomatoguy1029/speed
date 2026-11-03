#pragma once
#include "technique.h"
namespace speed {class DracoRifts {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &,double);
    static void active(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void tick_closing(RunRuntime &,BossBodyState &,double);
    static void clear(RunRuntime &,BossBodyState &);
    static bool validate(const DracoRiftsState &);
    static bool validate_body(const DracoBodyState &);
    static godot::Dictionary snapshot(const TechniqueState &);
    static void snapshot_body(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
};}
