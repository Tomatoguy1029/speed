#pragma once
#include "../../state/boss_states.h"
#include "image_pose_state.h"
#include "sweep_visual_state.h"
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct MonocerosSweepState {
    enum class Stage : uint8_t { Approach,Stop,Swing,Hold,Return };
    Stage stage=Stage::Approach;
    double elapsed=0,angle=0,glow=0,base=0,speed=0;
    int32_t side=1;
};
struct MonocerosLanceState {
    enum class Stage : uint8_t { Gather,Run,Stop };
    Stage stage=Stage::Gather;
    double elapsed=0,form=0,glow=0,traveled=0,boom_time=0,speed=0;
    bool shattered=false;
};
struct MonocerosReturnState {
    enum class Stage : uint8_t { Aim,Run,Brake,Turn };
    Stage stage=Stage::Aim;
    double elapsed=0,angle=0,glow=0,travel=0,traveled=0,from_angle=0,turn_delta=0;
    uint32_t completed=0;
};
struct MonocerosHornWaveState {
    enum class Stage : uint8_t { Windup,Swing,Recharge,Return };
    Stage stage=Stage::Windup;
    double elapsed=0,angle=0,glow=0;
    int32_t direction=1;
    bool released=false;
};
struct MonocerosDanceState {
    enum class Stage : uint8_t { Aim,Run,Circle,End };
    Stage stage=Stage::Aim;
    double elapsed=0,angle=0,glow=0,run_speed=0,travel=0,traveled=0,heading=0,speed=0;
    uint32_t completed=0;
};
struct MonocerosSlashVisual {godot::Vector2 from,to;double width=0,started=0;uint32_t seed=0;};
struct MonocerosSwordState {
    enum class Stage : uint8_t { Aim,Swing,Gap,Return };
    Stage stage=Stage::Aim;
    double elapsed=0,angle=0,glow=0,base=0,speed=0,released_at=0;
    uint32_t cut=0;
    int32_t side=1;
    bool released=false;
    godot::Vector2 target;
};
struct MonocerosBodyState {
    MonocerosImagePoseClock pose;
    std::vector<MonocerosBreathVisual> breaths;
    std::vector<MonocerosShatterVisual> shatters;
    std::vector<MonocerosBurnVisual> burns;
    std::vector<MonocerosSweepVisual> sweeps;
    std::vector<MonocerosSlashVisual> slashes;
};
}
