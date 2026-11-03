#include "afterimage.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../output/event_builder.h"
#include <algorithm>
namespace speed {
void AfterimageBehavior::end(RunRuntime &r) {auto &w=r.state.loadout.afterimage;for (auto &e:w.echoes) if (e.id==w.current) e.ended=true;w.current=0;}
void AfterimageBehavior::clear(RunRuntime &r) {auto &w=r.state.loadout.afterimage;w.echoes.clear();w.current=0;}
void AfterimageBehavior::launch(RunRuntime &r) {auto &w=r.state.loadout.afterimage;if (!w.ready) return;end(r);AfterimageEcho e;e.id=w.next_id++;e.start=e.until=w.clock;e.share=w.total*EquipmentSystem::weapon_damage_factor(r,w.definition)/w.count;
    for (uint32_t k=0;k<w.count;++k) {AfterimageCopy c;c.delay=w.delay*(k+1);c.pos=r.state.ship.pos;c.dir=r.state.ship.heading;e.copies.push_back(c);}w.current=e.id;w.echoes.push_back(std::move(e));if (w.echoes.size()>8) w.echoes.erase(w.echoes.begin());
}
void AfterimageBehavior::trail(RunRuntime &r,godot::Vector2 a,godot::Vector2 b) {auto &s=r.state;auto &w=s.loadout.afterimage;if (!w.ready || !w.current || !s.draw.tracing || a.is_equal_approx(b)) return;
    for (auto &e:w.echoes) if (e.id==w.current) {if (e.legs.size()>=2048 || w.clock-e.start>=4) {end(r);return;}const double start=std::max(w.clock,e.until),finish=start+a.distance_to(b)/std::max(s.draw.rate,1.0);e.legs.push_back({a,b,start,finish,CombatResolver::attack_power(r),r.content->config.trace_radius*s.loadout.effects.area});e.until=finish;return;}
}
namespace {
void hit(RunRuntime &r,AfterimageCopy &c,godot::Vector2 a,godot::Vector2 b,const AfterimageLeg &leg,double share) {auto &s=r.state;const double query_radius=leg.radius+std::max(s.combat_config.max_enemy_radius,s.grid.max_radius);const godot::Vector2 pad(query_radius,query_radius);
    for (auto row:CollisionQuery::enemy_rows(s,a.min(b)-pad,a.max(b)+pad)) {const auto &enemy=s.enemies[row];if (enemy.dead || c.hits.count(enemy.id)) continue;const double t=CollisionQuery::segment_circle_t(a,b,enemy.pos,enemy.radius+leg.radius);if (t<0) continue;c.hits.insert(enemy.id);if (leg.power<enemy.armor) continue;
        DamageRequest q;q.struck=s.enemy_handles.at(uint32_t(row));q.amount=leg.power*share;q.cause=Cause::Afterimage;q.weapon_id=s.loadout.afterimage.definition;q.direction=c.dir;q.impact=a.lerp(b,t);q.has_impact=true;q.knock=0;q.no_crit=true;CombatResolver::damage_enemy(r,q);EventBuilder::flush_combat(r);if (s.phase!=godot::RunState::Phase::Play) return;
    }
}
}
void AfterimageBehavior::step(RunRuntime &r,double dt) {auto &s=r.state;auto &w=s.loadout.afterimage;if (!w.ready || s.phase!=godot::RunState::Phase::Play) return;w.clock+=dt;
    for (auto &e:w.echoes) for (auto &c:e.copies) {const double now=w.clock-c.delay;while (c.cursor<e.legs.size()) {const auto &leg=e.legs[c.cursor];if (now<leg.start) break;const double progress=std::clamp((now-leg.start)/std::max(leg.finish-leg.start,0.000001),0.0,1.0);const auto a=leg.a.lerp(leg.b,c.progress),b=leg.a.lerp(leg.b,progress);c.pos=b;c.dir=(leg.b-leg.a).normalized();c.alpha=1;
            if (progress>c.progress) {hit(r,c,a,b,leg,e.share);if (s.phase!=godot::RunState::Phase::Play) {clear(r);return;}}if (progress<1) {c.progress=progress;break;}++c.cursor;c.progress=0;
        }if (e.ended && c.cursor>=e.legs.size()) c.alpha=e.legs.empty()?0:std::clamp(1-(now-e.until)/0.2,0.0,1.0);
    }
    w.echoes.erase(std::remove_if(w.echoes.begin(),w.echoes.end(),[&](const auto &e){return w.clock>=e.start+8 || (e.ended && w.clock>e.until+e.copies.back().delay+0.2);}),w.echoes.end());
}
}
