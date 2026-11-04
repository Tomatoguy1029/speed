#include "pose.h"
#include "body.h"
#include "../../systems/collision_query.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double PI=3.141592653589793,TAU=PI*2;
double taper(double t) {return 1.0-0.77*std::pow(std::clamp((t-0.55)/0.45,0.0,1.0),1.35);}
double length(const std::vector<godot::Vector2> &v) {double n=0;for (size_t i=1;i<v.size();++i) n+=v[i-1].distance_to(v[i]);return n;}
std::vector<godot::Vector2> sample_spine(const std::vector<godot::Vector2> &v,uint32_t count,bool head=true) {std::vector<godot::Vector2> out;if (v.empty() || !count) return out;const double total=length(v);size_t at=0;double traversed=0;for (uint32_t j=0;j<count;++j) {const double target=total*(head?double(j)/std::max(1u,count-1):double(j+1)/count);while (at+2<v.size() && target>traversed+v[at].distance_to(v[at+1])) {traversed+=v[at].distance_to(v[at+1]);++at;}out.push_back(at+1<v.size()?v[at].lerp(v[at+1],(target-traversed)/std::max(0.001,double(v[at].distance_to(v[at+1])))):v.back());}return out;}
}
void DracoPose::follow(std::vector<godot::Vector2> &trail,std::vector<godot::Vector2> &points,godot::Vector2 head,double body_length,uint32_t count) {
    if (trail.size()<2) trail={head,head+godot::Vector2(-body_length,0)};
    const auto previous=trail.front();const double distance=previous.distance_to(head);
    if (distance<0.01 && trail.size()==count && std::abs(length(trail)-body_length)<body_length*0.02) {points=trail;return;}
    if (distance>0.01) {const uint32_t steps=std::max(1,int(std::ceil(distance/24.0)));for (uint32_t j=1;j<=steps;++j) trail.insert(trail.begin(),previous.lerp(head,double(j)/steps));}else trail.front()=head;
    std::vector<godot::Vector2> path{trail.front()};double remaining=body_length;
    for (size_t j=1;j<trail.size();++j) {const double span=path.back().distance_to(trail[j]);if (span<0.001) continue;if (span>=remaining) {path.push_back(path.back().lerp(trail[j],remaining/span));remaining=0;break;}path.push_back(trail[j]);remaining-=span;}
    if (remaining>0.001) {const auto direction=path.size()>1?(path.back()-path[path.size()-2]).normalized():godot::Vector2(-1,0);path.push_back(path.back()+direction*remaining);}
    trail=std::move(path);points=sample_spine(trail,count);
}
std::vector<godot::Vector2> DracoPose::samples(const std::vector<godot::Vector2> &v,uint32_t count) {return sample_spine(v,count);}
void DracoPose::update(RunRuntime &r,BossBodyState &b) {
    const auto &p=DracoBody::rule(r,b);auto &d=b.draco;const auto &head=r.state.enemies[b.actor.slot];
    if (d.trail.empty()) {d.trail.push_back(head.pos);for (uint32_t j=0;j<p.body_segments;++j) {const double t=double(j+1)/p.body_segments;const double wave=std::sin(t*TAU*1.25-b.clock*0.75)*p.body_wave*std::sin(t*PI*0.8);d.trail.push_back(head.pos+godot::Vector2(-t*p.body_length,wave).rotated(head.facing));}const double n=length(d.trail);if (n>0.001) for (auto &v:d.trail) v=head.pos+(v-head.pos)*(p.body_length/n);}
    if (d.override_points.empty()) {
        const auto previous=d.trail.front();const double distance=previous.distance_to(head.pos);const bool settled=distance<0.01 && d.trail.size()==p.body_segments+1 && std::abs(length(d.trail)-p.body_length)<p.body_length*0.02;if (!settled) {if (distance>0.01) {const uint32_t steps=std::max(1,int(std::ceil(distance/24.0)));for (uint32_t j=1;j<=steps;++j) d.trail.insert(d.trail.begin(),previous.lerp(head.pos,double(j)/steps));}else d.trail.front()=head.pos;
        std::vector<godot::Vector2> path{d.trail.front()};double remaining=p.body_length;for (size_t j=1;j<d.trail.size();++j) {const double span=path.back().distance_to(d.trail[j]);if (span<0.001) continue;if (span>=remaining) {path.push_back(path.back().lerp(d.trail[j],remaining/span));remaining=0;break;}path.push_back(d.trail[j]);remaining-=span;}if (remaining>0.001) {const auto direction=path.size()>1?(path.back()-path[path.size()-2]).normalized():godot::Vector2(-1,0);path.push_back(path.back()+direction*remaining);}d.trail=std::move(path);}d.pose=settled?d.trail:sample_spine(d.trail,p.body_segments+1);
    } else d.pose=d.override_points;
    auto points=d.pose;if (!godot::Math::is_equal_approx(d.depth,1.0)) for (auto &v:points) v=head.pos+(v-head.pos)*d.depth;
    const auto row_points=sample_spine(points,p.body_segments,false);r.state.enemies[b.actor.slot].radius=p.head_radius*d.head_scale*d.depth;
    for (size_t j=1;j<b.participants.size();++j) {const auto actor=b.participants[j].actor;if (!r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead) continue;auto &e=r.state.enemies[actor.slot];e.pos=row_points[j-1];e.guard=head.guard;e.radius=d.width*0.5*taper(double(j)/p.body_segments)*d.depth;}
}

std::vector<godot::Vector2> DracoPose::points(const RunRuntime &r,const BossBodyState &b) {auto out=b.draco.override_points.empty()?b.draco.pose:b.draco.override_points;const auto head=r.state.enemies[b.actor.slot].pos;if (!godot::Math::is_equal_approx(b.draco.depth,1.0)) for (auto &v:out) v=head+(v-head)*b.draco.depth;return out;}
void DracoPose::depth(RunRuntime &r,BossBodyState &b,double value,double alpha) {b.draco.depth=std::clamp(value,0.1,1.0);b.draco.alpha=std::clamp(alpha,0.0,1.0);update(r,b);}
void DracoPose::reset(RunRuntime &r,BossBodyState &b) {if (!r.state.enemy_handles.contains(b.actor)) return;auto &d=b.draco;if (r.state.enemy_handles.contains(b.actor) && std::abs(d.depth-1.0)<0.00001) d.trail=d.override_points.empty()?points(r,b):d.override_points;else d.trail.clear();d.override_points.clear();d.pose.clear();const auto &p=DracoBody::rule(r,b);d.width=p.body_width;d.head_scale=p.head_scale;d.depth=d.alpha=1;update(r,b);}
bool DracoPose::contains(const RunRuntime &r,const BossBodyState &b,godot::Vector2 point,double radius) {const auto &e=r.state.enemies[b.actor.slot];if (e.guard>=1 || e.dead) return false;if (point.distance_to(e.pos)<=e.radius+radius) return true;const auto spine=points(r,b);const double total=length(spine);double traversed=0;for (size_t j=1;j<spine.size();++j) {const auto delta=spine[j]-spine[j-1];const double span=delta.length();const double t=delta.length_squared()>0?std::clamp(double((point-spine[j-1]).dot(delta))/delta.length_squared(),0.0,1.0):0;const auto nearest=spine[j-1]+delta*t;const double fraction=total>0.001?(traversed+t*span)/total:0;const double width=b.draco.width*0.5*taper(fraction)*b.draco.depth;if (nearest.distance_to(point)<=width+radius) return true;traversed+=span;}return false;}
}
