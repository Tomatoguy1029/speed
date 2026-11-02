#pragma once
#include "world_state.h"
#include "enemy_states.h"
#include <godot_cpp/variant/color.hpp>
namespace speed {
struct HoundSteering {
    double arrive=0,decel=0,face_turn=0,turn_slow=0,turn_fast=0,turn_switch=0,max_speed=0,accel=0;
};
struct HoundOrder {
    bool follow=false,steer=false,quiet=false,warning=false,quiet_velocity_set=false;
    godot::Vector2 follow_goal,steer_goal,face_point,quiet_velocity;
    double follow_until=0,follow_scale=1,steer_until=0,quiet_until=0,warning_until=0,heading=0,speed=0;
    HoundSteering steering;
};
struct GroupMember {EnemyHandle actor;HoundOrder order;};
struct Group {
    enum class Kind {Hounds,Cepheus} kind=Kind::Hounds;
    // 群れの番号は最初の個体ID。生存している親は要求しない。
    EnemyHandle leader;SoldierFormation formation;
    OrderedValues<int64_t,GroupMember> members;
};
struct CepheusMark {Vector2 pos,king;godot::Color color;double age=0,life=0;};
struct GroupState {OrderedValues<int64_t,Group> groups;std::vector<CepheusMark> summon_marks;};
}
