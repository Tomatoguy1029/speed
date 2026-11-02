#pragma once
#include "../state/combat_types.h"
#include "../state/pickup_state.h"
namespace speed {
class RunRuntime;
enum class CrystalRemoval { Collected,Lost,Stored,Absorbed };
class PickupSystem {
public:
    static uint64_t supply(RunRuntime &,godot::Vector2,uint8_t kind);
    static bool release_crystal(RunRuntime &,size_t row,CrystalRemoval);
    static void drop_enemy(RunRuntime &,const Corpse &);
};
}
