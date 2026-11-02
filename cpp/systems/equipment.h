#pragma once
#include "../runtime/run_runtime.h"
namespace speed {
class EquipmentSystem {
public:
    static double weapon_damage_factor(const RunRuntime &,uint32_t definition);
    static bool grant(RunRuntime &,uint32_t definition,uint32_t levels=1);
    static bool remove_trait(RunRuntime &,uint32_t definition);
    static bool remove_weapon(RunRuntime &,uint32_t definition);
    static void refresh_effects(RunRuntime &);
};
}
