#include "spiral.h"
#include "body.h"
#include "pose.h"
#include "picaro.h"
#include "cinematic.h"
#include "screen_staging.h"
#include "../../systems/field.h"
#include "../flow/phase_controller.h"
#include "../../systems/attacks/wall.h"
#include "../../systems/attack_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "tail_motion.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double PI=3.141592653589793,TAU=PI*2,WIDEN=1.3;
const DracoSpiralDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->draco_spirals.begin(),r.content->draco_spirals.end(),[&](const auto &p){return p.technique==t.definition;});}
double taper(double x) {return 1-0.77*std::pow(std::clamp((x-0.55)/0.45,0.0,1.0),1.35);}
void head(RunRuntime &r,TechniqueState &t,godot::Vector2 at,double length) {auto &s=std::get<DracoSpiralState>(t.detail.get<DracoTechniqueState>().move);auto &b=*PhaseController::find(r,t.actor);DracoPose::follow(s.trail,s.points,at,length,DracoBody::rule(r,b).body_segments+1);auto &e=r.state.enemies[t.actor.slot];e.pos=s.points[0];e.facing=(s.points[0]-s.points[1]).angle();b.draco->override_points=s.points;}
void camera(RunRuntime &r,const DracoSpiralState &s,double dt) {DracoCinematic::frame(r,r.state.view_center.lerp(r.state.ship_pos,1-std::exp(-5*dt)),r.state.control.camera_zoom+(s.zoom-r.state.control.camera_zoom)*(1-std::exp(-3*dt)));}
godot::Vector2 follow(RunRuntime &r,TechniqueState &t,double dt) {auto &s=std::get<DracoSpiralState>(t.detail.get<DracoTechniqueState>().move);const auto &e=r.state.enemies[t.actor.slot];if (TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) return {};const auto delta=(r.state.ship_pos-s.center)*(1-std::exp(-1.4*dt));const auto shift=delta.limit_length(350*dt);s.center+=shift;return shift;}
// 折れた所をならす：前後の点を隣の点の真ん中へ少しずつ寄せる。
void round_kink(std::vector<godot::Vector2> &points,int at,int span,int passes) {const int from=std::max(1,at-span),to=std::min(int(points.size())-2,at+span);for (int k=0;k<passes;++k) for (int j=from;j<=to;++j) {const double w=0.5*(1-double(std::abs(j-at))/(span+1));points[j]=points[j].lerp(points[j-1].lerp(points[j+1],0.5),w);}}
godot::Vector2 path_at(const std::vector<godot::Vector2> &path,double distance) {for (size_t j=1;j<path.size();++j) {const double span=path[j-1].distance_to(path[j]);if (distance<=span) return path[j-1].lerp(path[j],span>0?distance/span:0);distance-=span;}return path.back();}
// 頭が真下へ抜け、残りの胴は紐を結ぶように、引かれた分だけ渦ごと中心へ締まっていく。
void pull(RunRuntime &r,TechniqueState &t,double pulled) {auto &s=std::get<DracoSpiralState>(t.detail.get<DracoTechniqueState>().move);auto &b=*PhaseController::find(r,t.actor);const size_t last=s.points.size()-1;double total=0;for (size_t j=1;j<s.coiled.size();++j) total+=s.coiled[j-1].distance_to(s.coiled[j]);const double tight=DracoTailMotion::smooth(0,s.length*0.7,pulled);for (size_t j=0;j<=last;++j) {const double along=double(j)/last*s.length;if (along<=pulled) {s.points[j]=s.pull_from+godot::Vector2(0,pulled-along);continue;}const double rest=along-pulled,k=1+(-0.8*tight)*DracoTailMotion::smooth(0,260,rest);s.points[j]=s.center+(path_at(s.coiled,std::min(total,rest))-s.center)*k;}round_kink(s.points,int(std::round(pulled/s.length*last)),6,14);s.trail=s.points;auto &e=r.state.enemies[t.actor.slot];e.pos=s.points[0];e.facing=(s.points[0]-s.points[1]).angle();b.draco->override_points=s.points;}
void release(RunRuntime &r,DracoSpiralState &s) {if (!s.holding) return;s.holding=false;r.state.controls_locked=s.controls_before;r.state.encounter_protected=s.protection_before;r.state.ship.invuln=std::max(r.state.ship.invuln,0.35);}
}
void DracoSpiral::begin(RunRuntime &r,TechniqueState &t) {
    auto &v=t.detail.get<DracoTechniqueState>();v.move=DracoSpiralState{};auto &s=std::get<DracoSpiralState>(v.move);auto &b=*PhaseController::find(r,t.actor);const auto &p=rule(r,t);const auto &bp=DracoBody::rule(r,b);auto &e=r.state.enemies[t.actor.slot];
    s.center=DracoTechnique::predict(r,t.actor,0,bp.aim_lead_cap);s.camera_before=r.state.control.cinematic_camera;s.zoom=r.state.control.camera_zoom*0.82;const auto half=r.state.view_half/0.82;const double factor=std::clamp(p.radius_factor,0.5,1.5),broad=std::max(half.x,half.y)*factor,clearance=e.radius+b.draco->width*0.5+r.state.ship_config.ship_radius*2+40;
    s.extent=s.horizontal=std::max({b.draco->width*4,broad,b.draco->width*3+clearance})*WIDEN;s.length=p.spiral_length;const double smallest=std::min(1.0,clearance/s.extent),largest=std::max(smallest,1-b.draco->width*3/s.extent);s.inner=std::clamp(p.inner_radius_factor/factor,smallest,largest);
    const double active=std::max(0.5,r.content->boss_techniques[t.definition-1].active);s.shrink=std::clamp(p.shrink_time,0.3,std::max(0.3,active*0.5));s.coil=std::clamp(p.coil_time,0.5,std::min(3.0,std::max(0.5,active-s.shrink-0.8)));s.pause=std::clamp(p.pause,0.8,std::min(3.0,std::max(0.8,active-s.shrink-s.coil-0.15)));s.first=s.coil*0.35;s.second=s.coil*0.45;s.bend=s.coil*0.2;const double gap=e.radius+r.state.ship_config.ship_radius+60;s.offset=std::clamp(p.head_offset,gap,std::max(gap,s.extent*(1+s.inner)*0.5*0.8));s.bend_radius=std::max(40.0,s.extent*s.inner*0.35);
    s.controls_before=r.state.controls_locked;s.protection_before=r.state.encounter_protected;r.state.control.cinematic_camera=true;s.entry=DracoPose::samples(DracoPose::points(r,b),bp.body_segments+1);s.departure_angle=(s.entry[0]-s.entry[1]).angle();e.facing=s.departure_angle;s.trail=s.points=s.entry;DracoPicaro::pause(r,b,true);b.draco->override_points=s.points;v.warning_width=b.draco->width*0.5;
}
void DracoSpiral::windup(RunRuntime &r,TechniqueState &t,double dt) {
    auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoSpiralState>(v.move);auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];const auto &bp=DracoBody::rule(r,b);const auto &p=r.content->boss_techniques[t.definition-1];camera(r,s,dt);
    if (s.departing) {s.departure_time+=dt;const double angle=s.departure_angle+angle_difference(-PI*0.5-s.departure_angle)*DracoTechnique::smooth(s.departure_time/0.55),speed=std::max((bp.body_length+r.state.view_half.y*2+b.draco->width*2)/std::clamp(rule(r,t).exit_duration,0.6,3.0),std::max(0.0,-double(r.state.ship.vel.y))+1100);head(r,t,e.pos+godot::Vector2::from_angle(angle)*speed*dt,bp.body_length);
        bool outside=true;for (size_t j=0;j<s.points.size();++j) {const double radius=j==0?e.radius:b.draco->width*0.5*taper(double(j)/(s.points.size()-1));const auto relative=s.points[j]-r.state.view_center;if (std::abs(relative.x)<=r.state.view_half.x+radius && std::abs(relative.y)<=r.state.view_half.y+radius) {outside=false;break;}}
        if (!outside) {v.stage_time=t.elapsed=std::min(v.stage_time,p.warn-1.01);return;}s.departing=false;s.center=r.state.ship_pos;const double margin=e.radius+b.draco->width+100;s.outside={float(std::max(s.center.x+s.horizontal+margin,double(r.state.view_center.x+r.state.view_half.x)+margin)),float(std::min(s.center.y-s.extent-margin,double(r.state.view_center.y-r.state.view_half.y)-margin))};s.control=s.center+godot::Vector2(s.horizontal*0.52,-s.extent);s.inside=s.center+godot::Vector2(0,-s.extent);s.trail.clear();for (uint32_t j=0;j<=bp.body_segments;++j) s.trail.push_back(s.outside+godot::Vector2(1,0)*s.length*double(j)/double(bp.body_segments));s.points=s.trail;e.pos=s.points[0];e.facing=PI;b.draco->override_points=s.points;v.stage_time=t.elapsed=p.warn-1;return;
    }
    const auto shift=follow(r,t,dt);s.outside+=shift;s.control+=shift;s.inside+=shift;for (auto &q:s.trail) q+=shift;const double progress=std::clamp(v.stage_time-(p.warn-1),0.0,1.0);head(r,t,s.outside.lerp(s.control,progress).lerp(s.control.lerp(s.inside,progress),progress),s.length);
}
void DracoSpiral::active(RunRuntime &r,TechniqueState &t,double dt) {
    auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoSpiralState>(v.move);auto &b=*PhaseController::find(r,t.actor);const auto &p=r.content->boss_techniques[t.definition-1];const auto &d=rule(r,t);const double at=v.stage_time,shrink_at=s.coil+s.pause;
    if (at<s.coil) {if (!s.holding) {s.held_ship=r.state.ship_pos;s.holding=true;r.state.controls_locked=r.state.encounter_protected=true;}r.state.ship_pos=r.state.ship.pos=s.held_ship;r.state.ship.vel={};}else release(r,s);
    if (at>=s.coil && !s.charging) {s.charging=true;t.locked=true;godot::Dictionary event;event["pos"]=s.center;event["radius"]=std::min(s.horizontal,s.extent)*0.8;FrameBuilder::append(r,"draco_roar",event);}
    if (!t.locked && !s.holding) {const auto shift=follow(r,t,dt);for (auto *points:{&s.trail,&s.entry}) for (auto &q:*points) q+=shift;}
    camera(r,s,dt);v.warning_paths.clear();if (at>=s.coil && at<shrink_at) {const auto at=r.state.enemies[t.actor.slot].pos;v.warning_paths.push_back({at,at+godot::Vector2(0,1)*s.extent*2.0});}
    const double shrink=std::clamp((at-shrink_at)/s.shrink,0.0,1.0);
    if (at<shrink_at) {
        double turns=std::clamp(at<s.first?at/s.first:1+(at-s.first)/s.second,0.0,2.0);turns=std::clamp(turns+0.035*std::sin(turns*TAU*2.5)*std::sin(turns*PI*0.5),0.0,2.0); // 押し出すような速さの緩急
        const double angle=-PI*0.5-turns*TAU,radius=s.extent+(s.extent*s.inner-s.extent)*turns*0.5,bend=std::clamp((at-s.first-s.second)/s.bend,0.0,1.0)*PI*0.5;
        // 自機の真上で曲げて頭を真下へ向ける。曲げた分は最後の4分の1周で寄せ、真下への直進が中心を通るようにする。
        head(r,t,s.center+godot::Vector2(std::cos(angle),std::sin(angle))*radius+godot::Vector2(-s.bend_radius*std::sin(bend)+s.bend_radius*DracoTailMotion::smooth(1.75,2,turns),s.bend_radius*(1-std::cos(bend))),s.length);
        if (at>s.first+s.second) {round_kink(s.points,4,4,10);const double w=DracoTechnique::smooth(bend/(PI*0.5)),segment=s.length/(s.points.size()-1);for (int j=1;j<=3;++j) s.points[j]=s.points[j].lerp(s.points[0]-godot::Vector2(0,segment*j),w*(1-(j-1)/3.0));auto &e=r.state.enemies[t.actor.slot];e.facing+=angle_difference(PI*0.5-e.facing)*w;b.draco->override_points=s.points;}
    } else {if (s.coiled.empty()) {s.coiled=s.points;s.pull_from=s.points[0];}pull(r,t,(at-shrink_at)*(s.extent*2+s.length)/s.shrink);}
    std::vector<float> fractions{0};double total=0;for (size_t j=1;j<s.points.size();++j) {total+=s.points[j-1].distance_to(s.points[j]);fractions.push_back(total);}if (total>0.001) for (auto &q:fractions) q/=total;
    bool touching=false;for (size_t j=0;j+1<s.points.size();++j) {const auto delta=s.points[j+1]-s.points[j];const double f=delta.length_squared()>0?std::clamp(double((r.state.ship_pos-s.points[j]).dot(delta))/delta.length_squared(),0.0,1.0):0;if (r.state.ship_pos.distance_to(s.points[j]+delta*f)<=b.draco->width*0.5*taper((fractions[j]+fractions[j+1])*0.5)+r.state.ship_config.ship_radius) {touching=true;break;}}
    if (at<shrink_at && touching && s.hp_sampled && r.state.ship.hp<s.hp_before) r.state.ship.invuln=std::max(r.state.ship.invuln,d.touch_invuln);s.hp_before=r.state.ship.hp;s.hp_sampled=true;
    if (at>=shrink_at && !s.trapped_hit && DracoTechnique::observe_contact(r,t,touching)) {s.trapped=s.trapped_hit=true;ShipDamageRequest hit;hit.observation_id=t.observation_id;hit.amount=p.damage;hit.scale=DamageScale::AtkScale;hit.cause=Cause::Spiral;hit.source=r.state.enemies[t.actor.slot].definition+1;hit.technique=t.definition;CombatResolver::ship_damage(r,hit);r.state.ship.invuln=std::max(r.state.ship.invuln,s.shrink*(1-shrink)+1);}
    const auto ticket=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));while (s.walls.size()+1<s.points.size()) {WallParams w;w.position=s.center;w.length=1;w.half_width=b.draco->width*0.5;w.active=p.active+2;w.damage=at>=shrink_at?0:p.damage*r.state.combat_config.atk_scale;w.color=godot::Color::html("7560d9");w.style=WallStyle::Trail;w.blocking=w.attached=true;w.owner=t.actor;w.technique=ticket;s.walls.push_back(WallSystem::emit(r,w));}
    for (size_t j=0;j<s.walls.size();++j) {const auto delta=s.points[j+1]-s.points[j];WallSystem::move(r,s.walls[j],s.points[j],delta.angle(),delta.length());const auto *a=AttackSystem::get(r.state,s.walls[j]);if (!a || a->pool!=AttackPool::Hazard) continue;auto &h=r.state.hazards[a->row];std::get<WallHazard>(h.shape).half_width=b.draco->width*0.5*taper((fractions[j]+fractions[j+1])*0.5);if (at>=shrink_at) h.damage=0;}
}
void DracoSpiral::end(RunRuntime &r,TechniqueState &t,bool cancelled) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoSpiralState>(v.move);release(r,s);r.state.control.cinematic_camera=s.camera_before;if (auto *b=PhaseController::find(r,t.actor)) DracoPicaro::pause(r,*b,false);for (auto h:s.walls) AttackSystem::end(r.state,h,cancelled?AttackEndReason::TechniqueCancel:AttackEndReason::TechniqueEnd);s.recovery=r.state.enemies[t.actor.slot].pos;v.warning_paths.clear();}
bool DracoSpiral::recover(RunRuntime &r,TechniqueState &t,double dt) {
    auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoSpiralState>(v.move);
    auto &b=*PhaseController::find(r,t.actor);auto &e=r.state.enemies[t.actor.slot];auto &entry=s.return_staging;
    if (entry.points.empty()) {
        // Keep the authored downward departure until the entire spiral has left the view.
        if (s.coiled.empty()) {s.coiled=s.points;s.pull_from=s.points[0];}pull(r,t,(r.content->boss_techniques[t.definition-1].active-s.coil-s.pause+v.stage_time)*(s.extent*2+s.length)/s.shrink);
        e.facing=PI*0.5;
        for (size_t j=0;j<s.points.size();++j) {
            const double radius=j==0?e.radius:b.draco->width*0.5*taper(double(j)/(s.points.size()-1));
            const auto relative=s.points[j]-r.state.view_center;
            if (std::abs(relative.x)<=r.state.view_half.x+radius && std::abs(relative.y)<=r.state.view_half.y+radius) return false;
        }
        DracoScreenStaging::begin(r,t,entry,true);
        entry.side=r.state.ship_pos.x>0?-1:1;
    }
    const auto phase=entry.phase;
    const bool ready=DracoScreenStaging::advance(r,t,entry,dt);
    if (phase==0 && entry.phase==1) {
        // Only the return destination is constrained; the exit and entry remain offscreen.
        const double margin=e.radius+40,limit=std::max(margin,r.state.ship_config.field_radius-margin);
        entry.entry_to=(r.state.ship_pos+godot::Vector2(entry.side*std::min(500.0,double(r.state.view_half.x)*0.68),0)).limit_length(limit);
        for (int j=0;j<4;++j) entry.entry_to=FieldSystem::push_out(r,entry.entry_to,margin).limit_length(limit);
    }
    return ready;
}
bool DracoSpiral::validate(const DracoSpiralState &s) {for (double q:{s.extent,s.horizontal,s.length,s.inner,s.coil,s.pause,s.first,s.second,s.bend,s.shrink,s.offset,s.bend_radius,s.zoom,s.departure_time,s.departure_angle,s.hp_before}) if (!std::isfinite(q)) return false;if (s.extent<=0 || s.horizontal<=0 || s.length<0 || s.shrink<=0 || s.coil<=0 || s.pause<=0 || s.zoom<=0 || s.departure_time<0 || s.points.size()<2 || s.trail.size()<2) return false;for (auto q:{s.center,s.held_ship,s.outside,s.control,s.inside,s.recovery}) if (!q.is_finite()) return false;for (const auto *points:{&s.trail,&s.entry,&s.points}) for (auto q:*points) if (!q.is_finite()) return false;return s.return_staging.points.empty() || DracoScreenStaging::validate(s.return_staging);}
godot::Dictionary DracoSpiral::snapshot(const TechniqueState &t) {const auto &s=std::get<DracoSpiralState>(t.detail.get<DracoTechniqueState>().move);godot::Dictionary out;out["spiral_center"]=s.center;out["spiral_extent"]=s.extent;out["spiral_horizontal"]=s.horizontal;out["spiral_inner"]=s.inner;out["coil_time"]=s.coil;out["pause_time"]=s.pause;out["departing"]=s.departing;out["holding_player"]=s.holding;out["charging"]=s.charging;out["trapped_hit"]=s.trapped_hit;out["wall_count"]=int64_t(s.walls.size());out["return_stage"]=s.return_staging.points.empty()?-1:int(s.return_staging.phase);return out;}
}
