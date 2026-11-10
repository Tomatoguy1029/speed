#pragma once
#include "../state/combat_types.h"
#include "../state/pickup_state.h"
namespace godot {class SpeedRunCore;}
namespace speed {
class RunRuntime;
enum class CrystalRemoval { Collected,Lost,Stored,Absorbed };
enum class CrystalCollectMethod {Ship,Magnet};
enum class CargoLoss {Retreat,Released,Cleared,OwnerRemoved,Capacity};
class PickupSystem {
public:
    static double collect_rows(godot::SpeedRunCore &,const std::vector<size_t> &,CrystalCollectMethod);
    static double collect_all(godot::SpeedRunCore &);
    static void step_capsules(godot::SpeedRunCore &,double dt);
    static bool carry(RunRuntime &,EnemyHandle,size_t crystal_row);
    static bool reserve(RunRuntime &,size_t count);
    static void redrop(RunRuntime &,const Corpse &,bool reserved=false);
    static void lose(RunRuntime &,int64_t enemy_id,CargoLoss);
    static void lose_all(RunRuntime &,CargoLoss);
    static void prune(RunRuntime &);
    static uint64_t supply(RunRuntime &,godot::Vector2,uint8_t kind);
    static bool release_crystal(RunRuntime &,size_t row,CrystalRemoval);
    static void drop_enemy(RunRuntime &,const Corpse &);
    static void drop_boss_damage(RunRuntime &,EnemyHandle,double applied);
};
}
