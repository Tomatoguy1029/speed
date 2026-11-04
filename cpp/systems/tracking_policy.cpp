#include "tracking_policy.h"
#include <algorithm>
namespace speed {
godot::Vector2 TrackingPolicy::target(godot::Vector2 position,double facing,godot::Vector2 desired) const {
    return locked()?position+godot::Vector2::from_angle(facing)*std::max(1.0,double(position.distance_to(desired))):desired;
}
godot::Vector2 TrackingPolicy::velocity(godot::Vector2 previous,double facing,godot::Vector2 desired) const {
    if (!locked()) return desired;
    const auto direction=previous.length_squared()>0.000001?previous.normalized():godot::Vector2::from_angle(facing);
    return direction*desired.length();
}
}
