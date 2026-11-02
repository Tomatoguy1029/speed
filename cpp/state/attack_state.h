#pragma once
#include "entity_store.h"
#include "combat_types.h"
#include <unordered_map>
#include <vector>
namespace speed {
struct SlashState {uint32_t definition=0;float side=1;};
struct BudgetToken {int64_t value=0;};
enum class EndPolicy : uint32_t { NaturalLifetime=1,CancelWithTechnique=2,EndWithTechnique=4,CancelWithParticipant=8,ClearWithBoss=16,ClearWithBonus=32 };
using EndPolicies=uint32_t;
constexpr EndPolicies policy(EndPolicy flag) {return static_cast<uint32_t>(flag);}
constexpr EndPolicies operator|(EndPolicy a,EndPolicy b) {return policy(a)|policy(b);}
constexpr bool has_policy(EndPolicies flags,EndPolicy flag) {return (flags&policy(flag))!=0;}
enum class AttackPool : uint8_t { Friendly,Hostile,Hazard };
enum class AttackEndReason : uint8_t { Lifetime,TechniqueCancel,TechniqueEnd,ParticipantEnd,BossClear,BonusClear,Hit,Relocate };
struct AttackOwner {
    EnemyHandle live_source;
    int64_t source_id=0;
    uint32_t source_definition=0;
    BudgetToken budget;
    bool attached=false;
};
struct AttackSpec {
    AttackOwner owner;
    EndPolicies policies=0;
    TechniqueHandle technique;ParticipantHandle participant;BossHandle boss;EncounterHandle encounter;
    Cause cause=Cause::None;WeaponId weapon=0;
    ShipContactPolicy contact;
    TechniqueId source_technique=0;
    uint32_t contact_definition=0;
};
struct AttackRecord {
    AttackSpec spec;
    AttackPool pool=AttackPool::Friendly;
    uint32_t row=0;
    int64_t id=0;
    bool alive=false;
    bool ship_hit=false;
    godot::Vector2 ship_previous;
    bool ship_previous_ready=false;
};

struct AttackState {
    std::vector<AttackRecord> records;
    EntityStore<AttackTag> handles;
    std::vector<uint32_t> free_records;
    std::unordered_map<int64_t,std::vector<AttackHandle>> by_source;
    std::unordered_map<uint64_t,std::vector<AttackHandle>> by_technique,by_participant,by_boss,by_encounter;
    int64_t next_id=1;
    bool hostile_updating=false,hostile_clear_pending=false;
    AttackEndReason clear_reason=AttackEndReason::BossClear;
};
}
