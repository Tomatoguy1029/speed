#pragma once
#include "../runtime/run_random.h"
#include <vector>
#include <string>
#include "../runtime/input_frame.h"
#include "entity_store.h"
#include <godot_cpp/variant/string_name.hpp>
namespace speed {
struct RunControlState {
    RunRandom rng;
    InputFrame last_input;
    godot::StringName stage_id;
    int64_t tick=0, revision=0;
    int32_t resume_phase=0;
    double world_scale=1, world_real_accum=0, world_dt_accum=0;
    double last_world_real_dt=0, last_world_dt=0, bonus_remaining=0, time_limit=-1;
    int64_t world_steps=0, world_tick_div=1, world_updates=0;
    bool lab_mode=false;
    bool lab_enemy_ai=true;
    double boss_at=-1;
    // G10の停止と出口移動を値として保持し、復帰後も一度だけ適用する。
    double boss_ram_hitstop=0;
    double boss_touch_damage=0;
    struct BossRam {
        bool pending=false;
        EnemyHandle target;
        int64_t target_id=0,serial=0;
        godot::Vector2 entry,exit,direction;
        double remaining=0;
    } boss_ram;
    int64_t next_boss_ram_serial=1;
    bool draco_finish_done=false;
    std::vector<std::string> final_modules;
    bool ui_overlay=false, ui_reward=false, time_limit_reached=false;
    godot::Vector2 camera_center, logical_size;
    double cinematic_bars=0;
    double camera_zoom=1, base_view=1, zoom_ref_speed=1, zoom_exp=0, zoom_min=1, look_ahead=0;
    bool camera_ready=false,cinematic_camera=false,cinematic_hide_enemies=false;
    bool lab_pinned=false;
    godot::Vector2 lab_pin;
    struct LabSchedule {uint32_t definition=0;int64_t start=0,end=0,interval=1,count=1;double probability=1,radius=0,spacing=60,facing=0;godot::Vector2 position;bool enabled=true,elite=false,boss=false;};
    std::vector<LabSchedule> lab_schedule;
};
}
