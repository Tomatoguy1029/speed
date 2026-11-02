#include "collision_query.h"
#include "motion_math.h"
#include "../state/run_state.h"
#include <algorithm>
#include <cmath>
namespace speed {
std::vector<size_t> CollisionQuery::enemy_rows(const godot::RunState &state,Point lo,Point hi,bool include_dead) {
    std::vector<size_t> out;
    if (state.grid.cols == 0 || hi.x < state.grid.origin.x || hi.y < state.grid.origin.y ||
            lo.x > state.grid.origin.x + state.grid.cols * state.grid.cell || lo.y > state.grid.origin.y + state.grid.rows * state.grid.cell) return out;
    const int64_t x0 = std::clamp(int64_t((double(lo.x) - state.grid.origin.x) / state.grid.cell), int64_t(0), state.grid.cols - 1);
    const int64_t x1 = std::clamp(int64_t((double(hi.x) - state.grid.origin.x) / state.grid.cell), int64_t(0), state.grid.cols - 1);
    const int64_t y0 = std::clamp(int64_t((double(lo.y) - state.grid.origin.y) / state.grid.cell), int64_t(0), state.grid.rows - 1);
    const int64_t y1 = std::clamp(int64_t((double(hi.y) - state.grid.origin.y) / state.grid.cell), int64_t(0), state.grid.rows - 1);
    for (int64_t y = y0; y <= y1; ++y) for (int64_t x = x0; x <= x1; ++x) {
        int64_t row = state.grid.head[y * state.grid.cols + x];
        while (row != -1) {
            if (size_t(row) < state.enemies.size() && state.enemies[row].alive && (include_dead || !state.enemies[row].dead)) out.push_back(row);
            row = state.grid.next[row];
        }
    }
    return out;
}

double CollisionQuery::segment_circle_t(Point from,Point to,Point center,double radius) {
    const Point f=from-center,d=to-from;
    const double cc=double(f.length_squared())-radius*radius,a=d.length_squared();
    if (cc<=0) return 0;if (a==0) return -1;
    const double b=2.0*f.dot(d),disc=b*b-4.0*a*cc;
    if (disc<0) return -1;
    const double t=(-b-std::sqrt(disc))/(2.0*a);return t>=0 && t<=1?t:-1;
}
double CollisionQuery::point_segment_squared(Point point,Point from,Point to) {
    const Point delta=to-from;
    const double t=delta.length_squared()>0?std::clamp(double((point-from).dot(delta))/delta.length_squared(),0.0,1.0):0;
    return point.distance_squared_to(from+delta*t);
}
namespace {
bool crosses(Point a,Point b,Point c,Point d) {
    const Point r=b-a,s=d-c,q=c-a;const double den=r.cross(s);
    if (std::abs(den)<1e-7) return false;
    const double t=q.cross(s)/den,u=q.cross(r)/den;return t>=0 && t<=1 && u>=0 && u<=1;
}
bool inside_quad(Point point,Point a,Point b,Point c,Point d) {
    const Point points[]={a,b,c,d};bool inside=false;
    for (int i=0,j=3;i<4;j=i++) {
        if (CollisionQuery::point_segment_squared(point,points[i],points[j])==0) return true;
        if ((points[i].y>point.y)!=(points[j].y>point.y) && point.x<(points[j].x-points[i].x)*(point.y-points[i].y)/(points[j].y-points[i].y)+points[i].x) inside=!inside;
    }return inside;
}
bool swept_shape(const SweptSegment &shape,Point before,Point now,double radius) {
    const double reach=shape.half_width+radius;
    return CollisionQuery::sweep_segment(before,now,shape.from,shape.to,reach) ||
        CollisionQuery::sweep_segment(before,now,shape.before_from,shape.before_to,reach) ||
        CollisionQuery::sweep_segment(before,now,shape.before_from,shape.from,reach) ||
        CollisionQuery::sweep_segment(before,now,shape.before_to,shape.to,reach) ||
        inside_quad(now,shape.before_from,shape.before_to,shape.to,shape.from) ||
        inside_quad(before,shape.before_from,shape.before_to,shape.to,shape.from);
}
// 曲線と扇の境界で区間を分ける。区間内の真偽は変わらない。
template<class Predicate> bool radial_sweep(Point from,Point to,Point center,const std::vector<double> &radii,const std::vector<double> &angles,Predicate contains) {
    if (contains(from) || contains(to)) return true;
    std::vector<double> cuts{0,1};const Point f=from-center,d=to-from;
    const double a=d.length_squared(),b=2.0*f.dot(d);
    if (a==0) return false;
    for (double radius:radii) {
        const double c=double(f.length_squared())-radius*radius,disc=b*b-4.0*a*c;
        if (disc<0) continue;
        for (double sign:{-1.0,1.0}) {const double t=(-b+sign*std::sqrt(disc))/(2.0*a);if (t>=0 && t<=1) cuts.push_back(t);}
    }
    for (double angle:angles) {
        const Point ray=Point::from_angle(angle);const double den=d.cross(ray);
        if (std::abs(den)<1e-7) continue;
        const double t=-double(f.cross(ray))/den;
        if (t>=0 && t<=1 && (f+d*t).dot(ray)>=0) cuts.push_back(t);
    }
    std::sort(cuts.begin(),cuts.end());
    for (size_t i=0;i<cuts.size();++i) {
        if (contains(from+d*cuts[i])) return true;
        if (i && contains(from+d*((cuts[i-1]+cuts[i])*0.5))) return true;
    }return false;
}
}
bool CollisionQuery::sweep_segment(Point before,Point now,Point from,Point to,double radius) {
    const double squared=radius*radius;
    return crosses(before,now,from,to) || point_segment_squared(before,from,to)<=squared ||
        point_segment_squared(now,from,to)<=squared || point_segment_squared(from,before,now)<=squared || point_segment_squared(to,before,now)<=squared;
}
bool CollisionQuery::touches(const ContactShape &shape,const ShipMotion &ship,ContactGeometry policy) {
    const double radius=policy.add_ship_radius?ship.radius:0;
    const Point before=policy.ship_sweep?ship.before:ship.now,now=ship.now;
    return std::visit([&](const auto &value)->bool {
        using T=std::decay_t<decltype(value)>;
        if constexpr (std::is_same_v<T,PointCircle>) return segment_circle_t(before,now,value.center,value.radius+radius)>=0;
        else if constexpr (std::is_same_v<T,SegmentCircle>) return sweep_segment(before,now,value.from,value.to,value.half_width+radius);
        else if constexpr (std::is_same_v<T,SweptSegment>) return swept_shape(value,before,now,radius);
        else if constexpr (std::is_same_v<T,Polyline>) {
            for (size_t i=1;i<value.points.size();++i) {
                if (sweep_segment(before,now,value.points[i-1],value.points[i],value.half_width+radius)) return true;
                if (value.before.size()==value.points.size() && swept_shape({value.before[i-1],value.before[i],value.points[i-1],value.points[i],value.half_width},before,now,radius)) return true;
            }return false;
        } else if constexpr (std::is_same_v<T,Fan>) {
            const double outer=value.radius+radius;
            const auto contains=[&](Point p){const auto rel=p-value.center;return rel.length_squared()<=outer*outer && (rel.is_zero_approx() || std::abs(angle_difference(rel.angle()-value.angle))<=value.arc);};
            return radial_sweep(before,now,value.center,{outer},{value.angle-value.arc,value.angle+value.arc},contains);
        } else if constexpr (std::is_same_v<T,RingBand>) {
            const double inner=std::max(0.0,value.radius-value.half_width-radius),outer=value.radius+value.half_width+radius;
            const auto contains=[&](Point p){const auto rel=p-value.center;const double dist=rel.length();return dist>=inner && dist<=outer && std::abs(angle_difference(rel.angle()-value.angle))<=value.arc && (value.gap_arc<=0 || std::abs(angle_difference(rel.angle()-value.gap_angle))>value.gap_arc);};
            return radial_sweep(before,now,value.center,{inner,outer},{value.angle-value.arc,value.angle+value.arc,value.gap_angle-value.gap_arc,value.gap_angle+value.gap_arc},contains);
        } else if constexpr (std::is_same_v<T,ContactRect>) {
            const Point a=(before-value.center).rotated(-value.angle),b=(now-value.center).rotated(-value.angle),half=value.half+Point(radius,radius);
            const auto contains=[&](Point p){return std::abs(p.x)<=half.x && std::abs(p.y)<=half.y;};
            return contains(a) || contains(b) || crosses(a,b,{-half.x,-half.y},{half.x,-half.y}) || crosses(a,b,{half.x,-half.y},{half.x,half.y}) || crosses(a,b,{half.x,half.y},{-half.x,half.y}) || crosses(a,b,{-half.x,half.y},{-half.x,-half.y});
        } else {
            const Point direction=Point::from_angle(value.angle);
            const auto local=[&](Point p) {const auto relative=p-value.from;return Point(relative.dot(direction),relative.cross(direction));};
            const Point a=local(before),b=local(now);const double base=value.half_width+radius,slope=std::tan(value.arc),end=value.length+radius;
            const auto contains=[&](Point p){return p.x>=-radius && p.x<=end && std::abs(p.y)<=base+std::max(0.0,double(p.x))*slope;};
            if (contains(a) || contains(b)) return true;
            const Point edges[]={Point(-radius,-base),Point(0,-base),Point(end,-base-end*slope),Point(end,base+end*slope),Point(0,base),Point(-radius,base)};
            for (size_t i=0;i<6;++i) if (crosses(a,b,edges[i],edges[(i+1)%6])) return true;
            return false;
        }
    },shape);
}
}
