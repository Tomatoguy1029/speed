#pragma once
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/transform2d.hpp>
namespace speed {
struct MonocerosBreathVisual {
    godot::Vector2 position;double direction=0,started=0,lifetime=0,spread=0,reach=0;
    uint32_t seed=0,preset=0;bool attached=false;
};
struct MonocerosBurnVisual {godot::Vector2 position;double started=0;};
struct MonocerosShatterVisual {godot::Vector2 position;double started=0,lifetime=0;};
struct MonocerosImageNodePose {uint32_t node=0;godot::Transform2D transform;bool visible=true;};
struct MonocerosImagePoseClock {
    bool initialized=false;
    double last_body_clock=0,body=0,neck=0,head=0,tail=0,flame=0,gait=0;
    double feedback_white=0,feedback_angle=0;
    godot::Vector2 feedback_offset;
    std::vector<MonocerosImageNodePose> nodes;
};
}
