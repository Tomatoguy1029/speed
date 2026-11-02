#pragma once
#include "../state/combat_types.h"
#include <string>
#include <vector>
#include <godot_cpp/variant/dictionary.hpp>
namespace speed {
class RunRuntime;
struct CrystalState;
enum class CrystalRemoval;
enum class CargoLoss;
class EventBuilder {
public:
    static void crystal_transferred(RunRuntime &,const CrystalState &,int64_t enemy_id,bool was_absorber);
    static void crystal_lost(RunRuntime &,const CrystalState &,int64_t enemy_id,CargoLoss);
    static void crystal_absorber_selected(RunRuntime &,const CrystalState &,uint8_t before_kind);
    static void crystal_absorber_released(RunRuntime &,uint64_t previous_id,CrystalRemoval);
    static void crystal_absorbed(RunRuntime &,const CrystalState &incoming,const CrystalState &target,double before,bool new_supply=true,int64_t carrier_id=-1);
    static void crystal_drop(RunRuntime &,const CrystalState &,bool new_supply=true,int64_t carrier_id=-1);
    static void crystal_gold_roll(RunRuntime &,const Corpse &,bool won);
    static void crystal_burst(RunRuntime &,const Corpse &);
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
