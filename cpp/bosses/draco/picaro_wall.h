#pragma once
#include "technique.h"
#include "../../state/boss_states.h"
#include "state.h"
namespace speed {class DracoPicaroWall {public:
    static void begin(RunRuntime &,TechniqueState &);
    static double shout_facing(double,double);
    static void roar(RunRuntime &,const TechniqueState &);
    static void windup(RunRuntime &,TechniqueState &);
    static void active(RunRuntime &,TechniqueState &,double);
    static void recover(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static bool validate(const DracoPicaroWallState &);
    static godot::Dictionary snapshot(const TechniqueState &);
};}
