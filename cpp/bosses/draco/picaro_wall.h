#pragma once
#include "technique.h"
namespace speed {class DracoPicaroWall {public:
    static void begin(RunRuntime &,TechniqueState &);
    static void active(RunRuntime &,TechniqueState &,double);
    static void end(RunRuntime &,TechniqueState &,bool);
    static bool validate(const DracoPicaroWallState &);
    static godot::Dictionary snapshot(const TechniqueState &);
};}
