#include "field.h"
#include "collision_query.h"
#include "../output/frame_builder.h"
#include <cmath>
#include <limits>
namespace speed {
void FieldSystem::initialize(RunRuntime &run) {
    auto &field=run.state.field;field={};field.ready=true;
    for (uint32_t i=0;i<run.content->field_bodies.size();++i) {
        const auto &body=run.content->field_bodies[i];field.bodies.push_back({i,godot::Vector2(body.x,body.y)});
    }
}
std::optional<BodyHit> FieldSystem::first_body_hit(const RunRuntime &run,godot::Vector2 from,godot::Vector2 to,double radius) {
    std::optional<BodyHit> result;
    for (uint32_t i=0;i<run.state.field.bodies.size();++i) {
        const auto &body=run.state.field.bodies[i];const auto &definition=run.content->field_bodies[body.definition];
        const double t=CollisionQuery::segment_circle_t(from,to,body.position,definition.radius+radius);
        if (t>=0 && (!result || t<result->t)) result=BodyHit{i,t,from.lerp(to,t)};
    }
    return result;
}
double FieldSystem::body_gap(const RunRuntime &run,godot::Vector2 point,double radius) {
    double gap=std::numeric_limits<double>::infinity();
    for (const auto &body:run.state.field.bodies) gap=std::min(gap,double(point.distance_to(body.position))-run.content->field_bodies[body.definition].radius-radius);
    return gap;
}
godot::Vector2 FieldSystem::push_out(const RunRuntime &run,godot::Vector2 point,double margin) {
    for (const auto &body:run.state.field.bodies) {
        const auto delta=point-body.position;const double distance=delta.length(),minimum=run.content->field_bodies[body.definition].radius+margin;
        if (distance<minimum) point=body.position+(distance>0.001?delta/distance:godot::Vector2(1,0))*minimum;
    }
    return point;
}
godot::Vector2 FieldSystem::boundary_accel(const RunRuntime &run,godot::Vector2 point) {
    const auto &c=run.state.ship_config;const double radius=point.length();
    return radius<=c.field_radius?godot::Vector2():-point/radius*(c.boundary_push+(radius-c.field_radius)*4.0);
}
void FieldSystem::collide_ship(RunRuntime &run) {
    auto &ship=run.state.ship;const auto &c=run.state.ship_config;
    // 機体の天体接触は現行どおり移動後の重なりを解消する。線分の問い合わせとは別にする。
    for (const auto &body:run.state.field.bodies) {
        const auto delta=ship.pos-body.position;const double distance=delta.length(),minimum=run.content->field_bodies[body.definition].radius+c.ship_radius;
        if (distance>=minimum || distance==0) continue;
        const auto normal=delta/distance;ship.pos=body.position+normal*minimum;const double vn=ship.vel.dot(normal);
        if (vn<0) {
            ship.glide=false;ship.vel-=normal*vn*(1.0+c.crash_restitution);
            godot::Dictionary event;event["pos"]=ship.pos;event["power"]=-vn;FrameBuilder::append(run,"crash",event);
        }
    }
    const double radius=ship.pos.length(),wall=c.field_radius+500.0;
    if (radius>wall) {
        ship.glide=false;const auto normal=ship.pos/radius;ship.pos=normal*wall;const double vn=ship.vel.dot(normal);
        if (vn>0) ship.vel-=normal*2.0*vn;
    }
}
bool FieldSystem::validate(const RunRuntime &run) {
    for (const auto &body:run.state.field.bodies) if (body.definition>=run.content->field_bodies.size() || !body.position.is_finite()) return false;
    return true;
}
}
