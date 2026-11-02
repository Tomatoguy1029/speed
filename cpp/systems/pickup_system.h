#pragma once
#include "../state/combat_types.h"
#include "../state/pickup_state.h"
namespace speed {
class RunRuntime;
enum class CrystalRemoval { Collected,Lost,Stored,Absorbed };
enum class CargoLoss {Retreat,Released,Cleared,OwnerRemoved};
class PickupSystem {
public:
    static bool carry(RunRuntime &,EnemyHandle,size_t crystal_row);
    static void redrop(RunRuntime &,const Corpse &);
    static void lose(RunRuntime &,int64_t enemy_id,CargoLoss);
    static void lose_all(RunRuntime &,CargoLoss);
    static void prune(RunRuntime &);
    static uint64_t supply(RunRuntime &,godot::Vector2,uint8_t kind);
    static bool release_crystal(RunRuntime &,size_t row,CrystalRemoval);
    static void drop_enemy(RunRuntime &,const Corpse &);
};
}
