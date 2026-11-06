#include "finale.h"
#include "body.h"
#include "pose.h"
#include "intro.h"
#include "cycle.h"
#include "picaro.h"
#include "cinematic.h"
#include "rifts.h"
#include "../flow/phase_controller.h"
#include "../flow/technique_runner.h"
#include "../flow/flow_runner.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double PI=3.141592653589793,TAU=PI*2;
using Stage=DracoFinaleStage;
// 指定図が決まるまでの最終姿勢。胴の長さへ合わせて縮尺するので、節の長さは変わらない。
constexpr double POSE_WAY[][2]={{-226,-205},{-140,-182},{40,-176},{170,-140},{214,-70},{150,-12},{-60,0},{-205,30},{-235,92},{-170,144},{10,158},{130,146},{190,108}};
constexpr double DOCK_FIRST=0.9,DOCK_STEP=0.42,UNLOCK_AT=2.6,ROAR_AT=2.72,BURST_AT=0.92;
const char *const MODULES[]={"legendary_stern","legendary_keel","legendary_sail","legendary_compass"};
double smooth(double a,double b,double x) {const double f=std::clamp((x-a)/(b-a),0.0,1.0);return f*f*(3-2*f);}
double lerp(double a,double b,double k) {return a+(b-a)*k;}
double out_cubic(double k) {const double m=1-std::clamp(k,0.0,1.0);return 1-m*m*m;}
double out_expo(double k) {return k>=1?1:1-std::pow(2.0,-10*std::clamp(k,0.0,1.0));}
const DracoFinaleDefinition *rule(const RunRuntime &r,const BossBodyState &b) {const auto id=r.content->boss_bodies[b.definition-1].boss;const auto it=std::find_if(r.content->draco_finales.begin(),r.content->draco_finales.end(),[&](const auto &p){return p.boss==id;});return it==r.content->draco_finales.end()?nullptr:&*it;}
void next(DracoFinaleState &v,Stage stage) {v.stage=stage;v.time=0;}
void shake(RunRuntime &r,double amount) {godot::Dictionary e;e["amount"]=amount;FrameBuilder::append(r,"draco_shake",e);}
void cue(RunRuntime &r,const char *name,godot::Vector2 at,double radius) {godot::Dictionary e;e["cue"]=name;e["pos"]=at;e["radius"]=radius;e["boss"]="draco";FrameBuilder::append(r,"draco_cue",e);}
double flash_time(const DracoFinaleDefinition &p) {return p.flash_from+p.flash_ramp+p.flash_peak+p.flash_fade+p.flash_after;}
std::vector<godot::Vector2> even(const std::vector<godot::Vector2> &points,uint32_t segments) {
    std::vector<godot::Vector2> out{points.front()};double total=0;for (size_t j=1;j<points.size();++j) total+=points[j].distance_to(points[j-1]);
    size_t cursor=0;double walked=0,span=points[0].distance_to(points[1]);
    for (uint32_t j=1;j<=segments;++j) {const double target=total*j/segments;while (cursor+2<points.size() && target>walked+span) {walked+=span;++cursor;span=points[cursor].distance_to(points[cursor+1]);}out.push_back(points[cursor].lerp(points[cursor+1],std::clamp((target-walked)/std::max(0.001,span),0.0,1.0)));}
    return out;
}
std::vector<godot::Vector2> final_pose(double length,uint32_t segments) {
    constexpr int count=sizeof(POSE_WAY)/sizeof(POSE_WAY[0]);std::vector<godot::Vector2> dense;const auto at=[&](int i){const auto &w=POSE_WAY[std::clamp(i,0,count-1)];return godot::Vector2(w[0],w[1]);};
    for (int i=0;i<count-1;++i) for (int k=0;k<24;++k) {const double u=k/24.0;const auto p0=at(i-1),p1=at(i),p2=at(i+1),p3=at(i+2);dense.push_back((p1*2+(p2-p0)*u+(p0*2-p1*5+p2*4-p3)*u*u+(p1*3-p0-p2*3+p3)*u*u*u)*0.5);}
    dense.push_back(at(count-1));double total=0;for (size_t j=1;j<dense.size();++j) total+=dense[j].distance_to(dense[j-1]);for (auto &q:dense) q*=length/total;return even(dense,segments);
}
std::vector<double> headings(const std::vector<godot::Vector2> &points) {std::vector<double> out;for (size_t j=0;j+1<points.size();++j) {double a=(points[j+1]-points[j]).angle();if (!out.empty()) {while (a-out.back()>PI) a-=TAU;while (a-out.back()<-PI) a+=TAU;}out.push_back(a);}return out;}
void place(RunRuntime &r,BossBodyState &b,godot::Vector2 head,const std::vector<double> &angles,double step) {std::vector<godot::Vector2> points{head};for (double a:angles) points.push_back(points.back()+godot::Vector2::from_angle(a)*step);b.draco->override_points=points;auto &e=r.state.enemies[b.actor.slot];e.pos=points[0];e.facing=(points[0]-points[1]).angle();}
void writhe(RunRuntime &r,BossBodyState &b,double t) {auto &v=b.draco->finale;const double force=smooth(0,0.5,t)*(1-smooth(1.0,3.6,t));auto angles=v.heading_from;for (size_t j=0;j<angles.size();++j) angles[j]+=force*0.34*std::sin(double(j)/angles.size()*15-t*11);place(r,b,v.head_from+godot::Vector2(0,-26*force),angles,v.step);}
void settle(RunRuntime &r,BossBodyState &b,double u) {auto &v=b.draco->finale;auto angles=v.heading_to;for (size_t j=0;j<angles.size();++j) {const double s=double(j)/angles.size(),k=smooth(0,1,(u-0.42*s)/0.58);angles[j]=lerp(v.heading_from[j],v.heading_to[j],k)+std::sin(u*PI)*0.26*std::sin(s*9-u*9)*(0.4+0.6*s);}place(r,b,v.head_from.lerp(v.head_to,smooth(0,0.72,u)),angles,v.step);}
double dock_punch(double t) {double z=0;for (int i=0;i<4;++i) {const double q=t-(DOCK_FIRST+i*DOCK_STEP);if (q>=0) z+=0.3*std::exp(-q*13);}if (t>=UNLOCK_AT) z+=0.42*std::exp(-(t-UNLOCK_AT)*9);return z;}
godot::Vector2 dock_kick(double t) {godot::Vector2 kick;for (int i=0;i<4;++i) {const double q=t-(DOCK_FIRST+i*DOCK_STEP);if (q>=0) kick-=godot::Vector2::from_angle(i*TAU/4+0.5+2.3)*20*std::exp(-q*11);}return kick;}
void frame(RunRuntime &r,BossBodyState &b,const DracoFinaleDefinition &p) {
    auto &v=b.draco->finale;const double t=v.time;auto size=r.state.control.logical_size;if (size.x<=0 || size.y<=0) size={1280,720};
    const auto chase=v.core_to+godot::Vector2(0,40),ship=v.ship_rest+godot::Vector2(0,-16);auto camera=v.center;double zoom=0.52;
    switch (v.stage) {
    case Stage::Release: {const double a=smooth(0,1,t),c=smooth(1.1,2.3,t);camera=v.camera_from.lerp(v.core_from,a).lerp(chase,c);zoom=lerp(1.0,1.32,a)-0.2*c+smooth(2.5,2.75,t)*0.14;break;}
    case Stage::Combine: {const double k=smooth(0,0.5,t);camera=chase.lerp(ship,k);zoom=lerp(1.26,2.45,k*k)+smooth(0.5,2.4,t)*0.35-smooth(2.6,2.9,t)*0.5+dock_punch(t);break;}
    case Stage::Pose: {const double k=smooth(0,1.5,t);camera=ship.lerp(v.center+godot::Vector2(0,28),k);zoom=lerp(2.3,0.82,k);break;}
    case Stage::Input:camera=v.center+godot::Vector2(0,28);zoom=0.82;break;
    case Stage::Strikes: {const double k=std::clamp(t/p.rush_time,0.0,1.0);camera=v.center+godot::Vector2(0,lerp(28,0,k));zoom=lerp(0.82,1.1,k*k);break;}
    case Stage::Charge:zoom=lerp(1.12,0.52,out_cubic(t/p.charge_time));break;
    default:break;
    }
    DracoCinematic::frame(r,camera,zoom*size.y/720);
}
}
bool DracoFinale::begin(RunRuntime &r,BossBodyState &b) {
    if (!rule(r,b)) return false;if (b.draco->finale.active) dispose(r,b);const auto original_ship=r.state.ship_pos,original_velocity=r.state.ship.vel;
    DracoIntro::end(r,b,true);for (uint32_t row=0;row<r.state.bosses->techniques.size();++row) if (same_handle(r.state.bosses->techniques[row].actor,b.actor)) TechniqueRunner::cancel(r,r.state.bosses->handles.at(row));DracoCycle::cancel(r,b);DracoPicaro::pause(r,b,true);for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) {FlowRunner::cancel(r,f);f.suspended=true;}
    auto &v=b.draco->finale;v={};DracoCinematic::capture(r,v.saved);const auto &p=DracoBody::rule(r,b);auto &e=r.state.enemies[b.actor.slot];v.modules_before=r.state.control.final_modules;v.finish_before=r.state.control.draco_finish_done;r.state.control.final_modules.clear();r.state.control.draco_finish_done=false;v.original_ship=original_ship;v.original_velocity=original_velocity;v.original_pos=e.pos;v.original_angle=e.facing;v.original_guard=e.guard;v.camera_from=r.state.view_center;v.zoom=std::max(0.1,r.state.control.camera_zoom);v.center=e.pos-godot::Vector2::from_angle(e.facing)*p.body_length*0.32;v.ship_rest=original_ship;
    const auto from=even(DracoPose::points(r,b),p.body_segments),to=final_pose(p.body_length,p.body_segments);v.step=p.body_length/p.body_segments;v.head_from=from.front();v.head_to=v.center+to.front();v.heading_from=headings(from);v.heading_to=headings(to);double offset=0;for (size_t j=0;j<v.heading_to.size();++j) offset+=v.heading_from[j]-v.heading_to[j];offset=TAU*std::round(offset/v.heading_to.size()/TAU);for (auto &a:v.heading_to) a+=offset;
    v.core=v.core_from=from[size_t(from.size()*0.175)];v.core_to=v.core_from+godot::Vector2(-40,-300);
    v.stage=Stage::Release;v.active=true;b.mode=BossMode::Final;e.hp=1;e.guard=1;e.vel={};auto &s=r.state;s.controls_locked=s.encounter_protected=true;s.control.cinematic_bars=1;s.control.cinematic_camera=s.control.cinematic_hide_enemies=true;s.draw.drawing=s.draw.tracing=false;s.ship.vel={};s.control.world_scale=0;TechniqueRunner::observe_scripted(r,b,"draco_finale","scripted_finale",ObservationEvent::Warning,true);return true;
}
bool DracoFinale::tick(RunRuntime &r,double dt,const InputFrame &input,godot::Vector2 size) {
    auto found=std::find_if(r.state.bosses->bodies.begin(),r.state.bosses->bodies.end(),[](const auto &b){return b.draco->finale.active;});if (found==r.state.bosses->bodies.end()) return false;auto &b=*found;auto &v=b.draco->finale;const auto *p=rule(r,b);if (!p || !r.state.enemy_handles.contains(b.actor)) {dispose(r,b);return true;}auto &s=r.state;s.control.logical_size=size;v.time+=dt;b.clock+=dt;DracoRifts::tick_closing(r,b,dt);s.control.world_scale=0;
    TechniqueRunner::observe_scripted(r,b,"draco_finale","scripted_finale",v.stage>=Stage::Strikes?ObservationEvent::Execute:ObservationEvent::Warning);
    switch(v.stage) {
    case Stage::Release:
        writhe(r,b,v.time);
        if (v.time>=BURST_AT) {v.core=v.core_from.lerp(v.core_to,out_expo((v.time-BURST_AT)/0.9));if (!v.burst) {v.burst=true;cue(r,"core_released",v.core_from,100);shake(r,14);}}
        if (v.time>=ROAR_AT && !v.roared) {v.roared=true;b.draco->roar_mouth=v.core_to+godot::Vector2(135,-40);b.draco->roar_at=b.clock;cue(r,"bear_roar",v.core_to,180);shake(r,20);}
        if (v.time>=p->release_time) next(v,Stage::Combine);
        break;
    case Stage::Combine:
        writhe(r,b,p->release_time+v.time);s.ship_pos=s.ship.pos=v.ship_rest+dock_kick(v.time);
        while (v.docked<4 && v.time>=DOCK_FIRST+v.docked*DOCK_STEP) {s.control.final_modules.push_back(MODULES[v.docked++]);shake(r,17);}
        if (v.time>=UNLOCK_AT && !v.unlocked) {v.unlocked=true;shake(r,24);}
        if (v.time>=p->combine_time) next(v,Stage::Pose);
        break;
    case Stage::Pose:
        settle(r,b,std::clamp(v.time/p->pose_time,0.0,1.0));s.ship_pos=s.ship.pos=v.ship_rest.lerp(v.center+godot::Vector2(0,396),smooth(0.2,2.2,v.time));s.ship.heading={0,-1};
        if (v.time>=p->pose_time) {next(v,Stage::Input);s.controls_locked=false;s.control.cinematic_bars=0;for (uint32_t j=0;j<=320;++j) {const double u=j/320.0,a=u*TAU+0.05*std::sin(u*TAU*5+0.6),radius=345*std::cos(4*a)*(1+0.14*std::sin(u*TAU*3+1));v.guide.push_back(v.center+godot::Vector2::from_angle(a)*radius);}}
        break;
    case Stage::Input:if ((input.press || input.alt_press || input.finale_pressed) && !v.began) {v.began=true;v.strokes.push_back(input.finale_pen);}if (v.began && input.has_cursor && (v.strokes.empty() || v.strokes.back().distance_to(input.finale_pen)>3)) v.strokes.push_back(input.finale_pen);if (v.began && (input.pen_release || input.finale_released)) {next(v,Stage::Strikes);s.controls_locked=true;s.draw.drawing=false;s.control.cinematic_bars=1;s.control.cinematic_hide_ship=true;}else s.draw.drawing=v.began;break;
    case Stage::Strikes:if (v.time>=p->rush_time) {next(v,Stage::Charge);s.ship_pos=s.ship.pos=v.center+godot::Vector2(0,385);s.ship.heading={0,-1};}break;
    case Stage::Charge:if (v.time>=p->charge_time+p->hold_time) next(v,Stage::Flash);break;
    case Stage::Flash:if (v.time>=flash_time(*p)) next(v,Stage::Sight);break;
    case Stage::Sight:if (v.time>=p->sight_time) {next(v,Stage::Explode);cue(r,"cosmic_collapse",v.center,800);}break;
    case Stage::Explode:if (v.time>=p->explode_time) {v.completed=true;s.control.draco_finish_done=true;v.active=false;dispose(r,b);DeathContext death;death.target=b.actor;death.corpse.id=s.enemies[b.actor.slot].id;death.corpse.pos=s.enemies[b.actor.slot].pos;death.request.cause=Cause::DracoFinale;PhaseController::defeated(r,death);return true;}break;
    default:break;
    }
    frame(r,b,*p);DracoBody::update(r,b);return true;
}
void DracoFinale::dispose(RunRuntime &r,BossBodyState &b) {
    auto &v=b.draco->finale;if (!v.saved.saved) return;TechniqueRunner::finish_scripted(r,b,v.completed?"finished":"cancelled");DracoCinematic::restore(r,v.saved);r.state.control.cinematic_hide_ship=false;if (!v.completed) {r.state.control.final_modules=v.modules_before;r.state.control.draco_finish_done=v.finish_before;r.state.ship_pos=r.state.ship.pos=v.original_ship;r.state.ship.vel=v.original_velocity;DracoPose::reset(r,b);if(r.state.enemy_handles.contains(b.actor)) {auto &e=r.state.enemies[b.actor.slot];e.pos=v.original_pos;e.facing=v.original_angle;e.guard=v.original_guard;b.mode=BossMode::Idle;DracoBody::update(r,b);}v.stage=Stage::None;}v.active=false;
}
bool DracoFinale::validate(const BossBodyState &b) {const auto &v=b.draco->finale;for(double x:{v.time,v.zoom,v.step,v.original_angle,v.original_guard}) if(!std::isfinite(x))return false;if(v.time<0 || v.zoom<=0 || v.step<=0 || v.docked>4 || v.stage>Stage::Explode || (v.active && (!v.saved.saved || v.completed || b.mode!=BossMode::Final || v.heading_from.empty() || v.heading_from.size()!=v.heading_to.size())))return false;for(auto q:{v.center,v.core,v.core_from,v.core_to,v.camera_from,v.head_from,v.head_to,v.ship_rest,v.original_pos,v.original_ship,v.original_velocity})if(!q.is_finite())return false;for(const auto *points:{&v.guide,&v.strokes})for(auto q:*points)if(!q.is_finite())return false;for(const auto *angles:{&v.heading_from,&v.heading_to})for(double a:*angles)if(!std::isfinite(a))return false;return true;}
void DracoFinale::snapshot(const RunRuntime &r,const BossBodyState &b,godot::Dictionary &out) {const auto &v=b.draco->finale;godot::Dictionary x;const char *names[]={"","release","combine","pose","input","strikes","charge","flash","sight","explode"};x["stage"]=names[uint8_t(v.stage)];x["active"]=v.active;x["completed"]=v.completed;x["began"]=v.began;x["time"]=v.time;x["center"]=v.center;x["core"]=v.core;x["core_from"]=v.core_from;x["core_to"]=v.core_to;x["ship_rest"]=v.ship_rest;x["docked"]=v.docked;for(const auto &pair:{std::make_pair("guide",&v.guide),std::make_pair("strokes",&v.strokes)}) {godot::PackedVector2Array a;for(auto q:*pair.second)a.push_back(q);x[pair.first]=a;}if (const auto *p=rule(r,b)) {godot::Dictionary t;t["rush"]=p->rush_time;t["charge"]=p->charge_time;t["hold"]=p->hold_time;t["line"]=p->line_time;t["from"]=p->flash_from;t["ramp"]=p->flash_ramp;t["peak"]=p->flash_peak;t["fade"]=p->flash_fade;t["after"]=p->flash_after;t["sight"]=p->sight_time;t["combine"]=p->combine_time;x["times"]=t;}out["finale"]=x;}
}
