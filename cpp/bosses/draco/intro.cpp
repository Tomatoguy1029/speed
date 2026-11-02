#include "intro.h"
#include "body.h"
#include "pose.h"
#include "cinematic.h"
#include "../../systems/field.h"
#include <algorithm>
#include <cmath>
#include <limits>
namespace speed {
namespace {
double smooth(double a,double b,double x) {x=std::clamp((x-a)/(b-a),0.0,1.0);return x*x*(3-2*x);}
godot::Vector2 safe_position(const RunRuntime &r,const BossBodyState &b,godot::Vector2 ship) {
    const auto &p=DracoBody::rule(r,b);const double margin=p.head_radius*b.draco.head_scale+40,limit=std::max(margin,r.state.ship_config.field_radius-margin);const auto desired=ship+godot::Vector2(0,-430);auto candidate=desired.limit_length(limit);
    for (int j=0;j<4;++j) candidate=FieldSystem::push_out(r,candidate,margin).limit_length(limit);
    const auto clear=[&](godot::Vector2 at){return at.length()<=limit+0.1 && FieldSystem::body_gap(r,at,margin)>=-0.1;};
    if (clear(candidate)) return candidate;auto best=candidate;double best_score=std::numeric_limits<double>::infinity();
    for (double distance:{430.0,650.0,900.0}) for (int j=0;j<24;++j) {auto point=(ship+godot::Vector2::from_angle(-1.5707963267948966+j*6.283185307179586/24)*distance).limit_length(limit);if (!clear(point)) continue;const double score=point.distance_squared_to(desired)+std::max(0.0,double(point.y-ship.y))*1000;if (score<best_score) {best=point;best_score=score;}}
    return best;
}
}
void DracoIntro::begin(RunRuntime &r,BossBodyState &b) {
    if (b.draco.intro.active) end(r,b,true);auto &s=r.state;auto &e=s.enemies[b.actor.slot];auto &v=b.draco.intro;DracoCinematic::capture(r,v.saved);v.origin=e.pos;v.facing=e.facing;v.guard=e.guard;v.mode=b.mode;v.ship=s.ship_pos;v.camera=s.view_center;v.zoom=std::max(0.1,s.control.camera_zoom);v.center=safe_position(r,b,v.ship);v.rift_center=v.center+godot::Vector2(0,-70);v.active=true;v.time=0;v.stage=0;v.rift=v.eyes=v.chest=v.emerged=0;DracoPose::reset(r,b);b.mode=BossMode::Entrance;e.pos=v.center+godot::Vector2(0,-120);e.facing=1.5707963267948966;e.guard=1;e.vel={};s.controls_locked=s.encounter_protected=true;s.control.cinematic_bars=1;s.control.cinematic_camera=s.control.cinematic_hide_enemies=true;s.ship.heading={0,-1};s.ship.vel={};s.draw.drawing=s.draw.tracing=false;
    for (uint32_t row=0;row<s.enemies.size();++row) {auto &member=s.enemies[row];if (member.alive && !member.dead && !member.is_boss) {v.held.push_back({s.enemy_handles.at(row),member.held});member.held=true;}}
    DracoBody::update(r,b);
}
bool DracoIntro::tick(RunRuntime &r,BossBodyState &b,double dt) {
    auto &v=b.draco.intro;if (!v.active) return false;v.time+=dt;const double quiet=DracoBody::rule(r,b).entrance_quiet,reveal=quiet+1.35,confront=reveal+2,handoff=confront+1.4,finish=handoff+0.8;
    v.emerged=smooth(reveal,confront,v.time);v.rift=smooth(quiet,quiet+1,v.time)*(1-smooth(confront,confront+0.7,v.time));v.eyes=smooth(quiet+0.55,reveal,v.time)*(1-smooth(confront,confront+0.5,v.time));v.chest=smooth(reveal+0.3,confront,v.time);v.stage=v.time<quiet?0:v.time<reveal?1:v.time<confront?2:v.time<handoff?3:4;auto &e=r.state.enemies[b.actor.slot];e.pos=v.center+godot::Vector2(0,-120)*(1-v.emerged);e.facing=1.5707963267948966;e.vel={};const auto filmed=v.ship.lerp(v.center,0.45);const double move=smooth(0,1.5,v.time),restore=smooth(handoff,finish,v.time);DracoCinematic::frame(r,v.camera.lerp(filmed,move).lerp(v.camera,restore),v.zoom*(1-0.15*move*(1-restore)));r.state.control.cinematic_bars=1-restore;DracoBody::update(r,b);if (v.time>=finish) end(r,b);return v.active;
}
void DracoIntro::end(RunRuntime &r,BossBodyState &b,bool interrupted) {
    auto &v=b.draco.intro;if (!v.active) return;v.active=false;v.stage=0;for (const auto &member:v.held) if (r.state.enemy_handles.contains(member.actor)) r.state.enemies[member.actor.slot].held=member.held;v.held.clear();DracoCinematic::restore(r,v.saved);DracoPose::reset(r,b);if (r.state.enemy_handles.contains(b.actor)) {auto &e=r.state.enemies[b.actor.slot];e.pos=interrupted?v.origin:v.center;e.facing=interrupted?v.facing:1.5707963267948966;e.guard=v.guard;e.vel={};}b.mode=interrupted?v.mode:BossMode::Idle;v.rift=v.eyes=v.chest=0;DracoBody::update(r,b);
}
bool DracoIntro::validate(const godot::RunState &,const BossBodyState &b) {
    const auto &v=b.draco.intro;for (double n:{v.time,v.rift,v.eyes,v.chest,v.emerged,v.zoom,v.facing,v.guard,v.saved.bars,v.saved.zoom,v.saved.world_scale}) if (!std::isfinite(n)) return false;for (auto p:{v.origin,v.ship,v.camera,v.center,v.rift_center,v.saved.center,v.saved.half,v.saved.heading}) if (!p.is_finite()) return false;return v.time>=0 && v.zoom>0 && v.stage<=4 && (!v.active || (v.saved.saved && b.mode==BossMode::Entrance));
}
void DracoIntro::snapshot(const BossBodyState &b,godot::Dictionary &p) {const auto &v=b.draco.intro;godot::Dictionary q;q["active"]=v.active;q["time"]=v.time;q["stage"]=int(v.stage);q["rift"]=v.rift;q["eyes"]=v.eyes;q["chest_glow"]=v.chest;q["emerged"]=v.emerged;q["center"]=v.center;q["rift_center"]=v.rift_center;p["intro"]=q;}
}
