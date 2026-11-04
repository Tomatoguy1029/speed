#pragma once
#include "fire_field.h"
#include "fire_history.h"
#include "../../state/entity_store.h"
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>

namespace speed {
struct CanisFireVisual {
    int64_t id=0,action=0,frame=-1,trail_id=0;
    uint32_t technique=0,profile=0,ordinal=0,field_width=0,field_height=0;
    EnemyHandle hound;
    godot::Vector2 origin,field_origin,release_origin;
    double angle=0,length=0,width=0,started=0,duration=0,speed=1,cell=0,release_angle=0,release_length=0,sample_age=0;
    bool hound_jet=false,has_footprint=false,continuous=false,has_release=false;
    std::vector<CanisFirePixel> pixels;
    CanisFireHistory history;
};
struct CanisFireVisualState {
    std::vector<CanisFireVisual> jets;
    int64_t action=0;
    uint32_t next_ordinal=0;
};
}
