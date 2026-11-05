#include "killSonic.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/collision_query.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include "../../state/loadout_state.h"
#include <algorithm>
#include <cmath>
namespace speed {
void KillSonicBehavior::launch(RunRuntime &r) {auto &w=r.state.loadout->kill_sonic;if (!w.ready) return;w.kills=0;w.next=w.every;w.active=true;w.chains=0;}
void KillSonicBehavior::end(RunRuntime &r) {r.state.loadout->kill_sonic.active=false;}
void KillSonicBehavior::kill(RunRuntime &r,const DeathContext &death) {
    auto &w=r.state.loadout->kill_sonic;if (!w.ready || !w.active) return;
    if (w.kills<INT64_MAX) ++w.kills;if (w.kills<w.next || w.chains>=w.limit) return;
    w.next+=w.every;KillSonicWave wave;wave.id=w.next_id++;wave.pos=death.corpse.pos;wave.generation=w.chains;wave.life=w.life;wave.born=r.state.world_time;
    wave.radius=w.radius*std::pow(w.radius_decay,w.chains)*r.state.loadout->effects.area;wave.damage=CombatResolver::attack_power(r)*w.damage*std::pow(w.damage_decay,w.chains);++w.chains;w.waves.push_back(wave);
    EventBuilder::flush_combat(r);godot::Dictionary event;event["pos"]=wave.pos;event["radius"]=wave.radius;event["life"]=wave.life;event["generation"]=int64_t(wave.generation);FrameBuilder::append(r,"chain_shock",event);
}
void KillSonicBehavior::step(RunRuntime &r,double dt) {
    auto &s=r.state;auto &w=s.loadout->kill_sonic;if (!w.ready || dt<=0) return;
    // 命中中の撃破が追加する波は、次の装備更新から進める。
    const size_t count=w.waves.size();for (size_t i=0;i<count;++i) {
        auto wave=w.waves[i];wave.age+=dt;const double reach=wave.radius*(1-std::pow(1-std::min(1.0,wave.age/wave.life),3));const godot::Vector2 pad(reach+s.grid.max_radius,reach+s.grid.max_radius);
        for (auto row:CollisionQuery::enemy_rows(s,wave.pos-pad,wave.pos+pad)) {
            const auto e=s.enemies[row];if (e.dead || wave.hits.count(e.id) || e.pos.distance_to(wave.pos)>reach+e.radius) continue;
            wave.hits.insert(e.id);DamageRequest hit;hit.struck=s.enemy_handles.at(uint32_t(row));hit.amount=wave.damage;hit.cause=Cause::KillSonic;hit.direction=(e.pos-wave.pos).normalized();hit.knock=w.knock;CombatResolver::damage_enemy(r,hit);
        }w.waves[i]=std::move(wave);
    }
    w.waves.erase(std::remove_if(w.waves.begin(),w.waves.end(),[](const auto &v){return v.age>=v.life;}),w.waves.end());EventBuilder::flush_combat(r);
}
}
