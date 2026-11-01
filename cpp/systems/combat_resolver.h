#pragma once
#include "../state/combat_types.h"
#include "collision_query.h"
namespace speed {
class RunRuntime;
class CombatResolver {
public:
    static EnemyHandle damage_target(const RunRuntime &,EnemyHandle);
    static bool allows_hit(const RunRuntime &,EnemyHandle,const DamageRequest &);
    static DamageResult damage_enemy(RunRuntime &,const DamageRequest &);
    static KillResult kill_enemy(RunRuntime &,const DamageRequest &,bool one_shot=false);
    static ShipDamageResult ship_damage(RunRuntime &,const ShipDamageRequest &);
    static ShipContactResult attack_ship_damage(RunRuntime &,AttackHandle,const ContactShape &,double amount,double slow);
};
}
