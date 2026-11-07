#include "tail_slam.h"
#include "body.h"
#include "pose.h"
#include "tail_motion.h"
#include "../../output/frame_builder.h"
#include "../flow/phase_controller.h"
#include "../../systems/attacks/zone.h"
#include "../../systems/attacks/wave.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double REACH=3; // 尾の先の着地点からこの半径倍までに機体がいるときだけ使う
const DracoTailSlamDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->draco_tail_slams.begin(),r.content->draco_tail_slams.end(),[&](const auto &d){return d.technique==t.definition;});}
DracoTailTiming timing(const BossTechniqueDefinition &p) {return {p.warn,p.active,p.recover};}
void place(RunRuntime &r,const TechniqueState &t,double clock) {const auto &s=std::get<DracoTailSlamState>(t.detail.get<DracoTechniqueState>().move);auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];double facing=s.axis;auto points=DracoTailMotion::slam(s.base,s.axis,s.origin,DracoBody::rule(r,b).body_length,s.mirror,timing(r.content->boss_techniques[t.definition-1]),clock,&facing);e.pos=points.front();e.facing=facing;b.draco->override_points=std::move(points);}
godot::Vector2 tip(const RunRuntime &r,const std::vector<godot::Vector2> &base,double axis,godot::Vector2 origin,double mirror,double length,const BossTechniqueDefinition &p) {const auto timed=timing(p);return DracoTailMotion::slam(base,axis,origin,length,mirror,timed,timed.warn+DracoTailMotion::strike_time(timed),nullptr).back();}
}
bool DracoTailSlam::in_reach(const RunRuntime &r,const BossBodyState &b,uint32_t definition) {if (r.state.control.lab_mode) return true;const auto &p=DracoBody::rule(r,b);const auto &q=r.content->boss_techniques[definition-1];const auto &d=*std::find_if(r.content->draco_tail_slams.begin(),r.content->draco_tail_slams.end(),[&](const auto &v){return v.technique==definition;});const auto &e=r.state.enemies[b.actor.slot];const auto base=DracoPose::samples(DracoPose::points(r,b),p.body_segments+1);for (double mirror:{-1.0,1.0}) if (tip(r,base,e.facing,e.pos,mirror,p.body_length,q).distance_to(r.state.ship_pos)<=d.radius*REACH) return true;return false;}
void DracoTailSlam::begin(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();v.move=DracoTailSlamState{};auto &s=std::get<DracoTailSlamState>(v.move);auto &b=*PhaseController::find(r,t.actor);const auto &e=r.state.enemies[t.actor.slot];const auto &p=DracoBody::rule(r,b);const auto &q=r.content->boss_techniques[t.definition-1];s.origin=e.pos;s.axis=e.facing;s.base=DracoPose::samples(DracoPose::points(r,b),p.body_segments+1);const auto left=tip(r,s.base,s.axis,s.origin,-1,p.body_length,q),right=tip(r,s.base,s.axis,s.origin,1,p.body_length,q);s.mirror=left.distance_to(r.state.ship_pos)<right.distance_to(r.state.ship_pos)?-1:1;s.target=s.mirror<0?left:right;}
void DracoTailSlam::windup(RunRuntime &r,TechniqueState &t) {place(r,t,t.detail.get<DracoTechniqueState>().stage_time);}
void DracoTailSlam::active(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoTailSlamState>(v.move);auto &b=*PhaseController::find(r,t.actor);const auto &p=r.content->boss_techniques[t.definition-1];const auto &d=rule(r,t);place(r,t,p.warn+v.stage_time);if (s.fired || v.stage_time<DracoTailMotion::strike_time(timing(p))) return;s.fired=true;{godot::Dictionary shake;shake["amount"]=30.0;FrameBuilder::append(r,"draco_shake",shake);}const auto ticket=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));
    ZoneParams zone;zone.position=s.target;zone.radius=d.radius;zone.damage=p.damage*r.state.combat_config.atk_scale;zone.owner=t.actor;zone.technique=ticket;ZoneSystem::emit(r,zone);
    WaveParams wave;wave.position=s.target;wave.arc=3.141592653589793;wave.radius=d.radius*1.6;wave.speed=330;wave.width=18;wave.damage=p.damage*0.5*r.state.combat_config.atk_scale;wave.owner=t.actor;wave.technique=ticket;WaveSystem::emit(r,wave);
    b.draco->impacts.push_back({s.target,b.clock,d.radius,t.definition});if (b.draco->impacts.size()>32) b.draco->impacts.erase(b.draco->impacts.begin());
}
void DracoTailSlam::end(RunRuntime &r,TechniqueState &t,bool cancelled) {auto &v=t.detail.get<DracoTechniqueState>();v.warning_paths.clear();v.attack.clear();auto *b=PhaseController::find(r,t.actor);if (b && cancelled) DracoPose::reset(r,*b);}
void DracoTailSlam::recover(RunRuntime &r,TechniqueState &t) {const auto &p=r.content->boss_techniques[t.definition-1];place(r,t,p.warn+p.active+t.detail.get<DracoTechniqueState>().stage_time);}
bool DracoTailSlam::validate(const DracoTailSlamState &s) {if (!s.origin.is_finite() || !s.target.is_finite() || !std::isfinite(s.axis) || s.base.size()<2) return false;for (auto p:s.base) if (!p.is_finite()) return false;return true;}
godot::Dictionary DracoTailSlam::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &v=t.detail.get<DracoTechniqueState>();const auto &s=std::get<DracoTailSlamState>(v.move);godot::Dictionary out;godot::PackedVector2Array markers;if (t.stage==TechniqueStage::Windup) markers.push_back(s.target);out["telegraph_points"]=markers;out["telegraph_radius"]=rule(r,t).radius;out["target"]=s.target;out["fired"]=s.fired;return out;}
}
