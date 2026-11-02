#pragma once
#include "../content/generated/combat_ids.h"
#include "../systems/timing.h"
#include <cstdint>
#include <vector>
namespace speed {
struct ForwardWeaponState {
    bool ready = false;
    IntervalTimer fire;
    double recoil = 0;
    double base_interval = 0, interval = 0, damage = 0, life = 0, spread = 0, knock = 0, character_scale = 0;
    int64_t pierce = 0;
};
struct ScatterWeaponState {
    bool ready=false;
    uint32_t definition=0,shots=0;
    IntervalTimer fire;
    double recoil=0,base_interval=0,interval=0,damage=0,life=0,spread=0,knock=0;
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
