#pragma once
#include "entity_store.h"
#include "combat_types.h"
#include <unordered_map>
#include <vector>
#include <deque>
#include <unordered_set>
namespace speed {
struct FriendHullState {uint32_t definition=0,source_definition=0;int64_t source_id=-1;bool saw=false;};
struct FriendDebrisState {uint32_t definition=0;DebrisStyle style=DebrisStyle::Plain;};
struct DebrisDeathFixture {uint32_t count=0;double speed=0,damage=0;};
struct ShellState {uint32_t definition=0;double burst=0,full=0;godot::Vector2 mouth;std::vector<uint32_t> contents;};
struct LightArrowState {uint32_t definition=0;float length=0;};
struct StarBoltState {uint32_t definition=0;};
struct BoltState {uint32_t definition=0;bool reference_soldier=false;};
struct SlashState {uint32_t definition=0;float side=1;uint32_t lynx_definition=0;double initial_life=0,age=0;godot::Vector2 paw_offset;};
struct BudgetToken {int64_t value=0;};
enum class EndPolicy : uint32_t { NaturalLifetime=1,CancelWithTechnique=2,EndWithTechnique=4,CancelWithParticipant=8,ClearWithBoss=16,ClearWithBonus=32 };
using EndPolicies=uint32_t;
constexpr EndPolicies policy(EndPolicy flag) {return static_cast<uint32_t>(flag);}
constexpr EndPolicies operator|(EndPolicy a,EndPolicy b) {return policy(a)|policy(b);}
constexpr bool has_policy(EndPolicies flags,EndPolicy flag) {return (flags&policy(flag))!=0;}
enum class AttackPool : uint8_t { Friendly,Hostile,Hazard };
enum class AttackEndReason : uint8_t { Lifetime,TechniqueCancel,TechniqueEnd,ParticipantEnd,BossClear,BonusClear,Hit,Relocate,Barrier };
struct AttackOwner {
    EnemyHandle live_source;
    int64_t source_id=0;
    uint32_t source_definition=0;
    BudgetToken budget;
    bool attached=false;
};
struct AttackSpec {
    AttackOwner owner;
    int64_t observation_id=0;
    EndPolicies policies=0;
    TechniqueHandle technique;ParticipantHandle participant;BossHandle boss;EncounterHandle encounter;
    Cause cause=Cause::None;WeaponId weapon=0;
    ShipContactPolicy contact;
    TechniqueId source_technique=0;
    DefinitionId damage_source=0;
    TechniqueId damage_technique=0;
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

struct LightLanceState {
    uint64_t id=0;uint32_t definition=0;
    godot::Vector2 from,velocity;
    double length=0,width=0,damage=0,knock=0,life=0;
    bool duplicate=false;
    std::unordered_set<int64_t> hits;
};
struct LanceVisualState {uint64_t id=0;godot::Vector2 from,to;double width=0,age=0;};
struct LanceEffectState {uint64_t id=0;bool hit=false;godot::Vector2 pos,direction;double radius=0,age=0;};
struct AttackState {
    std::vector<LanceVisualState> lance_visuals;
    std::vector<LanceEffectState> lance_effects;
    uint64_t next_lance_effect_id=1;
    std::deque<LightLanceState> lances;
    uint64_t next_lance_id=1;
    std::vector<AttackRecord> records;
    EntityStore<AttackTag> handles;
    std::vector<uint32_t> free_records;
    std::unordered_map<int64_t,std::vector<AttackHandle>> by_source;
    std::unordered_map<uint64_t,std::vector<AttackHandle>> by_technique,by_participant,by_boss,by_encounter;
    std::unordered_map<int64_t,DebrisDeathFixture> development_debris_sources;
    std::unordered_set<int64_t> development_hull_captures;
    int64_t next_id=1;
    uint64_t friendly_reservations=0;
    bool hostile_updating=false,hostile_clear_pending=false;
    AttackEndReason clear_reason=AttackEndReason::BossClear;
};
}
