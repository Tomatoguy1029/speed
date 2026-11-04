#pragma once
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct CentaurusReleaseFx {godot::Vector2 position;double angle=0,started=0;};
struct CentaurusLandingFx {godot::Vector2 position;std::vector<godot::Vector2> feet;double started=0,radius=0;};
struct CentaurusStompFx {godot::Vector2 position;double angle=0,half=0,radius=0,started=0;};
struct CentaurusUpFx {godot::Vector2 position;double angle=0,started=0,radius=0,length=0;};
struct CentaurusReferenceFxState {
    bool leaping=false;
    int64_t rain_id=0,stomp_id=0;
    std::vector<uint8_t> up_emitted;
    std::vector<CentaurusReleaseFx> releases;
    std::vector<CentaurusLandingFx> landings;
    std::vector<CentaurusStompFx> stomps;
    std::vector<CentaurusUpFx> ups;
};
}
