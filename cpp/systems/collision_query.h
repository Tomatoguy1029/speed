#pragma once
#include <godot_cpp/variant/vector2.hpp>
#include <variant>
#include <vector>
namespace godot {struct RunState;}
namespace speed {
using Point=godot::Vector2;
struct PointCircle {Point center;double radius=0;};
struct SegmentCircle {Point from,to;double half_width=0;};
struct SweptSegment {Point before_from,before_to,from,to;double half_width=0;};
struct Polyline {std::vector<Point> points,before;double half_width=0;};
struct Fan {Point center;double radius=0,angle=0,arc=0;};
struct RingBand {Point center;double radius=0,half_width=0,angle=0,arc=0,gap_angle=0,gap_arc=0;};
struct ContactRect {Point center,half;double angle=0;};
struct TaperedBeam {Point from;double angle=0,length=0,half_width=0,arc=0;};
using ContactShape=std::variant<PointCircle,SegmentCircle,SweptSegment,Polyline,Fan,RingBand,ContactRect,TaperedBeam>;
struct ShipMotion {Point before,now;double radius=0;};
struct ContactGeometry {bool add_ship_radius=true,ship_sweep=false;};
class CollisionQuery {
public:
    static std::vector<size_t> enemy_rows(const godot::RunState &,Point lo,Point hi);
    static double segment_circle_t(Point from,Point to,Point center,double radius);
    static double point_segment_squared(Point point,Point from,Point to);
    static bool sweep_segment(Point ship_before,Point ship_now,Point from,Point to,double radius);
    static bool touches(const ContactShape &,const ShipMotion &,ContactGeometry);
};
}
