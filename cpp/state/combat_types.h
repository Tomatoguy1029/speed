#pragma once
#include "entity_store.h"
#include "../content/generated/combat_ids.h"
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
using DefinitionId=uint32_t;
using WeaponId=uint32_t;
using TechniqueId=uint32_t;
enum class CombatReason { Applied, Invalid, Dead, Nonpositive, RunPhase, Guard, ControlsLocked, EncounterProtected, DamageGate, PhaseFloor, BossDefeated, Shield, Invulnerability, DebugInvincible, Barrier };
enum class DamageScale { None, AtkScale };
enum class HitPolicy { MarkBefore, MarkAfter, MarkIfAccepted, EveryTick };
struct ShipContactPolicy {
    DamageScale scale=DamageScale::None;
    HitPolicy hit_policy=HitPolicy::MarkAfter;
    bool add_ship_radius=true,ship_sweep=false;
};
enum class RetireReason { Outside, Relocate, Regenerate, BonusClear, Development, DeathCleanup };
struct DamageRequest {
    EnemyHandle struck;
    double amount=0, knock=160;
    Cause cause=Cause::None;
    WeaponId weapon_id=0;
    godot::Vector2 direction, impact;
    bool has_impact=false, crit=false, no_crit=false;
    int32_t shatter_depth=0;
};
struct DamageResult {
    double requested=0,resolved=0,applied=0,overkill=0,hp_before=0,hp_after=0;
    EnemyHandle struck,target;
    bool killed=false;
    CombatReason reason=CombatReason::Invalid;
};
struct Corpse {
    int64_t id=0;DefinitionId definition=0;
    godot::Vector2 pos,vel;double radius=0,facing=0,max_hp=0,xp=0;
    bool elite=false,is_boss=false;
    uint32_t rare_weapon=0;
    double attack_priority=0;
};
struct DeathContext {
    Corpse corpse;
    DamageRequest request;
    EnemyHandle target;
    bool hull_used=false,one_shot=false;
};
struct KillResult { EnemyHandle target;bool killed=false;CombatReason reason=CombatReason::Invalid; };
struct ShipDamageRequest {
    bool source_is_explicit=false;
    int64_t observation_id=0;
    godot::Vector2 impact;
    bool has_impact=false;
    double amount=0,slow=0;
    DamageScale scale=DamageScale::None;
    Cause cause=Cause::None;
    DefinitionId source=0;
    TechniqueId technique=0;
    HitPolicy hit_policy=HitPolicy::EveryTick;
};
struct ShipDamageResult { bool accepted=false;CombatReason reason=CombatReason::Invalid;double hp_before=0,hp_after=0,amount=0; };
struct ShipContactResult {bool touching=false,attempted=false;ShipDamageResult damage;};
enum class AttackEndReason : uint8_t;
enum class AttackPool : uint8_t;
enum class CombatEventKind { AttackRetired, EnemyDamage, Hit, CriticalHit, Kill, ShieldBlock, ShipDamage, Hurt, Retire };
// 表示と観測は値を待ち列へ写す。死亡後の行の再利用に依存させない。
struct FloodTailState {
    bool ready=false;uint32_t row=0;godot::Vector2 pos;
    double angle=0,length=0,width=0,spread=0,age=0;
};
struct CombatEvent {
    FloodTailState flood;
    uint32_t zone_definition=0;
    AttackEndReason attack_end_reason{};AttackPool attack_pool{};int64_t source_entity_id=0;
    CombatEventKind kind=CombatEventKind::EnemyDamage;
    Cause cause=Cause::None;
    CombatReason reason=CombatReason::Applied;
    RetireReason retire_reason=RetireReason::Outside;
    SpawnOrigin origin=SpawnOrigin::Normal;
    SpawnRole role=SpawnRole::Regular;
    int64_t struck_id=0,target_id=0,observation_id=0;
    DefinitionId definition=0,source=0;
    WeaponId weapon_id=0;
    TechniqueId technique=0;
    godot::Vector2 pos,impact,direction;
    double requested=0,resolved=0,applied=0,overkill=0,hp_before=0,hp_after=0;
    double radius=0,facing=0,time=0,world_time=0;
    bool crit=false,elite=false,killed=false,accepted=false,circle_hazard=false,source_is_explicit=false;
    int32_t shatter_depth=0;int64_t meteor_index=-1;
};
const char *combat_reason_name(CombatReason reason);
}
