#pragma once
#include "../state/combat_types.h"
#include "collision_query.h"
#include "../state/attack_state.h"
namespace speed {
class RunRuntime;
enum class GateResult {Allow,Pass,Bounce};
class CombatResolver {
public:
    static double attack_power(const RunRuntime &);
    static EnemyHandle damage_target(const RunRuntime &,EnemyHandle);
    static GateResult gate(const RunRuntime &,EnemyHandle,const DamageRequest &);
    static double ram_damage(const RunRuntime &,EnemyHandle,double);
    static bool allows_hit(const RunRuntime &,EnemyHandle,const DamageRequest &);
    static DamageResult damage_enemy(RunRuntime &,const DamageRequest &);
    static KillResult kill_enemy(RunRuntime &,const DamageRequest &,bool one_shot=false);
    static ShipDamageResult ship_damage(RunRuntime &,const ShipDamageRequest &);
    // 被弾後の無敵を個別に数える攻撃者。ボスの技とボスの攻撃は0（機体全体の無敵を使う）。
    static int64_t attacker_of(const RunRuntime &,const AttackSpec &);
    static bool invulnerable(const RunRuntime &,const ShipDamageRequest &);
    static ShipContactResult attack_ship_damage(RunRuntime &,AttackHandle,const ContactShape &,double amount,double slow);
};
}
