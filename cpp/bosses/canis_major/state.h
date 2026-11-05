#pragma once
#include "../../state/boss_states.h"
#include "image_pose_state.h"
#include "fire_visual_state.h"
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct CanisSiriusState {uint32_t shot=0;double age=0,gap_left=0;bool fired=false;};
struct CanisPounceState {uint32_t definition=0;int64_t left=1;double stage_time=0,warn_time=0;bool jumping=false,done=false;};
struct CanisBayMember {EnemyHandle actor;double angle=0,phase=0,cool=0,bark=0,warn=-1;AttackHandle lunge;bool nipping=false;};
struct CanisBayState {std::vector<CanisBayMember> members;CanisPounceState jump;double heading=0;bool jumping=false;};
struct CanisBlazeChosen {EnemyHandle actor;double at=0;bool sent=false,lit=false;};
struct CanisBlazeState {std::vector<CanisBlazeChosen> chosen;double age=0;};
struct CanisSequenceItem {EnemyHandle actor;double mark=0,launch=0;bool marked=false,launched=false;};
struct CanisHowlState {bool formed=false;double last_launch=0;std::vector<CanisSequenceItem> sequence;};
struct CanisCommandState {std::vector<EnemyHandle> warned;bool warning_started=false;};
struct CanisStreamState {uint32_t definition=0;bool sent=false;double started=0,last_launch=0;std::vector<CanisSequenceItem> sequence;};
struct CanisFlameAimState {double age=0;bool fired=false,done=false;};
struct CanisHuntState {CanisStreamState stream;CanisFlameAimState aim;bool aiming=false,combo_pending=true;};
struct CanisHuntPounceState {CanisStreamState stream;CanisPounceState jump;bool jumping=false,combo_pending=true;};
struct CanisNovaPair {EnemyHandle actor;uint32_t group=0;double angle=0,side=1;bool stationed=false;};
struct CanisNovaShadow {double angle=0,half=0,near=0;};
struct CanisNovaState {
    double started=0;
    std::vector<CanisNovaPair> pairs;
    std::vector<CanisNovaShadow> shadows;
    std::vector<bool> ring_hit;
    bool flashed=false,released=false;
    // 判定と表示が同じワールド位置で参照する、24fps単位の遮光場。
    std::vector<uint8_t> field_alpha;
    godot::Vector2 field_origin;
    double field_cell=0;
    int64_t field_frame=-1;
    uint32_t field_width=0,field_height=0;
    uint64_t field_revision=0;
};
struct CanisRelayItem {EnemyHandle actor;double at=0,angle=0;godot::Vector2 from;bool marked=false,fired=false,released=false;};
struct CanisRelayState {CanisFlameAimState aim;double started=0,last_fire=0,tint_until=0;std::vector<CanisRelayItem> items;bool ordered=false,aiming=false,cancelled=false;};
struct CanisSiriusFlameState {double age=0,emit_left=0;bool started=false;};
struct CanisHoundRef {EnemyHandle actor;double base_hp=0;godot::Color color;};
struct CanisRingMember {EnemyHandle actor;double angle=0;};
struct CanisBurningHound {EnemyHandle actor;int64_t observation_id=0,effect_id=0;godot::Vector2 observation_pos;uint32_t definition=0,technique=0;double base_hp=0,age=0,blink_age=-1;godot::Color color;};
struct CanisBlazeBurst {godot::Vector2 position;double radius=0,started=0;int64_t id=0;uint32_t technique=0;};
struct CanisBodyState {
    CanisImagePoseClock image_pose;
    CanisFireVisualState fire_visual;
    int64_t roar_last_technique=0,roar_serial=0;
    uint32_t roar_definition=0;
    double roar_started=-1;
    TechniqueHandle nova;
    std::vector<CanisBurningHound> burning;
    std::vector<CanisBlazeBurst> bursts;
    std::vector<CanisRingMember> ring;
    godot::Vector2 ring_center;
    double ring_started=-1,ring_tick_at=0;
    uint32_t ring_definition=0;
    bool pack_spawned=false,barking=false,calling=false;
    double call_left=0,call_ready_at=0,lead_scan=0,turn_motion=0;
    std::unordered_set<int64_t> lunge_hits;
    std::vector<CanisHoundRef> led;
    std::vector<EnemyHandle> lunging;
};
}
