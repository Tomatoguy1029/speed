#include "corona_vortex.h"
#include "../../output/event_builder.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/field.h"
#include "../../systems/motion_math.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
#include <limits>
namespace speed {
namespace {
constexpr double PI=3.141592653589793,TAU=PI*2;
bool live(const RunRuntime &r,EnemyHandle h) {return r.state.enemy_handles.contains(h) && !r.state.enemies[h.slot].dead;}
const CoronaAmmunition *ammo(const RunRuntime &r,const Enemy &owner,uint32_t definition) {const auto &values=r.content->corona_ammunition[r.content->definitions[owner.definition].corona_definition-1];const auto i=std::find_if(values.begin(),values.end(),[&](const auto &p){return p.definition==definition;});return i==values.end()?nullptr:&*i;}
std::string key(EnemyHandle h,const Enemy &e) {return "throw:"+std::to_string(h.slot)+":"+std::to_string(e.id);}
bool current(const RunRuntime &r,const CoronaMemberRef &ref) {return r.state.enemy_handles.contains(ref.target) && r.state.enemies[ref.target.slot].corona && r.state.enemies[ref.target.slot].corona->serial==ref.serial;}
void unstock(RunRuntime &r,EnemyHandle h,const CoronaMember &a) {
    auto &s=r.state;if (a.thrown || !s.enemy_handles.contains(a.owner)) return;auto *o=std::get_if<CoronaState>(&s.enemies[a.owner.slot].behavior_state);if (!o || !o->ready) return;
    const auto bucket=std::find_if(o->types.begin(),o->types.end(),[&](const auto &b){return b.definition==a.definition;});if (bucket==o->types.end() || a.slot>=bucket->items.size()) return;
    const auto last=bucket->items.back();bucket->items[a.slot]=last;if (s.enemy_handles.contains(last) && s.enemies[last.slot].corona) s.enemies[last.slot].corona->slot=a.slot;bucket->items.pop_back();--o->count;if (bucket->items.empty()) o->types.erase(bucket);if (same_handle(o->selected,h)) o->selected={};
}
void detach(RunRuntime &r,EnemyHandle h) {
    auto &s=r.state;if (!s.enemy_handles.contains(h) || !s.enemies[h.slot].corona) return;auto &e=s.enemies[h.slot];const auto a=*e.corona;
    if (a.attack_token) AttackBudgetSystem(r).external(a.attack_token,key(h,e),false);unstock(r,h,a);e.corona.reset();e.held=false;
    if (!e.dead) {e.mode=EnemyMode::Move;e.charge=0;e.timer=0;e.vel=e.vel.limit_length(e.speed);}
}
void cancel(RunRuntime &r,EnemyHandle h,CoronaState &o) {auto &e=r.state.enemies[h.slot];AttackBudgetSystem(r).cancel(AttackBudgetSystem::owner(r.state,e.id,e.attack_group),e.id);o.selected={};o.wait=0;e.mode=EnemyMode::Move;e.charge=0;}
godot::Vector2 velocity(godot::Vector2 center_v,double angle,double radius,double spin) {return center_v+godot::Vector2(-std::sin(angle),std::cos(angle))*radius*spin;}
double error(godot::Vector2 center,godot::Vector2 center_v,double angle,double radius,double spin,godot::Vector2 target) {const auto at=center+godot::Vector2::from_angle(angle)*radius;return angle_difference(double((target-at).angle())-velocity(center_v,angle,radius,spin).angle());}
double turn_to_aim(godot::Vector2 center,godot::Vector2 center_v,double angle,double radius,double spin,godot::Vector2 target,double tolerance) {double previous=error(center,center_v,angle,radius,spin,target);if (std::abs(previous)<=tolerance) return 0;for (int k=1;k<=48;++k) {const double turn=TAU*k/48.0,e=error(center,center_v,angle+(spin>0?1.0:spin<0?-1.0:0)*turn,radius,spin,target);if (previous*e<=0 && std::abs(e-previous)<PI) return turn;previous=e;}return TAU;}
void capture(RunRuntime &r,EnemyHandle owner,CoronaState &o,const CoronaDefinition &p) {
    auto &s=r.state;const auto center=s.enemies[owner.slot].pos,pad=godot::Vector2(p.pull_radius,p.pull_radius);const auto rows=CollisionQuery::enemy_rows(s,center-pad,center+pad);std::vector<EnemyHandle> targets;for (auto row:rows) targets.push_back(s.enemy_handles.at(uint32_t(row)));
    for (auto h:targets) {
        if (o.count>=p.capture_max || s.corona_serial==UINT64_MAX) break;if (!s.enemy_handles.contains(h) || same_handle(h,owner)) continue;auto &e=s.enemies[h.slot];const auto &d=r.content->definitions[e.definition];
        if (e.corona || e.dead || e.is_boss || s.field.rock_handles.contains(e.rock) || e.parent.generation || d.rank>2 || d.gate!=EnemyDefinition::Gate::None || e.stone>0 || e.knock_t>0 || e.shove_time>0) continue;
        const auto *type=ammo(r,s.enemies[owner.slot],uint32_t(e.definition));const auto offset=e.pos-center;if (!type || type->weight<=0 || offset.length()>p.pull_radius) continue;
        auto bucket=std::find_if(o.types.begin(),o.types.end(),[&](const auto &b){return b.definition==e.definition;});if (bucket==o.types.end()) {o.types.push_back({uint32_t(e.definition),{}});bucket=std::prev(o.types.end());}
        CoronaMember a;a.owner=owner;a.definition=uint32_t(e.definition);a.slot=bucket->items.size();a.serial=++s.corona_serial;a.angle=offset.angle();a.radius=std::max(1.0,double(offset.length()));a.from=e.pos;a.ship_from=s.ship_pos;a.effect=p.effect;e.corona=a;bucket->items.push_back(h);++o.count;e.held=true;e.charge=0;s.corona_members.push_back({h,a.serial});EventBuilder::audio(r,"elite.corona.capture",e.pos);
    }
}
void orbit(RunRuntime &r,EnemyHandle h,CoronaMember &a,CoronaState &o,const CoronaDefinition &p,double dt) {
    auto &s=r.state;auto &e=s.enemies[h.slot];auto &owner=s.enemies[a.owner.slot];const auto center0=o.center,center1=owner.pos,center_v=(center1-center0)/dt;const double angle0=a.angle,radius0=a.radius;
    const double radius1=radius0+std::clamp(p.ring-radius0,-std::max(0.0,p.pull)*dt,std::max(0.0,p.pull)*dt),angle1=angle0+p.spin*dt;const auto start=e.pos,finish=center1+godot::Vector2::from_angle(angle1)*radius1;
    const bool ready=a.settled && godot::Math::is_equal_approx(radius0,p.ring) && same_handle(o.selected,h) && o.wait<=0;
    if (ready) {
        const double e0=error(center0,center_v,angle0,radius0,p.spin,s.ship_pos),e1=error(center1,center_v,angle1,radius1,p.spin,s.ship_pos);double f=-1;
        if (e0*e1<=0 && std::abs(e1-e0)<PI) {double lo=0,hi=1;for (int k=0;k<10;++k) {const double mid=(lo+hi)*0.5,err=error(center0.lerp(center1,mid),center_v,angle0+(angle1-angle0)*mid,radius1,p.spin,s.ship_pos);if (err*e0>0) lo=mid;else hi=mid;}f=(lo+hi)*0.5;}else if (std::abs(e0)<=p.align_angle) f=0;
        if (f>=0) {
            const double angle=angle0+(angle1-angle0)*f;const auto at=center0.lerp(center1,f)+godot::Vector2::from_angle(angle)*radius1,direction=velocity(center_v,angle,radius1,p.spin).normalized();
            if (direction!=godot::Vector2() && direction.dot((s.ship_pos-at).normalized())>0) {unstock(r,h,a);a.thrown=true;EventBuilder::audio(r,"elite.corona.throw",at);a.slot=owner.definition;a.angle=angle;const auto owner_key=AttackBudgetSystem::owner(s,owner.id,owner.attack_group);a.attack_token=AttackBudgetSystem::token(s,owner_key);if (a.attack_token) AttackBudgetSystem(r).external(a.attack_token,key(h,e),true);a.life=p.throw_life;if (const auto *type=ammo(r,owner,a.definition)) a.damage=type->damage;a.from=at;a.release_fraction=f;e.vel=direction*p.throw_speed;e.pos=at+e.vel*dt*(1.0-f);e.facing=direction.angle();cancel(r,a.owner,o);owner.fire_t=r.content->definitions[owner.definition].fire_interval;return;}
        }
    }
    a.angle=angle1;a.radius=radius1;a.settled=godot::Math::is_equal_approx(radius1,p.ring);e.pos=finish;e.vel=(finish-start)/dt;e.facing=e.vel.angle();
}
}
void CoronaVortex::release(RunRuntime &r,EnemyHandle h) {
    if (!r.state.enemy_handles.contains(h)) return;auto *o=std::get_if<CoronaState>(&r.state.enemies[h.slot].behavior_state);
    if (o) {const auto refs=r.state.corona_members;for (const auto &ref:refs) if (current(r,ref) && same_handle(r.state.enemies[ref.target.slot].corona->owner,h)) {
        auto &member=*r.state.enemies[ref.target.slot].corona;
        if (!member.thrown) {detach(r,ref.target);continue;}
        member.slot=r.state.enemies[h.slot].definition;
        if (member.attack_token) AttackBudgetSystem(r).external(member.attack_token,key(ref.target,r.state.enemies[ref.target.slot]),false);
        member.attack_token=0;member.owner={};
    }*o={};}
    detach(r,h);
}
void CoronaVortex::death_marked(RunRuntime &r,const DeathContext &death) {release(r,death.target);}
void CoronaVortex::tick(RunRuntime &r,double dt,const std::vector<EnemyHandle> &owners) {
    if (dt<=0) return;auto &s=r.state;
    for (auto h:owners) {
        if (!live(r,h)) continue;auto &e=s.enemies[h.slot];auto &o=std::get<CoronaState>(e.behavior_state);const auto &p=r.content->coronas[r.content->definitions[e.definition].corona_definition-1];if (!o.ready) {o.ready=true;o.center=e.pos;}
        if (e.stone>0) {cancel(r,h,o);o.center=e.pos;continue;}
        const bool fast=s.draw.tracing || s.ship.glide || s.ship.vel.length()>=s.ship_config.max_speed*s.combat_config.ram_speed_ratio;const auto delta=e.pos-s.ship_pos;const double dist=delta.length();if (!fast && dist<p.pull_radius && dist>=1) s.ship.vel+=delta/dist*(p.pull*dt)*(1.0-dist/p.pull_radius);
        o.capture_t-=dt;if (o.capture_t<=0) {o.capture_t=std::max(p.capture_interval,dt);capture(r,h,o,p);}e.fire_t=std::max(0.0,e.fire_t-dt);
        const auto owner_key=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
        if (e.pos.distance_to(s.ship_pos)<=p.ring+s.ship_config.ship_radius || !o.count) cancel(r,h,o);
        else if (!o.selected.generation && e.fire_t<=0 && (!e.attack_managed || (budget.owns(owner_key,e.id) && EnemySystem::attack_active(s,h)) || budget.request({owner_key,{AttackCategory::Aimed},h,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:r.content->definitions[e.definition].attack_weight}))) {
            double total=0;for (const auto &b:o.types) if (const auto *type=ammo(r,e,b.definition)) total+=type->weight;
            if (total>0) {double roll=s.control.rng.randf()*total;const CoronaBucket *bucket=nullptr;for (const auto &b:o.types) {if (const auto *type=ammo(r,e,b.definition)) roll-=type->weight;if (roll<0) {bucket=&b;break;}}
                if (bucket && !bucket->items.empty()) {o.selected=bucket->items.front();double best=std::numeric_limits<double>::infinity();const auto center_v=(e.pos-o.center)/std::max(dt,0.001);for (auto candidate:bucket->items) {if (!s.enemy_handles.contains(candidate) || !s.enemies[candidate.slot].corona) continue;const auto &a=*s.enemies[candidate.slot].corona;double turn=turn_to_aim(e.pos,center_v,a.angle+p.spin*p.telegraph,p.ring,p.spin,s.ship_pos,p.align_angle);if (!a.settled) turn+=TAU;if (turn<best) {best=turn;o.selected=candidate;}}o.wait=p.telegraph;e.mode=EnemyMode::Windup;EventBuilder::audio(r,"elite.corona.tell",e.pos);}
            }
        }
        if (o.selected.generation) {o.wait-=dt;e.charge=std::clamp(1.0-o.wait/std::max(p.telegraph,0.001),0.0,1.0);if (o.wait<-TAU/std::max(std::abs(p.spin),0.1)) {cancel(r,h,o);e.fire_t=r.content->definitions[e.definition].fire_interval;}}
    }
    const auto members=s.corona_members;
    for (const auto &ref:members) {
        if (!current(r,ref)) continue;auto &e=s.enemies[ref.target.slot];auto &a=*e.corona;
        if (!live(r,ref.target) || (!a.thrown && (!live(r,a.owner) || e.stone>0 || e.shove_time>0 || e.knock_t>0))) {detach(r,ref.target);continue;}
        e.age+=dt;e.hit_cd=std::max(0.0,e.hit_cd-dt);e.guard=std::max(0.0,e.guard-dt);e.flash=std::max(0.0,e.flash-dt);a.from=e.pos;a.ship_from=s.ship_pos;a.release_fraction=0;
        if (a.thrown) {
            const auto owner_definition=s.enemy_handles.contains(a.owner)?s.enemies[a.owner.slot].definition:a.slot;
            const auto &p=r.content->coronas[r.content->definitions[owner_definition].corona_definition-1];
            e.vel=godot::Vector2::from_angle(e.facing)*p.throw_speed;
            const double travel=std::min(dt,std::max(0.0,a.life));a.life-=travel;e.pos+=e.vel*travel;
        } else {
            auto &owner=s.enemies[a.owner.slot];auto &o=std::get<CoronaState>(owner.behavior_state);const auto &p=r.content->coronas[r.content->definitions[owner.definition].corona_definition-1];
            if (owner.stone<=0) orbit(r,ref.target,a,o,p,dt);else e.vel={};
            if (current(r,ref) && !a.thrown && FieldSystem::first_body_hit(r,a.from,e.pos,e.radius)) {FieldSystem::collide_enemy(r,ref.target.slot,a.from,dt);detach(r,ref.target);}
        }
    }
    for (auto h:owners) if (live(r,h)) std::get<CoronaState>(s.enemies[h.slot].behavior_state).center=s.enemies[h.slot].pos;
    s.corona_members.erase(std::remove_if(s.corona_members.begin(),s.corona_members.end(),[&](const auto &ref){return !current(r,ref);}),s.corona_members.end());
}
bool CoronaVortex::hit_thrown(RunRuntime &r) {
    auto &s=r.state;const auto refs=s.corona_members;
    for (const auto &ref:refs) {
        if (!current(r,ref) || !live(r,ref.target)) continue;const auto e=s.enemies[ref.target.slot];const auto a=*e.corona;if (!a.thrown) continue;const double reach=e.radius*a.effect+s.ship_config.ship_radius;const auto ship_from=a.ship_from.lerp(s.ship.pos,a.release_fraction);
        const double hit=CollisionQuery::segment_circle_t(a.from-ship_from,e.pos-s.ship.pos,{},reach);
        // 同じ移動区間に機体と天体があるときは、先に触れた方で消える。
        if (const auto body=FieldSystem::first_body_hit(r,a.from,e.pos,e.radius);body && (hit<0 || body->t<=hit)) {
            s.enemies[ref.target.slot].pos=body->point;
            EnemySystem::retire(r,ref.target,RetireReason::CoronaThrowEnd);continue;
        }
        if (hit<0) {if (a.life<=0) EnemySystem::retire(r,ref.target,RetireReason::CoronaThrowEnd);continue;}
        const uint32_t source=uint32_t((s.enemy_handles.contains(a.owner)?s.enemies[a.owner.slot].definition:a.slot)+1);
        s.enemies[ref.target.slot].pos=a.from.lerp(e.pos,hit);
        EnemySystem::retire(r,ref.target,RetireReason::CoronaThrowEnd);ShipDamageRequest request;request.amount=a.damage;request.cause=Cause::CoronaThrow;request.source=source;CombatResolver::ship_damage(r,request);if (s.phase!=godot::RunState::Phase::Play) return false;
    }return true;
}
}
