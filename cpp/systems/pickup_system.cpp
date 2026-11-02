#include "pickup_system.h"
#include "progression.h"
#include "../api/run_core.h"
#include "../runtime/run_runtime.h"
#include "../output/event_builder.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void drop_gem(RunRuntime &run,godot::Vector2 position,double value) {
    if (run.state.pickups.live_gems > run.state.pickup_config.gem_max) {
        while (run.state.pickups.gem_queue_head < run.state.pickups.gem_queue.size()) {
            const auto entry = run.state.pickups.gem_queue[run.state.pickups.gem_queue_head++];
            auto &old = run.state.pickups.gems[entry.first];
            if (old.alive && old.order == entry.second) {
                value += old.value;
                old.alive = false;
                run.state.pickups.free_gems.push_back(entry.first);
                --run.state.pickups.live_gems;
                break;
            }
        }
        if (run.state.pickups.gem_queue_head >= 1024 && run.state.pickups.gem_queue_head * 2 >= run.state.pickups.gem_queue.size()) {
            run.state.pickups.gem_queue.erase(run.state.pickups.gem_queue.begin(), run.state.pickups.gem_queue.begin() + run.state.pickups.gem_queue_head);
            run.state.pickups.gem_queue_head = 0;
        }
    }
    const double angle = run.state.control.rng.randf() * (2.0 * godot::Math::PI);
    const godot::Vector2 at = position + godot::Vector2::from_angle(angle) * 8.0;
    size_t row = run.state.pickups.gems.size();
    if (run.state.pickups.free_gems.empty()) run.state.pickups.gems.emplace_back();
    else { row = run.state.pickups.free_gems.back(); run.state.pickups.free_gems.pop_back(); }
    run.state.pickups.gems[row] = {at, value, run.state.pickups.next_ground_order, true, false};
    run.state.pickups.gems[row].id=run.state.pickups.next_id++;
    run.state.pickups.gem_queue.push_back({row, run.state.pickups.next_ground_order++});
    ++run.state.pickups.live_gems;
}

void drop_legacy(RunRuntime &run,const Corpse &enemy) {
    const auto &c = run.state.pickup_config;
    const double value = enemy.xp * c.xp_mult * (c.xp_bonus > 0 ? c.xp_bonus : 1.0);
    run.state.pickups.xp_dropped += value;
    drop_gem(run,enemy.pos, value);
    const int64_t coin_count = enemy.elite ? 3 + run.state.control.rng.randi_range(0, 3).value() : (run.state.control.rng.randf() < 0.03 ? 1 : 0);
    for (int64_t k = 0; k < coin_count; ++k) {
        const double angle = run.state.control.rng.randf() * (2.0 * godot::Math::PI);
        const double share = run.state.control.rng.randf();
        const godot::RunState::Coin coin{enemy.pos + godot::Vector2::from_angle(angle) * share * enemy.radius, true, false};
        if (run.state.pickups.free_coins.empty()) run.state.pickups.coins.push_back(coin);
        else { run.state.pickups.coins[run.state.pickups.free_coins.back()] = coin; run.state.pickups.free_coins.pop_back(); }
    }
    if (run.state.control.rng.randf() < std::min(c.drop_max, c.drop_base * std::pow(enemy.xp, c.drop_power))) {
        const double fraction = std::clamp(run.state.time / c.shift_time, 0.0, 1.0);
        std::vector<float> weights;
        double total = 0;
        for (size_t k = 0; k < c.xp.size(); ++k) {
            const double weight = godot::Math::lerp(c.start_weights[k], c.end_weights[k], fraction);
            weights.push_back(weight); total += weight;
        }
        double roll = run.state.control.rng.randf() * total;
        size_t tier = weights.size() - 1;
        for (size_t k = 0; k < weights.size(); ++k) { roll -= weights[k]; if (roll < 0) { tier = k; break; } }
        run.state.pickups.xp_dropped += c.xp[tier];
        drop_gem(run,enemy.pos, c.xp[tier]);
    }
}

