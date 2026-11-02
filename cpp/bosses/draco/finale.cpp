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
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double PI=3.141592653589793,TAU=PI*2;
using Stage=DracoFinaleStage;
double smooth(double a,double b,double x) {const double f=std::clamp((x-a)/(b-a),0.0,1.0);return f*f*(3-2*f);}
const DracoFinaleDefinition *rule(const RunRuntime &r,const BossBodyState &b) {const auto id=r.content->boss_bodies[b.definition-1].boss;const auto it=std::find_if(r.content->draco_finales.begin(),r.content->draco_finales.end(),[&](const auto &p){return p.boss==id;});return it==r.content->draco_finales.end()?nullptr:&*it;}
void next(DracoFinaleState &v,Stage stage) {v.stage=stage;v.time=0;}
void cue(RunRuntime &r,const char *name,godot::Vector2 at,double radius) {godot::Dictionary e;e["cue"]=name;e["pos"]=at;e["radius"]=radius;e["boss"]="draco";FrameBuilder::append(r,"draco_cue",e);if (std::string(name)=="bear_roar") {godot::Dictionary roar;roar["pos"]=at;roar["radius"]=700;FrameBuilder::append(r,"draco_roar",roar);}}
void frame(RunRuntime &r,BossBodyState &b,const DracoFinaleDefinition &p) {
    auto &v=b.draco.finale;double zoom=v.zoom*0.82;auto camera=v.center;
    if (v.stage==Stage::Release || v.stage==Stage::Combine) {
        const auto head=r.state.enemies[b.actor.slot].pos;const double radius=b.draco.head_scale*165;godot::Rect2 bounds(head-godot::Vector2(radius,radius),godot::Vector2(radius*2,radius*2));bounds=bounds.merge(godot::Rect2(r.state.ship_pos-godot::Vector2(64,64),{128,128}));bounds=bounds.merge(godot::Rect2(v.core-godot::Vector2(280,280),{560,560}));camera=bounds.get_center();if (v.stage==Stage::Release) camera=v.camera_from.lerp(camera,smooth(0,1.4,v.time));const auto extent=(bounds.position-camera).abs().max((bounds.get_end()-camera).abs());auto size=r.state.control.logical_size;if (size.x<=0 || size.y<=0) size={1280,720};zoom=std::min(zoom,std::min(size.x*0.44/std::max(1.0,double(extent.x)),size.y*0.36/std::max(1.0,double(extent.y))));v.assembly_camera=camera;v.assembly_zoom=zoom;
    } else if (v.stage==Stage::Pose) {const double f=smooth(0,1.2,v.time);camera=v.assembly_camera.lerp(v.center,f);zoom=v.assembly_zoom+(zoom-v.assembly_zoom)*f;}
    else if (v.stage==Stage::Strikes) zoom=v.zoom*(0.82+(1.15-0.82)*std::clamp(v.time/(p.finish_passes*p.finish_pass_time),0.0,1.0));
    else if (v.stage>=Stage::Last) zoom=v.zoom*0.52;
    DracoCinematic::frame(r,camera,zoom);
}
}
bool DracoFinale::begin(RunRuntime &r,BossBodyState &b) {
    if (!rule(r,b)) return false;if (b.draco.finale.active) dispose(r,b);const auto original_ship=r.state.ship_pos,original_velocity=r.state.ship.vel;
    DracoIntro::end(r,b,true);for (uint32_t row=0;row<r.state.bosses.techniques.size();++row) if (same_handle(r.state.bosses.techniques[row].actor,b.actor)) TechniqueRunner::cancel(r,r.state.bosses.handles.at(row));DracoCycle::cancel(r,b);DracoPicaro::pause(r,b,true);for (auto &f:r.state.bosses.flows) if (same_handle(f.actor,b.actor)) {FlowRunner::cancel(r,f);f.suspended=true;}
    auto &v=b.draco.finale;v={};DracoCinematic::capture(r,v.saved);const auto &p=DracoBody::rule(r,b);auto &e=r.state.enemies[b.actor.slot];v.modules_before=r.state.control.final_modules;v.finish_before=r.state.control.draco_finish_done;r.state.control.final_modules.clear();r.state.control.draco_finish_done=false;v.original_ship=original_ship;v.original_velocity=original_velocity;v.original_pos=e.pos;v.original_angle=e.facing;v.original_guard=e.guard;v.pose_from=DracoPose::points(r,b);v.camera_from=r.state.view_center;v.zoom=std::max(0.1,r.state.control.camera_zoom);v.assembly_camera=v.camera_from;v.assembly_zoom=v.zoom;v.center=e.pos-godot::Vector2::from_angle(e.facing)*p.body_length*0.32;v.radius=std::max(b.draco.width*2,p.body_length/(TAU*0.76));v.core=v.core_from=e.pos-godot::Vector2::from_angle(e.facing)*110*b.draco.head_scale*b.draco.depth;
    for (uint32_t j=0;j<=p.body_segments;++j) {const double t=double(j)/p.body_segments,angle=-PI*0.25+t*TAU*0.76,radius=v.radius*(0.94+std::sin(t*PI)*0.06);v.pose.push_back(v.center+godot::Vector2::from_angle(angle)*radius);}
    v.stage=Stage::Release;v.active=true;b.mode=BossMode::Final;e.hp=1;e.guard=1;e.vel={};auto &s=r.state;s.controls_locked=s.encounter_protected=true;s.control.cinematic_bars=1;s.control.cinematic_camera=s.control.cinematic_hide_enemies=true;s.draw.drawing=s.draw.tracing=false;s.ship.vel={};s.control.world_scale=0;cue(r,"core_released",v.core,100);return true;
}
bool DracoFinale::tick(RunRuntime &r,double dt,const InputFrame &input,godot::Vector2 size) {
    auto found=std::find_if(r.state.bosses.bodies.begin(),r.state.bosses.bodies.end(),[](const auto &b){return b.draco.finale.active;});if (found==r.state.bosses.bodies.end()) return false;auto &b=*found;auto &v=b.draco.finale;const auto *p=rule(r,b);if (!p || !r.state.enemy_handles.contains(b.actor)) {dispose(r,b);return true;}auto &s=r.state;s.control.logical_size=size;v.time+=dt;b.clock+=dt;DracoRifts::tick_closing(r,b,dt);s.control.world_scale=0;v.trails.erase(std::remove_if(v.trails.begin(),v.trails.end(),[&](const auto &t){return b.clock-t.time>=0.5;}),v.trails.end());
    switch(v.stage) {
    case Stage::Release:v.core=v.core_from.lerp(v.center+godot::Vector2(-60,-250),smooth(0,1.8,v.time));if (v.time>=2) {cue(r,"bear_roar",v.core,180);next(v,Stage::Combine);}break;
    case Stage::Combine:v.combine=smooth(0,1.8,v.time);if (v.time>=2) {s.control.final_modules={"legendary_stern","legendary_keel","legendary_sail","legendary_compass"};next(v,Stage::Pose);}break;
    case Stage::Pose: {const double f=smooth(0,1.2,v.time);std::vector<godot::Vector2> points;for (size_t j=0;j<v.pose.size();++j) {const size_t index=std::min(v.pose_from.size()-1,size_t(std::llround(double(j)*(v.pose_from.size()-1)/(v.pose.size()-1))));points.push_back(v.pose_from[index].lerp(v.pose[j],f));}b.draco.override_points=points;s.enemies[b.actor.slot].pos=points[0];s.enemies[b.actor.slot].facing=(points[0]-points[1]).angle();if (v.time>=1.2) {next(v,Stage::Input);s.controls_locked=false;s.control.cinematic_bars=0;for (uint32_t j=0;j<=64;++j) v.guide.push_back(v.center+godot::Vector2::from_angle(j*TAU/64)*(v.radius+b.draco.width*0.8));}break;}
    case Stage::Input:if ((input.press || input.alt_press || input.finale_pressed) && !v.began) {v.began=true;v.strokes.push_back(input.finale_pen);}if (v.began && input.has_cursor && (v.strokes.empty() || v.strokes.back().distance_to(input.finale_pen)>3)) v.strokes.push_back(input.finale_pen);if (v.began && (input.pen_release || input.finale_released)) {next(v,Stage::Strikes);s.controls_locked=true;s.draw.drawing=false;}else s.draw.drawing=v.began;break;
    case Stage::Strikes: {const uint32_t index=std::min(p->finish_passes-1,uint32_t(v.time/p->finish_pass_time));const double progress=std::fmod(v.time,p->finish_pass_time)/p->finish_pass_time;const auto direction=godot::Vector2::from_angle(index*2.399963);v.line={v.center-direction*(v.radius+340),v.center+direction*(v.radius+340)};s.ship_pos=s.ship.pos=v.line[0].lerp(v.line[1],std::clamp(progress*1.4,0.0,1.0));s.ship.heading=direction;if (int32_t(index)!=v.last_strike) {v.last_strike=index;v.trails.push_back({v.line,b.clock});cue(r,"finish_strike",v.center,v.radius*0.7);}if (v.time>=p->finish_passes*p->finish_pass_time) next(v,Stage::Last);break;}
    case Stage::Last:v.line={v.center+godot::Vector2(0,v.radius+750),v.center-godot::Vector2(0,v.radius+750)};s.ship_pos=s.ship.pos=v.line[0].lerp(v.line[1],smooth(0,0.3,v.time));s.ship.heading={0,-1};v.dim=0.95*smooth(0.03,0.16,v.time);if(v.time>=0.4) next(v,Stage::Sight);break;
    case Stage::Sight:v.dim=0.95*(1-smooth(0,1.6,v.time));if(v.time>=1.6) next(v,Stage::Split);break;
    case Stage::Split:v.split=smooth(0,0.5,v.time);if(v.time>=0.65) {next(v,Stage::Explode);cue(r,"cosmic_collapse",v.center,v.radius+b.draco.width);}break;
    case Stage::Explode:if(v.time>=1.1) {v.completed=true;s.control.draco_finish_done=true;v.active=false;dispose(r,b);DeathContext death;death.target=b.actor;death.corpse.id=s.enemies[b.actor.slot].id;death.corpse.pos=s.enemies[b.actor.slot].pos;death.request.cause=Cause::DracoFinale;PhaseController::defeated(r,death);return true;}break;
    default:break;
    }
    frame(r,b,*p);DracoBody::update(r,b);return true;
}
void DracoFinale::dispose(RunRuntime &r,BossBodyState &b) {
    auto &v=b.draco.finale;if (!v.saved.saved) return;DracoCinematic::restore(r,v.saved);if (!v.completed) {r.state.control.final_modules=v.modules_before;r.state.control.draco_finish_done=v.finish_before;r.state.ship_pos=r.state.ship.pos=v.original_ship;r.state.ship.vel=v.original_velocity;DracoPose::reset(r,b);if(r.state.enemy_handles.contains(b.actor)) {auto &e=r.state.enemies[b.actor.slot];e.pos=v.original_pos;e.facing=v.original_angle;e.guard=v.original_guard;b.mode=BossMode::Idle;DracoBody::update(r,b);}v.stage=Stage::None;}v.active=false;
}
bool DracoFinale::validate(const BossBodyState &b) {const auto &v=b.draco.finale;for(double x:{v.time,v.zoom,v.assembly_zoom,v.dim,v.split,v.radius,v.combine,v.original_angle,v.original_guard}) if(!std::isfinite(x))return false;if(v.time<0 || v.zoom<=0 || v.assembly_zoom<=0 || v.stage>Stage::Explode || (v.active && (!v.saved.saved || v.completed || b.mode!=BossMode::Final || v.pose_from.size()<2 || v.pose.size()<2)))return false;for(auto q:{v.center,v.core,v.core_from,v.camera_from,v.assembly_camera,v.original_pos,v.original_ship,v.original_velocity})if(!q.is_finite())return false;for(const auto *points:{&v.guide,&v.strokes,&v.line,&v.pose_from,&v.pose})for(auto q:*points)if(!q.is_finite())return false;for(const auto &t:v.trails){if(!std::isfinite(t.time))return false;for(auto q:t.points)if(!q.is_finite())return false;}return true;}
void DracoFinale::snapshot(const BossBodyState &b,godot::Dictionary &out) {const auto &v=b.draco.finale;godot::Dictionary x;const char *names[]={"","release","combine","pose","input","strikes","last","sight","split","explode"};x["stage"]=names[uint8_t(v.stage)];x["active"]=v.active;x["completed"]=v.completed;x["began"]=v.began;x["time"]=v.time;x["center"]=v.center;x["core"]=v.core;x["dim"]=v.dim;x["split"]=v.split;x["pose_radius"]=v.radius;x["combine_progress"]=v.combine;for(const auto &pair:{std::make_pair("guide",&v.guide),std::make_pair("strokes",&v.strokes),std::make_pair("line",&v.line)}) {godot::PackedVector2Array a;for(auto q:*pair.second)a.push_back(q);x[pair.first]=a;}godot::Array trails;for(const auto &t:v.trails) {godot::Dictionary item;godot::PackedVector2Array points;for(auto q:t.points)points.push_back(q);item["points"]=points;item["time"]=t.time;trails.push_back(item);}x["strike_trails"]=trails;out["finale"]=x;}
}
