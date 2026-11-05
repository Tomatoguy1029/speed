#include "contactArc.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/collision_query.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/equipment.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
void ContactArcBehavior::contact(RunRuntime &r,EnemyHandle target) {
    auto &s=r.state;auto &w=s.loadout->contact_arc;if (!w.ready || !s.enemy_handles.contains(target) || s.world_time+0.000001<w.ready_at) return;
    const auto root=s.enemies[target.slot];if (s.field.rock_handles.contains(root.rock) || r.content->definitions[root.definition].kind==EnemyDefinition::Kind::Meteor) return;
    w.ready_at=s.world_time+w.cooldown;const double damage=CombatResolver::attack_power(r)*EquipmentSystem::weapon_damage_factor(r,w.definition)*w.damage;
    std::unordered_set<int64_t> used{root.id};ContactArcVisual visual;visual.id=w.next_visual++;visual.age=0;visual.segments={s.ship.pos,root.pos};
    if (!root.dead) {DamageRequest request;request.struck=target;request.amount=damage;request.cause=Cause::ContactArc;CombatResolver::damage_enemy(r,request);}
    const double reach=w.range*s.loadout->effects.area*(1+w.area_increment*double(s.loadout->post_area_stacks));const godot::Vector2 pad(reach+s.grid.max_radius,reach+s.grid.max_radius);
    const auto allowed=[&](size_t row){const auto &e=s.enemies[row];return !s.field.rock_handles.contains(e.rock) && r.content->definitions[e.definition].kind!=EnemyDefinition::Kind::Meteor && !used.count(e.id);};
    const auto strike=[&](godot::Vector2 from,EnemyHandle next) {const auto e=s.enemies[next.slot];used.insert(e.id);visual.segments.push_back(from);visual.segments.push_back(e.pos);DamageRequest request;request.struck=next;request.amount=damage;request.cause=Cause::ContactArc;request.direction=(e.pos-from).normalized();request.knock=w.knock*(1+w.knockback_increment*double(s.loadout->post_knockback_stacks));CombatResolver::damage_enemy(r,request);return e.pos;};
    uint32_t remaining=w.chains;const uint32_t count=std::min(w.branches,remaining);const double width=6.283185307179586/count;std::vector<EnemyHandle> roots(count);std::vector<double> distances(count,reach*reach);
    for (auto row:CollisionQuery::enemy_rows(s,root.pos-pad,root.pos+pad,true)) {if (!allowed(row)) continue;const auto offset=s.enemies[row].pos-root.pos;const uint32_t sector=uint32_t(std::floor(std::fmod(offset.angle()+width*0.5+6.283185307179586,6.283185307179586)/width))%count;const double d=offset.length_squared();if (d<distances[sector]) {distances[sector]=d;roots[sector]=s.enemy_handles.at(uint32_t(row));}}
    std::vector<godot::Vector2> tips;
    for (auto next:roots) {if (s.phase!=godot::RunState::Phase::Play) break;if (!s.enemy_handles.contains(next) || s.enemies[next.slot].dead) continue;tips.push_back(strike(root.pos,next));--remaining;}
    size_t branch=0;
    while (remaining && !tips.empty() && s.phase==godot::RunState::Phase::Play) {
        const auto from=tips[branch];EnemyHandle next;double best=reach*reach;
        for (auto row:CollisionQuery::enemy_rows(s,from-pad,from+pad,true)) {if (!allowed(row)) continue;const double d=s.enemies[row].pos.distance_squared_to(from);if (d<best) {best=d;next=s.enemy_handles.at(uint32_t(row));}}
        if (!s.enemy_handles.contains(next)) tips.erase(tips.begin()+branch);else {tips[branch]=strike(from,next);--remaining;++branch;}if (branch>=tips.size()) branch=0;
    }
    w.visuals.erase(std::remove_if(w.visuals.begin(),w.visuals.end(),[&](const auto &v){return v.age>=w.visual_life;}),w.visuals.end());w.visuals.push_back(visual);if (w.visuals.size()>80) w.visuals.erase(w.visuals.begin());
    EventBuilder::flush_combat(r);godot::PackedVector2Array segments;for (auto p:visual.segments) segments.push_back(p);godot::Dictionary event;event["segments"]=segments;FrameBuilder::append(r,"bolt",event);
}
}
