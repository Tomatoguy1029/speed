#pragma once
#include "../content/generated/combat_ids.h"
#include "../systems/timing.h"
#include <cstdint>
#include <vector>
#include <unordered_set>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct ForwardWeaponState {
    bool ready = false;
    IntervalTimer fire;
    double recoil = 0;
    double base_interval = 0, interval = 0, damage = 0, life = 0, spread = 0, knock = 0, character_scale = 0;
    int64_t pierce = 0;
};
struct RearWeaponState : ForwardWeaponState {
    uint32_t definition=0,color=0;
    double mount_x=0,mount_y=0,muzzle_distance=0;
};
struct ScatterWeaponState {
    bool ready=false;
    uint32_t definition=0,shots=0;
    IntervalTimer fire;
    double recoil=0,base_interval=0,interval=0,damage=0,life=0,spread=0,knock=0;
};
struct BarrierWaveState {
    godot::Vector2 pos;
    double age=0,radius=0,damage=0,angle=0;
    bool broken=false;
    std::unordered_set<int64_t> hits;
};
struct BarrierWeaponState {
    bool ready=false;
    uint32_t definition=0;
    double restore_visual_age=1;
    double durability=-1,restore=0,maximum=0,revive=0,radius=0,damage=0,shell_radius=0,knock=0;
    std::vector<BarrierWaveState> waves;
};
struct EquipmentLevel {uint32_t definition=0,level=0;};
struct CardCandidate {int64_t id=0;CardKind kind=CardKind::Weapon;uint32_t definition=0,level=0;};
// 数値特性は取得の境界で畳み、武器の更新中には定義を探索しない。
struct EquipmentEffects {
    double area=1,shot_amount=1,full_gauge_rate=0;
    double burst_power=1,damage_multiplier=1;
};
struct LoadoutState {
    EquipmentEffects effects;
    ScatterWeaponState scatter;
    RearWeaponState rear;
    BarrierWeaponState barrier;
    uint64_t post_weapon_interval_stacks=0,post_projectile_speed_stacks=0,post_duration_stacks=0,post_knockback_stacks=0;

    double charge_profile_factor=1,speed_profile_factor=1,attack_profile_factor=1,pickup_profile_factor=1,length_profile_factor=1;
    uint64_t post_charge_stacks=0,post_crit_stacks=0,post_max_speed_stacks=0,post_weapon_damage_stacks=0,post_followup_stacks=0,post_xp_pickup_stacks=0,post_line_length_stacks=0;
    std::vector<double> weapon_damage_factors;
    bool ready=false,initial_offer=false;
    int64_t level=0,pending_levels=0,rerolls=0,next_offer_id=1,offer_id=0,selected_id=0;
    double xp=0,xp_gained=0,xp_gain_mult=1;
    std::vector<EquipmentLevel> weapons,traits;
    std::vector<uint32_t> pending_comet_weapons;
    std::vector<CardCandidate> candidates;
};
}
