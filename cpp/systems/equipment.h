#pragma once
#include "../runtime/run_runtime.h"
namespace speed {
class EquipmentSystem {
public:
    static void contact(RunRuntime &,EnemyHandle target,godot::Vector2 position);
    static void electric_contact(RunRuntime &,EnemyHandle);
    static int64_t shot_count(RunRuntime &,int64_t base);
    static double weapon_damage_factor(const RunRuntime &,uint32_t definition);
    static bool grant(RunRuntime &,uint32_t definition,uint32_t levels=1);
    static bool remove_trait(RunRuntime &,uint32_t definition);
    static bool remove_weapon(RunRuntime &,uint32_t definition);
    static void refresh_effects(RunRuntime &);
};
}
