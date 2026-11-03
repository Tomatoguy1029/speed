#pragma once
#include "../../state/combat_types.h"
namespace speed {
class RunRuntime;
class BarrierBehavior {
public:
    static bool block(RunRuntime &,const ShipDamageRequest &,double amount);
    static double segment(const RunRuntime &,godot::Vector2 from,godot::Vector2 to,double radius,const ShipDamageRequest &);
    static void step(RunRuntime &,double dt);
};
}
