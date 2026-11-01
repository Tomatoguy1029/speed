#pragma once
#include "../state/combat_types.h"
#include <string>
#include <vector>
#include <godot_cpp/variant/dictionary.hpp>
namespace speed {
class RunRuntime;
class EventBuilder {
public:
    static void budget_started(RunRuntime &,const std::string &owner,int64_t id,uint32_t row,const std::vector<AttackCategory> &,int64_t token);
    static void budget_ended(RunRuntime &,const std::string &owner,int64_t token);
    static void enemy_damage(RunRuntime &,const DamageRequest &,const DamageResult &);
    static void enemy_hit(RunRuntime &,const DamageRequest &,EnemyHandle);
    static void enemy_kill(RunRuntime &,const DeathContext &);
    static void player_damage(RunRuntime &,const ShipDamageRequest &,const ShipDamageResult &);
    // 未移行のGodot出力との接点。戦闘ループは型付き待ち列だけを書く。
    static void flush_combat(RunRuntime &);
    static godot::Dictionary damage_result(const RunRuntime &,const DamageResult &);
    static godot::Dictionary ship_result(const ShipDamageResult &);
};
}
