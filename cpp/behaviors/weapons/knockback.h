#pragma once
#include "../../state/combat_types.h"
namespace speed {
class RunRuntime;
class KnockbackBehavior {
public:
    static void defeated(RunRuntime &,const DeathContext &);
    static void step(RunRuntime &,double);
    static void hit(RunRuntime &,godot::Vector2);
};
}
