#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "regrow.h"
#include "swim.h"
#include "../../systems/motion_math.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../systems/field.h"
#include "../../systems/collision_query.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
using V=godot::Vector2;
// 蛇は泳ぎ続け、1匹ずつ止まって機体を狙う。ビームは撃った場所に残り、プレイヤーがよけた跡が格子になる。
constexpr double START=1.4,GAP=0.7,STOP=0.75,LOCK=0.4,HOLD=1.9,REACH=380;
const HydraGridDefinition &grid_rule(const RunRuntime &r,uint32_t definition) {return *std::find_if(r.content->hydra_grids.begin(),r.content->hydra_grids.end(),[&](const auto &v){return v.technique==definition;});}
double wave(double n) {const double v=std::sin(n*127.1+311.7)*43758.5453;return v-std::floor(v);}
HydraNeckState *pick(RunRuntime &r,BossBodyState &b,const HydraTechniqueState &v,const HydraGridState &g) {
    // 機体から見て、これまでに撃った蛇と離れた方向にいる蛇を次に選ぶ。
    const auto ship=r.state.ship_pos;HydraNeckState *best=nullptr;double top=-1e18;
    for (size_t i=0;i<v.participants.size();++i) {auto *n=HydraNormalAttack::neck(b,v.participants[i]);if (!n || !HydraRegrow::alive(r,*n) || std::any_of(g.shots.begin(),g.shots.end(),[&](const auto &q){return same_handle(q.actor,n->actor);})) continue;const double bearing=(n->free_pos-ship).angle();double score=-double(n->free_pos.distance_to(ship));if (!g.shots.empty()) {score=1e9;for (const auto &q:g.shots) if (const auto *m=HydraNormalAttack::neck(b,q.actor)) score=std::min(score,std::abs(angle_difference(bearing-(m->free_pos-ship).angle())));}if (score>top) {top=score;best=n;}}
    return best;
}
}
bool HydraTechnique::grid_ready(const RunRuntime &r,const BossBodyState &b,uint32_t definition) {return b.hydra->separated && HydraRegrow::alive(r,b.hydra->bearer) && size_t(std::count_if(b.hydra->necks.begin(),b.hydra->necks.end(),[&](const auto &n){return HydraRegrow::alive(r,n);}))>=grid_rule(r,definition).minimum;}
void HydraTechnique::grid_prepare(RunRuntime &r,TechniqueState &t) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();HydraGridState g;godot::Rect2 rect(r.state.view_center-r.state.view_half,r.state.view_half*2);for (const auto &a:r.state.field.arenas) if (same_handle(a.owner,b.actor)) rect=rect.intersection(a.bounds);if (!rect.has_area()) {finish(r,t,true);return;}
    const auto center=rect.get_center();const auto off=r.state.ship_pos-center;g.bearer=center+V(off.x>0?-1:1,off.y>0?-1:1)*rect.size*0.5*V(0.78,0.69);g.center=center;g.finish_at=START+(v.participants.size()-1)*GAP+HOLD;
    for (size_t i=0;i<v.participants.size();++i) {const auto *n=HydraNormalAttack::neck(b,v.participants[i]);const auto at=n?n->free_pos-center:V(1,0);g.orbit.push_back({at.angle(),double(at.length()),(i%2?1:-1)*(0.16+wave(i*6.7)*0.1)});}
    v.move=g;
}
std::optional<V> HydraTechnique::bearer_target(const RunRuntime &r,const BossBodyState &b) {for (const auto &t:r.state.bosses->techniques) if (same_handle(t.actor,b.actor) && t.stage<TechniqueStage::Finished && supports(r.content->boss_techniques[t.definition-1].kind)) if (const auto *v=t.detail.get_if<HydraTechniqueState>()) if (const auto *g=std::get_if<HydraGridState>(&v->move)) return g->bearer;return {};}
void HydraTechnique::grid(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();auto &g=std::get<HydraGridState>(v.move);const auto &p=grid_rule(r,t.definition);g.elapsed+=dt;v.time=t.elapsed=g.elapsed;if (g.elapsed>=g.finish_at) {finish(r,t,false);return;}
    if (std::none_of(v.participants.begin(),v.participants.end(),[&](auto actor){return r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;})) {finish(r,t,true);return;}
    while (g.fired<v.participants.size() && g.elapsed>=START+g.fired*GAP-STOP) {const double fire=START+g.fired*GAP;++g.fired;if (auto *n=pick(r,b,v,g)) {HydraGridShot shot;shot.actor=n->actor;shot.fire_at=fire;g.shots.push_back(shot);n->velocity={};}}
    const auto ship=r.state.ship_pos;
    for (size_t i=0;i<v.participants.size();++i) {
        auto *n=HydraNormalAttack::neck(b,v.participants[i]);if (!n || !HydraRegrow::alive(r,*n)) continue;auto shot=std::find_if(g.shots.begin(),g.shots.end(),[&](const auto &q){return same_handle(q.actor,n->actor);});
        if (shot==g.shots.end()) {auto &o=g.orbit[i];o.angle+=o.speed*dt;HydraSwim::steer(r,b,*n,g.center*0.7+ship*0.3+V(std::cos(o.angle)*o.radius*1.25,std::sin(o.angle)*o.radius*0.82),dt,0.9,true);}
        else if (g.elapsed<shot->fire_at-LOCK) {const double aim=(ship-n->free_pos).angle();n->angle+=angle_difference(aim-n->angle)*std::min(1.0,dt*10);n->look_angle=n->angle;}
        else if (!shot->locked) {auto d=(ship-n->free_pos).normalized();if (d.is_zero_approx()) d=V::from_angle(n->angle);n->angle=n->look_angle=d.angle();shot->end=ship+d*REACH;shot->locked=true;}
        n->strike_pos=n->free_pos;r.state.enemies[n->actor.slot].pos=n->free_pos;if (shot!=g.shots.end()) r.state.enemies[n->actor.slot].facing=n->angle;
        if (shot!=g.shots.end()) n->glow=std::clamp(1+(g.elapsed-shot->fire_at)/STOP,0.0,1.0);
        if (shot==g.shots.end() || g.elapsed<shot->fire_at || n->emission.generation) continue;
        if (!v.playing) {v.playing=true;t.stage=TechniqueStage::Active;cue(r,b,"attack_started",t.definition);}
        n->emission=emit(r,t,n->actor,{n->strike_pos,shot->end},p.width,0,g.finish_at-shot->fire_at);HydraNormalAttack::cue(r,b,*n,"attack_started",t.definition);
    }
}
bool HydraTechnique::grid_valid(const HydraGridState &g,size_t participants) {if (!g.bearer.is_finite() || !g.center.is_finite() || !std::isfinite(g.elapsed) || g.elapsed<0 || !std::isfinite(g.finish_at) || g.orbit.size()!=participants || g.shots.size()>participants) return false;for (const auto &o:g.orbit) if (!std::isfinite(o.angle) || !std::isfinite(o.radius) || !std::isfinite(o.speed)) return false;for (const auto &q:g.shots) if (!std::isfinite(q.fire_at) || !q.end.is_finite()) return false;return true;}
void HydraTechnique::grid_snapshot(const HydraGridState &g,godot::Dictionary &out) {out["grid_bearer"]=g.bearer;out["grid_elapsed"]=g.elapsed;out["grid_finish_at"]=g.finish_at;out["grid_stop"]=STOP;out["grid_reach"]=REACH;godot::Array shots;for (const auto &q:g.shots) {godot::Dictionary row;row["actor"]=int64_t(handle_key(q.actor));row["fire_at"]=q.fire_at;row["end"]=q.end;row["locked"]=q.locked;shots.push_back(row);}out["grid_shots"]=shots;}
}
