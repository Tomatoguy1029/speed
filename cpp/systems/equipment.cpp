#include "equipment.h"
#include "../behaviors/weapons/forward.h"
#include <algorithm>
#include <cmath>
namespace speed {
void EquipmentSystem::refresh_effects(RunRuntime &run) {
    auto &effects=run.state.loadout.effects;
    run.state.loadout.full_charge_maximum=1;
    run.state.loadout.full_burst_owned=false;
    bool rampage_owned=false;
    run.state.loadout.duplicator={};
    effects.area=effects.shot_amount=1;effects.full_gauge_rate=0;double charge_bonus=0,capacity_bonus=0,crit_bonus=0,speed_bonus=0,attack_bonus=0,pickup_bonus=0,length_bonus=0,glide_bonus=0;
    for (const auto &owned:run.state.loadout.traits) {
        if (run.content->equipment[owned.definition-1].external_id=="T36") run.state.loadout.full_burst_owned=true;
        for (const auto &level:run.content->duplicator_levels) if (level.equipment==owned.definition && level.level==owned.level) {
            auto &d=run.state.loadout.duplicator;d.ready=true;d.chance=level.chance;d.damage=level.damage;d.maximum=level.maximum;d.angle_min=level.angle_min;d.angle_max=level.angle_max;
        }
        for (const auto &level:run.content->rampage_levels) if (level.equipment==owned.definition && level.level==owned.level) {
            auto &rampage=run.state.loadout.rampage;rampage.ready=true;rampage.bonus=level.bonus;rampage.target_kills=level.kills;rampage.half_life=level.half_life;rampage_owned=true;
        }
        for (const auto &level:run.content->full_charge_levels) if (level.equipment==owned.definition && level.level==owned.level) run.state.loadout.full_charge_maximum=level.multiplier;
        for (const auto &level:run.content->numeric_traits) if (level.equipment==owned.definition && level.level==owned.level) {
            effects.area+=level.area_bonus;effects.shot_amount+=level.shot_bonus;effects.full_gauge_rate+=level.full_gauge_rate;charge_bonus+=level.charge_bonus;capacity_bonus+=level.capacity_bonus;crit_bonus+=level.crit_bonus;speed_bonus+=level.speed_bonus;attack_bonus+=level.attack_bonus;pickup_bonus+=level.pickup_bonus;length_bonus+=level.length_bonus;glide_bonus+=level.glide_bonus;
        }
    }
    if (!run.state.loadout.full_burst_owned) run.state.loadout.full_burst_active=false;
    if (!rampage_owned) run.state.loadout.rampage={};
    effects.damage_multiplier=1+run.state.loadout.rampage.bonus*run.state.loadout.rampage.strength;
    if (run.state.loadout.full_charge_maximum==1) {effects.burst_power=1;effects.ignore_armor=false;}
    run.state.trace_radius=run.content->config.trace_radius*effects.area;
    run.state.ship_config.glide_duration_mult=1.0+glide_bonus;
    run.state.draw_config.capacity=1.0+capacity_bonus;
    const auto &p=run.state.loadout;const auto &post=run.content->post_charge;
    const double base=run.content->config.draw_config_charge_time*p.charge_profile_factor/(1.0+charge_bonus);
    const double floor=std::min(base,std::max(post.minimum_time,base*post.minimum_ratio));
    run.state.draw_config.charge_time=std::max(floor,base*(1.0-post.increment*double(p.post_charge_stacks)));
    run.state.draw_config.length_mult=p.length_profile_factor*(1.0+length_bonus)*(1.0+run.content->post_draw.line_length_increment*double(p.post_line_length_stacks));
    run.state.pickup_config.coin_radius=run.content->config.coin_radius*p.pickup_profile_factor*(1.0+pickup_bonus);
    run.state.pickup_config.xp_radius=run.state.pickup_config.coin_radius*(1.0+run.content->post_pickup.xp_radius_increment*double(p.post_xp_pickup_stacks));
    run.state.combat_config.attack_mult=p.attack_profile_factor*(1.0+attack_bonus);
    auto &powers=run.state.loadout.weapon_damage_factors;powers.assign(run.content->equipment.size(),1.0);
    for (const auto &power:run.content->post_weapon_power) powers[power.equipment-1]=1.0+power.damage_increment*double(p.post_weapon_damage_stacks)+power.followup_increment*double(p.post_followup_stacks);
    run.state.ship_config.max_speed=run.content->config.ship_config_base_max_speed*p.speed_profile_factor*(1.0+speed_bonus)*(1.0+run.content->post_motion.max_speed_increment*double(p.post_max_speed_stacks));
    const auto &crit=run.content->post_crit;const double crit_base=run.content->config.combat_crit_chance;
    const double cap=std::min(1.0,crit.trait_maximum),trained=std::min(cap,crit_base+crit.trained_bonus);
    const double reserve=std::max(0.0,cap-trained);
    run.state.combat_config.crit_chance=std::min(crit.trait_maximum,crit_base+crit_bonus)+std::min(reserve,crit.increment*double(p.post_crit_stacks));
}
int64_t EquipmentSystem::shot_count(RunRuntime &run,int64_t base) {
    const double amount=double(base)*run.state.loadout.effects.shot_amount;
    const auto whole=int64_t(std::floor(amount));
    // 整数のときも1回抽選し、武器間で乱数の消費順をそろえる。
    return whole+(run.state.control.rng.randf()<amount-double(whole)?1:0);
}
double EquipmentSystem::weapon_damage_factor(const RunRuntime &run,uint32_t id) {
    const auto &powers=run.state.loadout.weapon_damage_factors;return id && id<=powers.size()?powers[id-1]:1.0;
}
bool EquipmentSystem::grant(RunRuntime &run,uint32_t id,uint32_t levels) {
    if (!levels || !id || id>run.content->equipment.size()) return false;
    const auto &d=run.content->equipment[id-1];
    auto &owned=d.kind==0?run.state.loadout.weapons:run.state.loadout.traits;
    auto current=std::find_if(owned.begin(),owned.end(),[&](const auto &v){return v.definition==id;});
    const uint32_t old=current==owned.end()?0:current->level;
    if (old>=d.maximum_level || (!old && owned.size()>=(d.kind==0?run.content->progression.weapon_slots:run.content->progression.trait_slots))) return false;
    const uint32_t next=old+std::min(levels,d.maximum_level-old);
    if (d.kind==0) {
        if (d.external_id=="W01") {
        const auto &level=run.content->forward_levels[next-1];auto &forward=run.state.forward;
        if (forward.ready) ForwardBehavior::set_interval(forward,level.interval);
        else {forward={};forward.base_interval=forward.interval=forward.fire.remaining=level.interval;}
        forward.damage=level.damage;forward.pierce=level.pierce;forward.life=level.life;forward.spread=level.spread;forward.knock=level.knock;
        forward.character_scale=run.content->config.character_scale;forward.ready=true;
        } else if (d.external_id=="W05") {
            const auto &level=run.content->barrier_levels[next-1];auto &barrier=run.state.loadout.barrier;
            if (!barrier.ready) barrier={};
            barrier.definition=id;barrier.maximum=level.durability;barrier.revive=level.revive;barrier.radius=level.radius;
            barrier.damage=level.damage;barrier.shell_radius=level.shell_radius;barrier.knock=level.knock;barrier.ready=true;
        } else if (d.external_id=="W23") {
            const auto &level=run.content->rear_levels[next-1];auto &rear=run.state.loadout.rear;
            if (rear.ready) ForwardBehavior::set_interval(rear,level.interval);
            else {rear={};rear.base_interval=rear.interval=rear.fire.remaining=level.interval;}
            rear.definition=id;rear.damage=level.damage;rear.pierce=level.pierce;rear.life=level.life;rear.spread=level.spread;rear.knock=level.knock;
            rear.character_scale=run.content->config.character_scale;rear.color=level.color;rear.mount_x=level.mount_x;rear.mount_y=level.mount_y;rear.muzzle_distance=level.muzzle_distance;rear.ready=true;
        } else if (d.external_id=="W29") {
            const auto &level=run.content->end_blast_levels[next-1];auto &weapon=run.state.loadout.end_blast;
            weapon.ready=true;weapon.definition=id;weapon.radius=level.radius;weapon.damage=level.damage;weapon.secondary=level.secondary;
            weapon.secondary_radius=level.secondary_radius;weapon.secondary_damage=level.secondary_damage;weapon.secondary_delay=level.secondary_delay;weapon.secondary_step=level.secondary_step;weapon.knock=level.knock;
        } else if (d.external_id=="W02") {
            const auto &level=run.content->scatter_levels[next-1];auto &scatter=run.state.loadout.scatter;
            if (scatter.ready) scatter.fire.remaining+=level.interval-scatter.interval;
            else {scatter={};scatter.fire.remaining=level.interval;}
            scatter.base_interval=scatter.interval=level.interval;scatter.definition=id;scatter.shots=level.shots;
            scatter.damage=level.damage;scatter.life=level.life;scatter.spread=level.spread;scatter.knock=level.knock;scatter.ready=true;
        } else return false;
    } else if (d.external_id=="T37") {
        if (std::none_of(run.content->duplicator_levels.begin(),run.content->duplicator_levels.end(),[&](const auto &v){return v.equipment==id && v.level==next;})) return false;
    } else if (d.external_id=="T33") {
        if (std::none_of(run.content->rampage_levels.begin(),run.content->rampage_levels.end(),[&](const auto &v){return v.equipment==id && v.level==next;})) return false;
    } else if (d.external_id=="T04") {
        if (std::none_of(run.content->full_charge_levels.begin(),run.content->full_charge_levels.end(),[&](const auto &v){return v.equipment==id && v.level==next;})) return false;
    } else if (std::none_of(run.content->numeric_traits.begin(),run.content->numeric_traits.end(),[&](const auto &v){return v.equipment==id && v.level==next;})) return false;
    if (current==owned.end()) owned.push_back({id,next});else current->level=next;
    refresh_effects(run);
    if (std::find(run.state.lifecycle.obtained.begin(),run.state.lifecycle.obtained.end(),id)==run.state.lifecycle.obtained.end()) run.state.lifecycle.obtained.push_back(id);
    return true;
}
bool EquipmentSystem::remove_trait(RunRuntime &run,uint32_t id) {
    auto &owned=run.state.loadout.traits;const auto found=std::find_if(owned.begin(),owned.end(),[&](const auto &item){return item.definition==id;});
    if (found==owned.end()) return false;
    owned.erase(found);refresh_effects(run);return true;
}
bool EquipmentSystem::remove_weapon(RunRuntime &run,uint32_t id) {
    auto &owned=run.state.loadout.weapons;
    auto current=std::find_if(owned.begin(),owned.end(),[&](const auto &v){return v.definition==id;});
    if (current==owned.end() || !id || id>run.content->equipment.size()) return false;
    // 発射済みの自然寿命の弾は、装備の解除後も残す。
    const auto &external=run.content->equipment[id-1].external_id;
    if (external=="W01") run.state.forward={};
    else if (external=="W05") run.state.loadout.barrier={};
    else if (external=="W23") run.state.loadout.rear={};
    else if (external=="W29") run.state.loadout.end_blast={};
    else if (external=="W02") run.state.loadout.scatter={};
    else return false;
    owned.erase(current);refresh_effects(run);return true;
}
}
