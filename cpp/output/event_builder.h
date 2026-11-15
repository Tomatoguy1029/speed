#pragma once
#include "../state/combat_types.h"
#include <string>
#include <vector>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
struct CrystalState;
struct CrystalCollection;
struct CapsuleState;
enum class CrystalCollectMethod;
enum class CrystalRemoval;
enum class CargoLoss;
class EventBuilder {
public:
    /// 音の欄（cue は欄ID）を1回鳴らす合図。Godot の AudioManager が欄の音で鳴らす。
    static void audio(RunRuntime &,const char *cue,godot::Vector2 pos=godot::Vector2());
    /// ループする欄を key ごとに鳴らし始める（on）・止める合図。
    static void audio_loop(RunRuntime &,const char *cue,int64_t key,bool on);
    /// ループする欄を key ごとに life 秒（実時間）だけ鳴らす合図。
    static void audio_for(RunRuntime &,const char *cue,int64_t key,double life,godot::Vector2 pos=godot::Vector2());
    static void capsule_collected(RunRuntime &,const CapsuleState &,double effect_value);
    static void crystals_collected(RunRuntime &,const std::vector<CrystalCollection> &,double base,double actual,double multiplier,CrystalCollectMethod);
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
