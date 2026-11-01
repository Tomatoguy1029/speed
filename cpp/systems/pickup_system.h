#pragma once
#include "../state/combat_types.h"
namespace speed {
class RunRuntime;
class PickupSystem {
public:
    static void drop_enemy(RunRuntime &,const Corpse &);
};
}
