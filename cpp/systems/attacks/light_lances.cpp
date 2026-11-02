#include "light_lances.h"
#include "../attack_system.h"
#include "../combat_resolver.h"
#include "../../behaviors/traits/duplicator.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include <godot_cpp/templates/sort_array.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
std::vector<uint64_t> LightLancesSystem::fire(RunRuntime &run,const LightLanceParams &p) {
    auto &state=run.state;std::vector<uint64_t> created;
    if (!state.started || state.closed || !state.combat_ready || state.phase!=godot::RunState::Phase::Play || run.content->light_lances.empty() || !p.position.is_finite() || !p.direction.is_finite()) return created;
    for (double value:{p.length,p.width,p.damage,p.knock}) if (!std::isfinite(value) || value<0) return created;
    const auto &definition=run.content->light_lances.front();const auto velocity=p.direction*p.length/definition.flight_time;if (!velocity.is_finite()) return created;
    LightLanceState original;original.definition=definition.id;original.from=p.position;original.velocity=velocity;original.length=p.length;original.width=p.width;original.damage=p.damage;original.knock=p.knock;
    struct VisualHit {EnemyHandle target;godot::Vector2 direction;};std::vector<VisualHit> visual_hits;
    std::vector<LightLanceState> queue{original};size_t next=0;uint64_t reserved=0;
    struct Reservation {godot::RunState &state;uint64_t &count;~Reservation(){AttackSystem::release_friendly(state,count);}} reservation{state,reserved};
    while (next<queue.size() && state.phase==godot::RunState::Phase::Play) {
        auto lance=queue[next++];if (lance.duplicate) {AttackSystem::release_friendly(state,1);--reserved;}
        if (state.attacks.next_lance_id==UINT64_MAX) break;
        lance.id=state.attacks.next_lance_id++;lance.life=definition.life;const size_t item=state.attacks.lances.size();state.attacks.lances.push_back(lance);created.push_back(lance.id);
        if (!lance.duplicate) {
            const auto vectors=DuplicatorBehavior::vectors(run,lance.velocity);const uint64_t count=AttackSystem::flying_count(state);
            if (count<=definition.maximum && vectors.size()<=definition.maximum-count && AttackSystem::reserve_friendly(state,vectors.size())) {
                reserved+=vectors.size();
                for (auto vector:vectors) {auto child=lance;child.id=0;child.velocity=vector;child.damage*=DuplicatorBehavior::damage_factor(run);child.duplicate=true;child.hits.clear();queue.push_back(std::move(child));}
                if (!vectors.empty()) {godot::Array directions;for (auto v:vectors) directions.push_back(v);godot::Dictionary event;event["pos"]=lance.from;event["directions"]=directions;FrameBuilder::append(run,"duplicate",event);}
            }
        }
        const auto direction=lance.velocity.normalized(),to=lance.from+direction*lance.length;godot::Dictionary event;event["from"]=lance.from;event["to"]=to;event["width"]=lance.width;FrameBuilder::append(run,"critical_lance",event);
        state.attacks.lance_visuals.push_back({lance.id,lance.from,to,lance.width,0});
        state.attacks.lance_effects.push_back({state.attacks.next_lance_effect_id++,false,lance.from,direction,0,0});
        struct Hit {double fraction;EnemyHandle target;};struct Earlier {bool operator()(const Hit &a,const Hit &b) const{return a.fraction<b.fraction;}};
        std::vector<Hit> hits;const double padding=lance.width*0.5+std::max(state.combat_config.max_enemy_radius,state.grid.max_radius);const auto pad=godot::Vector2(padding,padding);
        for (auto row:CollisionQuery::enemy_rows(state,lance.from.min(to)-pad,lance.from.max(to)+pad)) {
            const auto &enemy=state.enemies[row];if (enemy.dead || state.attacks.lances[item].hits.count(enemy.id)) continue;
            const double fraction=CollisionQuery::segment_circle_t(lance.from,to,enemy.pos,enemy.radius+lance.width*0.5);if (fraction>=0) hits.push_back({fraction,state.enemy_handles.at(uint32_t(row))});
        }
        if (hits.size()>1) godot::SortArray<Hit,Earlier>().sort(hits.data(),int64_t(hits.size()));
        for (auto hit:hits) {
            const auto handle=hit.target;if (!state.enemy_handles.contains(handle)) continue;
            const auto &enemy=state.enemies[handle.slot];if (!enemy.alive || enemy.dead) continue;
            state.attacks.lances[item].hits.insert(enemy.id);
            DamageRequest request;request.struck=handle;request.amount=lance.damage;request.cause=Cause::CritBeam;request.no_crit=true;request.direction=direction;request.knock=lance.knock;
            CombatResolver::damage_enemy(run,request);EventBuilder::flush_combat(run);
            visual_hits.push_back({handle,direction});
        }
    }
    for (const auto &hit:visual_hits) if (state.enemy_handles.contains(hit.target) && !state.enemies[hit.target.slot].dead) {
        godot::Dictionary effect;effect["pos"]=state.enemies[hit.target.slot].pos;effect["radius"]=state.enemies[hit.target.slot].radius;effect["direction"]=hit.direction;FrameBuilder::append(run,"critical_lance_hit",effect);
        state.attacks.lance_effects.push_back({state.attacks.next_lance_effect_id++,true,state.enemies[hit.target.slot].pos,hit.direction,state.enemies[hit.target.slot].radius,0});
    }
    return created;
}
void LightLancesSystem::step(RunRuntime &run,double dt) {
    if (!std::isfinite(dt) || dt<=0 || run.state.closed) return;
    auto &items=run.state.attacks.lances;for (auto &item:items) item.life-=dt;
    items.erase(std::remove_if(items.begin(),items.end(),[](const auto &item){return item.life<=0;}),items.end());
}
}
