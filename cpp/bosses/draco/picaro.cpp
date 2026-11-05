#include "picaro.h"
#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
bool alive(const godot::RunState &s,EnemyHandle h) {return s.enemy_handles.contains(h) && !s.enemies[h.slot].dead;}
void release(RunRuntime &r,const DracoPicaroMember &m) {for (const auto *parts:{&m.parts,&m.clone_parts}) for (auto h:*parts) EnemySystem::mark_dead(r,h);}
void stop(RunRuntime &r,EnemyHandle h,bool cancel) {
    if (!alive(r.state,h)) return;auto &e=r.state.enemies[h.slot];e.held=true;if (!cancel) return;e.mode=EnemyMode::Move;e.vel={};
    // Sourceのpauseは通常弾を残し、所有するhazardだけを停止する。
    for (auto &hazard:r.state.hazards) if (hazard.alive) {const auto *attack=AttackSystem::get(r.state,hazard.attack);if (attack && same_handle(attack->spec.owner.live_source,h)) AttackSystem::end(r.state,hazard.attack,AttackEndReason::TechniqueCancel);}
}
}
EnemyHandle DracoPicaro::spawn(RunRuntime &r,BossBodyState &b,uint32_t definition,godot::Vector2 at) {
    if (!definition || definition>r.content->definitions.size()) return {};
    EnemySpawn options;options.position=at;options.picaro_owner=b.actor;options.guard=1;
    const auto id=EnemySystem::spawn(r,definition-1,options);if (id<0) return {};const auto h=r.state.enemy_handles.at(r.state.rows_by_id.at(id));auto &e=r.state.enemies[h.slot];e.held=true;e.guard=1;
    b.draco->picaro.push_back({h,e.parts,{},b.clock,0,uint32_t(std::max<int64_t>(1,r.content->definitions[definition-1].rank))});return h;
}
bool DracoPicaro::adopt_clone(RunRuntime &r,BossBodyState &b,EnemyHandle actor,const std::vector<EnemyHandle> &parts,double angle,uint32_t stars) {
    if (!alive(r.state,actor) || parts.empty() || !std::isfinite(angle) || std::any_of(b.draco->picaro.begin(),b.draco->picaro.end(),[&](const auto &m){return same_handle(m.actor,actor);})) return false;
    for (auto h:parts) if (!alive(r.state,h)) return false;
    // 複製のHPは本体から独立させ、胴の転送先を複製自身の世代付きHandleにする。
    for (auto h:parts) r.state.enemies[h.slot].damage_target=actor;
    b.draco->picaro.push_back({actor,{},parts,b.clock-2,angle,stars});return true;
}
void DracoPicaro::spawned(RunRuntime &r,EnemyHandle h) {const auto owner=r.state.enemies[h.slot].picaro_owner;if (auto *b=PhaseController::find(r,owner)) b->draco->picaro_pending.push_back(h);}
void DracoPicaro::tick(RunRuntime &r,BossBodyState &b) {
    auto &d=*b.draco;auto &s=r.state;
    for (auto h:d.picaro_pending) {if (!alive(s,h) || s.enemies[h.slot].parent.generation) continue;if (std::any_of(d.picaro.begin(),d.picaro.end(),[&](const auto &m){return same_handle(m.actor,h);})) continue;const auto &e=s.enemies[h.slot];d.picaro.push_back({h,e.parts,{},b.clock,0,uint32_t(std::max<int64_t>(1,r.content->definitions[e.definition].rank))});}
    d.picaro_pending.clear();
    for (const auto &m:d.picaro) if (!alive(s,m.actor)) release(r,m);
    d.picaro.erase(std::remove_if(d.picaro.begin(),d.picaro.end(),[&](const auto &m){return !alive(s,m.actor);}),d.picaro.end());
    for (auto &m:d.picaro) {auto &e=s.enemies[m.actor.slot];const bool forming=b.clock-m.born<1;e.held=forming || !d.picaro_attacking;e.guard=forming?1:0;m.parts=e.parts;
        for (auto h:e.parts) if (s.enemy_handles.contains(h)) s.enemies[h.slot].held=e.held;
        if (!m.clone_parts.empty()) {
            const auto &p=DracoBody::rule(r,b);std::vector<godot::Vector2> points{e.pos};
            double total=0;for (uint32_t j=0;j<p.body_segments;++j) {const double t=double(j+1)/p.body_segments;const auto point=e.pos+godot::Vector2(-t*p.body_length,std::sin(t*6.283185307179586*1.25-b.clock*0.75)*p.body_wave*std::sin(t*3.141592653589793*0.8)).rotated(m.angle);total+=points.back().distance_to(point);points.push_back(point);}
            if (total>0.001) for (auto &v:points) v=e.pos+(v-e.pos)*(p.body_length/total);
            size_t at=0;double traversed=0;for (size_t j=0;j<m.clone_parts.size();++j) {const double fraction=double(j+1)/m.clone_parts.size(),target=p.body_length*fraction;while (at+2<points.size() && target>traversed+points[at].distance_to(points[at+1])) {traversed+=points[at].distance_to(points[at+1]);++at;}if (!s.enemy_handles.contains(m.clone_parts[j])) continue;auto &part=s.enemies[m.clone_parts[j].slot];part.pos=points[at].lerp(points[at+1],(target-traversed)/std::max(0.001,double(points[at].distance_to(points[at+1]))));part.radius=b.draco->width*0.5*(1-0.77*std::pow(std::clamp((fraction-0.55)/0.45,0.0,1.0),1.35));part.held=e.held;}
        }
    }
}
void DracoPicaro::pause(RunRuntime &r,BossBodyState &b,bool cancel) {b.draco->picaro_attacking=false;tick(r,b);for (const auto &m:b.draco->picaro) {stop(r,m.actor,cancel);for (const auto *parts:{&m.parts,&m.clone_parts}) for (auto h:*parts) stop(r,h,cancel);}}
void DracoPicaro::clear(RunRuntime &r,BossBodyState &b) {tick(r,b);b.draco->picaro_pending.clear();for (const auto &m:b.draco->picaro) {release(r,m);EnemySystem::mark_dead(r,m.actor);}b.draco->picaro.clear();}
bool DracoPicaro::validate(const godot::RunState &s,const ContentBundle &c,const BossBodyState &b) {
    std::unordered_set<uint64_t> seen;for (const auto &m:b.draco->picaro) {const uint64_t key=uint64_t(m.actor.slot)<<32|m.actor.generation;if (!seen.insert(key).second || !std::isfinite(m.born) || m.born< -2 || m.born>b.clock || !std::isfinite(m.angle) || (!m.stars && m.clone_parts.empty())) return false;if (s.enemy_handles.contains(m.actor)) {const auto &e=s.enemies[m.actor.slot];if (m.clone_parts.empty() && (!same_handle(e.picaro_owner,b.actor) || e.source_definition==0 || e.source_definition>c.definitions.size())) return false;}}return true;
}
godot::Array DracoPicaro::snapshot(const RunRuntime &r,const BossBodyState &b) {
    godot::Array out;for (const auto &e:r.state.enemies) if (e.alive && !e.dead && same_handle(e.picaro_owner,b.actor)) {godot::Dictionary p;p["id"]=e.id;p["source_definition"]=e.source_definition;p["source_type"]=r.content->definitions[e.source_definition-1].id;p["visual_id"]=r.content->definitions[e.source_definition-1].visual_id;p["position"]=e.pos;p["angle"]=e.facing+r.content->definitions[e.definition].sprite_angle;p["radius"]=e.radius;p["sprite_radius"]=e.radius*r.content->definitions[e.definition].sprite_scale;p["guard"]=e.guard;p["held"]=e.held;p["hp"]=e.hp;p["mode"]=int(e.mode);p["velocity"]=e.vel;p["color"]=r.content->definitions[e.definition].color;p["parent"]=e.parent_id;p["born_age"]=2.0;for (const auto &m:b.draco->picaro) if (r.state.enemy_handles.contains(m.actor) && r.state.enemy_handles.entity_id(m.actor)==e.id) p["born_age"]=std::max(0.0,b.clock-m.born);godot::PackedInt64Array parts;for (auto h:e.parts) if (r.state.enemy_handles.contains(h)) parts.push_back(r.state.enemy_handles.entity_id(h));p["parts"]=parts;out.push_back(p);}return out;
}
}
