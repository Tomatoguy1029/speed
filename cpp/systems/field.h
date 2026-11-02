#pragma once
#include "../runtime/run_runtime.h"
#include <optional>
namespace godot {class SpeedRunCore;}
namespace speed {
struct SightBlocker {godot::Vector2 offset;float radius=0;};
struct BodyHit {uint32_t body=UINT32_MAX;double t=0;godot::Vector2 point,normal,position;};
class FieldSystem {
public:
    static std::vector<SightBlocker> sight_blockers(const RunRuntime &,godot::Vector2 lens,double length);
    static double sight_reach(godot::Vector2 direction,double length,const std::vector<SightBlocker> &);
    static void initialize(RunRuntime &);
    static bool add_well(RunRuntime &,godot::Vector2,double life,double radius,double pull);
    static bool spawn_well(RunRuntime &);
    static void spawn_warp(RunRuntime &);
    static bool take_warp(RunRuntime &);
    static RockHandle spawn_comet(RunRuntime &,bool rare);
    static void step_comets(RunRuntime &,double);
    static godot::PackedVector2Array rare_comet_positions(const RunRuntime &);
    static void step_gravity(RunRuntime &,double);
    static void comet_gravity(RunRuntime &,const DeathContext &);
    static void update(RunRuntime &);
    static void initialize_rocks(RunRuntime &);
    static RockHandle add_rock(RunRuntime &,FieldRock);
    static godot::Vector2 rock_at(const RunRuntime &,const FieldRock &);
    static void stream_rocks(RunRuntime &,double dt);
    static bool contact_rock(godot::SpeedRunCore &,uint32_t row,godot::Vector2 direction,godot::Vector2 from,double speed);
    static uint32_t rock_visual(const RunRuntime &,uint32_t row);
    static double rock_sprite_radius(const RunRuntime &,uint32_t row);
    static uint32_t visual(const RunRuntime &,const FieldBody &);
    static void collide_enemy(RunRuntime &,uint32_t row,godot::Vector2 from,double dt);
    static std::optional<BodyHit> first_body_hit(const RunRuntime &,godot::Vector2 from,godot::Vector2 to,double radius);
    static std::optional<BodyHit> arena_hit(const RunRuntime &,godot::Vector2,godot::Vector2,double);
    static godot::Vector2 safe_point(const RunRuntime &,godot::Rect2,godot::Vector2,double);
    static double body_gap(const RunRuntime &,godot::Vector2,double radius);
    static godot::Vector2 push_out(const RunRuntime &,godot::Vector2,double margin);
    static godot::Vector2 boundary_accel(const RunRuntime &,godot::Vector2);
    static void collide_ship(RunRuntime &);
    static bool validate(const godot::RunState &,const ContentBundle &);
};
}
