#pragma once
#include "../runtime/run_random.h"
#include "../runtime/input_frame.h"
#include <godot_cpp/variant/string_name.hpp>
namespace speed {
struct RunControlState {
    RunRandom rng;
    InputFrame last_input;
    godot::StringName stage_id;
    int64_t tick=0, revision=0;
    int32_t resume_phase=0;
    godot::Vector2 camera_center, logical_size;
    double camera_zoom=1, base_view=1, zoom_ref_speed=1, zoom_exp=0, zoom_min=1, look_ahead=0;
    bool camera_ready=false;
};
}
