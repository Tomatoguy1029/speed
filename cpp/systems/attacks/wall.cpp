#include "wall.h"
#include "../attack_system.h"
#include "../field.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle WallSystem::emit(RunRuntime &run,const WallParams &p) {
    if (!run.state.started || run.state.closed || run.content->walls.empty() || p.style>=WallStyle::Count || !p.position.is_finite() ||
        (p.owner.generation && !run.state.enemy_handles.contains(p.owner)) || (p.attached && !p.owner.generation)) return {};
    for (double v:{p.length,p.half_width,p.delay,p.active,p.damage}) if (!std::isfinite(v) || v<0) return {};
    for (double v:{p.angle,p.length,p.half_width,p.delay,p.active}) if (!std::isfinite(float(v))) return {};
    for (float v:{p.color.r,p.color.g,p.color.b,p.color.a}) if (!std::isfinite(v)) return {};
    HazardState hazard;hazard.pos=p.position;hazard.delay=p.delay;hazard.duration=p.active;hazard.damage=p.damage;hazard.color=p.color;
    hazard.shape=WallHazard{float(p.angle),float(p.length),float(p.half_width),1,uint32_t(p.style),p.blocking};
    AttackSpec spec;spec.cause=Cause::Wall;spec.technique=p.technique;if (run.state.bosses.handles.contains(p.technique)) spec.source_technique=run.state.bosses.techniques[p.technique.slot].definition;spec.owner.live_source=p.owner;spec.owner.attached=p.attached;spec.owner.budget=p.budget;
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (p.attached) spec.policies|=policy(EndPolicy::CancelWithParticipant);
    if (!AttackSystem::configure_contact(*run.content,run.content->walls.front().contact,spec)) return {};
    return AttackSystem::emit_hazard(run.state,hazard,spec);
}
bool WallSystem::move(RunRuntime &run,AttackHandle handle,godot::Vector2 position,double angle,std::optional<double> length) {
    const auto *record=AttackSystem::get(run.state,handle);
    if (!record || record->pool!=AttackPool::Hazard || !position.is_finite() || !std::isfinite(float(angle)) ||
        (length && (!std::isfinite(float(*length)) || *length<0))) return false;
    auto &h=run.state.hazards[record->row];auto *wall=std::get_if<WallHazard>(&h.shape);if (!wall) return false;
    h.pos=position;wall->angle=angle;if (length) wall->length=*length;return true;
}
ContactShape WallSystem::geometry(const HazardState &h) {
    const auto &w=std::get<WallHazard>(h.shape);return SegmentCircle{h.pos,h.pos+godot::Vector2::from_angle(w.angle)*w.length,w.half_width};
}
namespace {
bool blocking(const RunRuntime &run,const HazardState &h) {
    const auto *w=std::get_if<WallHazard>(&h.shape);
    if (!h.alive || !w || !w->blocking || h.time<h.delay || h.time>double(h.delay)+h.duration) return false;
    const auto *record=AttackSystem::get(run.state,h.attack);if (!record) return false;
    const auto source=record->spec.owner.live_source;
    return !run.state.enemy_handles.contains(source) || !run.state.enemy_handles.contains(run.state.enemies[source.slot].pump_owner);
}
double sign(double v) {return (v>0)-(v<0);}
}
std::optional<WallHit> WallSystem::block_hit(const RunRuntime &run,godot::Vector2 from,godot::Vector2 to,double radius) {
    std::optional<WallHit> best;
    for (const auto &h:run.state.hazards) {
        if (!blocking(run,h)) continue;const auto &w=std::get<WallHazard>(h.shape);const auto u=godot::Vector2::from_angle(w.angle);
        const double m=w.half_width+radius,d0=u.cross(from-h.pos),d1=u.cross(to-h.pos);
        if (std::abs(d1)>=m && sign(d0)==sign(d1)) continue;
        const double t=std::abs(d0)>m && std::abs(d0-d1)>1e-6?(d0-sign(d0)*m)/(d0-d1):0;
        const double along=u.dot(from.lerp(to,t)-h.pos);
        if (along<-m || along>w.length+m || (best && t>=best->t)) continue;
        best=WallHit{t,from.lerp(to,t),godot::Vector2(-u.y,u.x)*(d0>=0?1.0:-1.0)};
    }return best;
}
bool WallSystem::bounce_ship(RunRuntime &run,godot::Vector2 from) {
    auto &ship=run.state.ship;const double radius=run.state.ship_config.ship_radius;std::optional<WallHit> hit;double least=INFINITY;
    for (const auto &h:run.state.hazards) {
        if (!blocking(run,h)) continue;const auto &w=std::get<WallHazard>(h.shape);const auto u=godot::Vector2::from_angle(w.angle);
        const double m=w.half_width+radius,d=u.cross(from-h.pos),along=u.dot(from-h.pos);
        if (std::abs(d)>=m-1.0 || along<-m || along>w.length+m) continue;
        double side=std::abs(d)>0.5?sign(d):sign(u.cross(ship.vel));if (side==0) side=1;
        const double push=m+1.0-side*d;if (push>=least) continue;least=push;
        const auto normal=godot::Vector2(-u.y,u.x)*side;hit=WallHit{0,from+normal*push,normal};
    }
    if (!hit) {hit=block_hit(run,from,ship.pos,radius);const auto arena=FieldSystem::arena_hit(run,from,ship.pos,radius);if (arena && (!hit || from.distance_squared_to(arena->position)<from.distance_squared_to(hit->point))) hit=WallHit{arena->t,arena->position,arena->normal};}if (!hit) return false;
    ship.pos=hit->point;const auto normal=hit->normal;const double vn=ship.vel.dot(normal);
    if (vn<0) ship.vel-=normal*2.0*vn;
    ship.vel*=run.state.combat_config.bounce_keep;
    if (ship.vel.length()<run.state.combat_config.bounce_min_speed) ship.vel=normal*run.state.combat_config.bounce_min_speed;
    ship.boost_t=0;ship.glide=false;run.state.ship_pos=ship.pos;
    godot::Dictionary event;event["pos"]=ship.pos-normal*radius;event["normal"]=normal;event["enemy_pos"]=ship.pos;event["r"]=radius;
    FrameBuilder::append(run,"block_impact",event);event.clear();event["pos"]=ship.pos;FrameBuilder::append(run,"bounce",event);return true;
}
void WallSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &h=run.state.hazards[row];const auto *w=std::get_if<WallHazard>(&h.shape);
    if (!h.alive || !w || w->style==uint32_t(WallStyle::Trail) || !view.grow(w->length).has_point(h.pos)) return;
    const auto *record=AttackSystem::get(run.state,h.attack);if (!record) return;
    const bool charging=h.time<h.delay;const double width=w->half_width*2.0,zoom=std::max(0.01,run.state.control.camera_zoom);
    const double k=std::clamp(double(h.time)/std::max(0.001,double(h.delay)),0.0,1.0),left=double(h.delay)+h.duration-h.time;
    Color col=w->style==uint32_t(WallStyle::Lightning)?Color::html("e1f7ff"):h.color;
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Polyline);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    PackedVector2Array points;PackedInt32Array offsets;PackedFloat32Array widths;PackedColorArray colors;offsets.push_back(0);
    const auto to=h.pos+Vector2::from_angle(w->angle)*w->length;
    const auto line=[&](double size,Color color) {points.push_back(h.pos);points.push_back(to);offsets.push_back(points.size());widths.push_back(size);colors.push_back(color);};
    if (charging) {col.a=0.15+0.35*k;line(std::max(2.0/zoom,width*0.25*k),col);}
    else if (w->style==uint32_t(WallStyle::Ray)) {
        const double f=std::clamp(left/0.3,0.0,1.0)*std::clamp(double(h.time-h.delay)/0.12,0.0,1.0),flick=0.85+0.15*std::sin(h.time*50.0+row);
        col.a=0.22*f;line(width*2.6*flick,col);col=h.color.lightened(0.2);col.a=0.9*f;line(width,col);line(std::max(2.0/zoom,width*0.35),Color(1,1,1,0.9*f));
        Dictionary glow=shape.duplicate();glow["kind"]=int32_t(RenderShapeKind::Circle);PackedVector2Array p;p.push_back(h.pos);PackedInt32Array o;o.push_back(0);o.push_back(1);PackedFloat32Array r;r.push_back(width*(0.9+0.2*flick));PackedColorArray c;c.push_back(Color(1,1,1,0.8*f));
        glow["points"]=p;glow["offsets"]=o;glow["widths"]=r;glow["colors"]=c;out.push_back(glow);
    } else {const double f=std::clamp(left/0.4,0.0,1.0);col.a=0.35*f;line(width*1.5,col);col.a=0.9*f;line(width,col);}
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;out.push_back(shape);
}
}