uint64_t place_crystal(RunRuntime &run,godot::Vector2 pos,CrystalState crystal,bool new_supply,int64_t carrier_id=-1) {
    auto &state=run.state;auto &pickups=state.pickups;
    if (pickups.live_gems<state.pickup_config.gem_max && pickups.next_ground_order==UINT64_MAX) {run.frame_workspace.invalid=true;return 0;}
    const auto id=crystal.id;const double value=crystal.value;
    // 満杯では新しい位置も乱数も作らず、最古の大結晶（なければ最古の結晶）へ加算する。
    if (state.pickups.live_gems>=state.pickup_config.gem_max && state.pickups.live_gems>0) {
        int64_t target=state.pickups.gem_absorber;
        if (target<0 || size_t(target)>=state.pickups.gems.size() || !state.pickups.gems[target].alive || state.pickups.gems[target].id!=state.pickups.gem_absorber_id || state.pickups.gems[target].kind!=2) {
            int64_t oldest=-1,high=-1;
            for (size_t i=0;i<state.pickups.gems.size();++i) if (state.pickups.gems[i].alive) {
                if (oldest<0 || state.pickups.gems[i].order<state.pickups.gems[oldest].order) oldest=int64_t(i);
                if (state.pickups.gems[i].kind==2 && (high<0 || state.pickups.gems[i].order<state.pickups.gems[high].order)) high=int64_t(i);
            }
            target=high>=0?high:oldest;
            const uint8_t before_kind=state.pickups.gems[target].kind;
            state.pickups.gems[target].kind=2;state.pickups.gem_absorber=target;state.pickups.gem_absorber_id=state.pickups.gems[target].id;
            EventBuilder::crystal_absorber_selected(run,state.pickups.gems[target],before_kind);
        }
        auto &receiver=state.pickups.gems[target];const double before=receiver.value;receiver.value+=value;
        crystal.pos=pos;
        EventBuilder::crystal_absorbed(run,crystal,receiver,before,new_supply,carrier_id);
        return id;
    }
    const auto at=pos+godot::Vector2::from_angle(state.control.rng.randf()*2.0*godot::Math::PI)*8.0;
    size_t row=state.pickups.gems.size();
    if (state.pickups.free_gems.empty()) state.pickups.gems.emplace_back();else {row=state.pickups.free_gems.back();state.pickups.free_gems.pop_back();}
    crystal.pos=at;crystal.order=state.pickups.next_ground_order++;crystal.alive=true;crystal.pulled=false;
    state.pickups.gems[row]=crystal;++state.pickups.live_gems;
    EventBuilder::crystal_drop(run,state.pickups.gems[row],new_supply,carrier_id);
    return id;
}
uint64_t drop_crystal(RunRuntime &run,godot::Vector2 pos,uint8_t kind,const CrystalOrigin &origin,godot::Vector2 velocity={},double wait=0) {
    auto &p=run.state.pickups;
    if (p.next_id==UINT64_MAX) {run.frame_workspace.invalid=true;return 0;}
    CrystalState gem;gem.id=p.next_id++;gem.kind=kind;gem.value=run.content->crystal_values[kind];gem.origin=origin;gem.velocity=velocity;gem.wait=wait;
    p.xp_dropped+=gem.value;++p.supplied[kind].count;p.supplied[kind].base_xp+=gem.value;
    return place_crystal(run,pos,gem,true);
}

}
uint64_t PickupSystem::supply(RunRuntime &run,godot::Vector2 pos,uint8_t kind) {
    if (kind>2 || !pos.is_finite()) return 0;
    return drop_crystal(run,pos,kind,{CrystalSource::Direct,0,-1,run.state.time,run.state.world_time});
}
bool PickupSystem::release_crystal(RunRuntime &run,size_t row,CrystalRemoval reason) {
    auto &p=run.state.pickups;
    if (row>=p.gems.size() || !p.gems[row].alive) return false;
    const auto &gem=p.gems[row];
    if (reason==CrystalRemoval::Collected || reason==CrystalRemoval::Lost) {
        auto &total=reason==CrystalRemoval::Collected?p.collected[gem.kind]:p.lost[gem.kind];++total.count;total.base_xp+=gem.value;
    }
    if (p.gem_absorber_id==gem.id) {EventBuilder::crystal_absorber_released(run,gem.id,reason);p.gem_absorber=-1;p.gem_absorber_id=0;}
    p.gems[row].alive=false;p.free_gems.push_back(row);--p.live_gems;return true;
}
double PickupSystem::collect_rows(godot::SpeedRunCore &core,const std::vector<size_t> &rows,CrystalCollectMethod method) {
    auto &run=core.runtime;auto &p=run.state.pickups;
    const double multiplier=run.state.pickup_config.xp_mult*run.state.loadout.xp_gain_mult;
    std::vector<CrystalCollection> details;double base=0;
    for (size_t row:rows) {
        if (row>=p.gems.size() || !p.gems[row].alive) continue;
        const auto gem=p.gems[row];const double actual=gem.value*multiplier;
        details.push_back({gem,actual,p.gem_absorber_id==gem.id});base+=gem.value;
        p.collected[gem.kind].actual_xp+=actual;
        release_crystal(run,row,CrystalRemoval::Collected);
    }
    if (details.empty()) return 0;
    const double actual=base*multiplier;
    ProgressionSystem::add_experience(core,actual);p.collected_actual_xp+=actual;
    EventBuilder::crystals_collected(run,details,base,actual,multiplier,method);return actual;
}
double PickupSystem::collect_all(godot::SpeedRunCore &core) {
    std::vector<size_t> rows;for (size_t row=0;row<core.runtime.state.pickups.gems.size();++row) if (core.runtime.state.pickups.gems[row].alive) rows.push_back(row);
    return collect_rows(core,rows,CrystalCollectMethod::Magnet);
}
void PickupSystem::step_capsules(godot::SpeedRunCore &core,double dt) {
    auto &run=core.runtime;auto &state=run.state;auto &capsules=state.pickups.capsules;
    const double reach=22.0+state.ship_config.ship_radius+14.0,pull=state.pickup_config.coin_radius*1.6;
    for (size_t i=0;i<capsules.size();) {
        auto &capsule=capsules[i];capsule.age+=dt;
        const bool can=capsule.kind!=CapsuleKind::Heal || state.ship.hp<state.ship_config.max_hp;
        const auto direction=state.ship.pos-capsule.pos;const double distance=direction.length();
        if (capsule.drop && can && distance<pull && distance>1.0) capsule.pos+=direction/distance*std::min((600.0+state.ship.vel.length())*dt,distance);
        if (can && capsule.pos.distance_squared_to(state.ship.pos)<reach*reach) {
            const auto collected=capsule;capsules.erase(capsules.begin()+i);double applied=0;
            if (collected.kind==CapsuleKind::Heal) {
                const double before=state.ship.hp;state.ship.hp=std::min(state.ship_config.max_hp,state.ship.hp+state.ship_config.max_hp*state.pickup_config.repair_fraction);applied=state.ship.hp-before;
            } else if (collected.kind==CapsuleKind::Magnet) applied=collect_all(core);
            else state.loadout.pending_comet_weapons.push_back(collected.weapon);
            EventBuilder::capsule_collected(run,collected,applied);continue;
        }
        if (capsule.drop && capsule.age>state.pickup_config.pickup_life) {capsules.erase(capsules.begin()+i);continue;}
        ++i;
    }
}
bool PickupSystem::carry(RunRuntime &run,EnemyHandle owner,size_t row) {
    auto &state=run.state;auto &p=state.pickups;
    if (!state.enemy_handles.contains(owner) || !state.enemies[owner.slot].alive || state.enemies[owner.slot].dead || row>=p.gems.size() || !p.gems[row].alive) return false;
    const auto crystal=p.gems[row];const auto id=state.enemies[owner.slot].id;
    auto found=std::find_if(p.cargo.begin(),p.cargo.end(),[&](const auto &cargo){return cargo.enemy_id==id && same_handle(cargo.owner,owner);});
    if (found==p.cargo.end()) {p.cargo.push_back({owner,id,{}});found=std::prev(p.cargo.end());}
    found->crystals.push_back(crystal);const bool was_absorber=p.gem_absorber_id==crystal.id;
    release_crystal(run,row,CrystalRemoval::Stored);EventBuilder::crystal_transferred(run,crystal,id,was_absorber);return true;
}
void PickupSystem::redrop(RunRuntime &run,const Corpse &enemy) {
    auto &cargo=run.state.pickups.cargo;const auto found=std::find_if(cargo.begin(),cargo.end(),[&](const auto &entry){return entry.enemy_id==enemy.id;});
    if (found==cargo.end()) return;
    auto crystals=std::move(found->crystals);cargo.erase(found);
    for (size_t k=0;k<crystals.size();++k) {
        auto &crystal=crystals[k];crystal.velocity={};crystal.wait=0;
        const auto pos=enemy.pos+godot::Vector2::from_angle(2.0*godot::Math::PI*double(k)/double(crystals.size()))*(10.0+4.0*double(k%3));
        place_crystal(run,pos,crystal,false,enemy.id);
    }
}
void PickupSystem::lose(RunRuntime &run,int64_t enemy_id,CargoLoss reason) {
    auto &p=run.state.pickups;const auto found=std::find_if(p.cargo.begin(),p.cargo.end(),[&](const auto &cargo){return cargo.enemy_id==enemy_id;});
    if (found==p.cargo.end()) return;
    for (const auto &crystal:found->crystals) {++p.lost[crystal.kind].count;p.lost[crystal.kind].base_xp+=crystal.value;EventBuilder::crystal_lost(run,crystal,enemy_id,reason);}
    p.cargo.erase(found);
}
void PickupSystem::lose_all(RunRuntime &run,CargoLoss reason) {
    while (!run.state.pickups.cargo.empty()) lose(run,run.state.pickups.cargo.front().enemy_id,reason);
}
void PickupSystem::prune(RunRuntime &run) {
    auto &state=run.state;
    for (size_t i=0;i<state.pickups.cargo.size();) {
        const auto &cargo=state.pickups.cargo[i];const auto owner=cargo.owner;
        if (!state.enemy_handles.contains(owner) || state.enemy_handles.entity_id(owner)!=cargo.enemy_id || !state.enemies[owner.slot].alive || state.enemies[owner.slot].dead) lose(run,cargo.enemy_id,CargoLoss::OwnerRemoved);
        else ++i;
    }
}
void PickupSystem::drop_enemy(RunRuntime &run,const Corpse &enemy) {
    auto &state=run.state;const auto &definition=run.content->definitions[enemy.definition-1];
    if (enemy.is_boss) return;
    if (!state.pickup_config.fixed_rewards) {drop_legacy(run,enemy);return;}
    EventBuilder::flush_combat(run);
    CrystalOrigin origin{CrystalSource::Enemy,enemy.definition,enemy.id,state.time,state.world_time};
    const uint64_t reward_count=uint64_t(definition.xp_rewards[0])+definition.xp_rewards[1]+definition.xp_rewards[2];
    uint64_t index=0;
    for (uint8_t kind=0;kind<3;++kind) for (uint32_t i=0;i<definition.xp_rewards[kind];++i,++index) {
        if (definition.reward_scattered) {
            const auto direction=godot::Vector2::from_angle(2.0*godot::Math::PI*double(index)/double(std::max<uint64_t>(1,reward_count))+state.control.rng.randf()*0.5);
            drop_crystal(run,enemy.pos+direction*enemy.radius*0.3,kind,origin,direction*state.control.rng.randf_range(240.0,380.0),0.35);
        } else drop_crystal(run,enemy.pos,kind,origin);
    }
    if (definition.reward_burst && reward_count) EventBuilder::crystal_burst(run,enemy);
    if (definition.gold_eligible) {
        ++state.pickups.gold_rolls;const bool won=state.control.rng.randf()<state.pickup_config.strong_gold_chance;
        if (won) ++state.pickups.gold_won;
        EventBuilder::crystal_gold_roll(run,enemy,won);
        if (won) {origin.source=CrystalSource::StrongGold;drop_crystal(run,enemy.pos,2,origin);}
    }
    redrop(run,enemy);
    const bool meteor=definition.kind==EnemyDefinition::Kind::Meteor && !run.content->rock_fields.empty();
    const double chance=meteor?run.content->rock_fields.front().meteor_coin_chance:0.03;
    const int64_t count=enemy.elite?3+state.control.rng.randi_range(0,3).value():(state.control.rng.randf()<chance?(meteor?1+state.control.rng.randi_range(0,2).value():1):0);
    for (int64_t i=0;i<count;++i) {
        const double angle=state.control.rng.randf()*2.0*godot::Math::PI,share=state.control.rng.randf();
        const godot::RunState::Coin coin{enemy.pos+godot::Vector2::from_angle(angle)*share*enemy.radius,true,false};
        if (state.pickups.free_coins.empty()) state.pickups.coins.push_back(coin);else {state.pickups.coins[state.pickups.free_coins.back()]=coin;state.pickups.free_coins.pop_back();}
    }
    if (meteor) {
        const auto &config=run.content->rock_fields.front();
        if (state.control.rng.randf()<config.meteor_heal_chance) state.pickups.capsules.push_back({enemy.pos,0,godot::RunState::CapsuleKind::Heal});
        if (state.control.rng.randf()<config.meteor_magnet_chance) state.pickups.capsules.push_back({enemy.pos,0,godot::RunState::CapsuleKind::Magnet});
        if (enemy.rare_weapon) state.pickups.capsules.push_back({enemy.pos,0,CapsuleKind::CometWeapon,enemy.rare_weapon,false});
    }
}
}
