#pragma once
#include "../runtime/run_runtime.h"
#include <optional>
namespace godot {class SpeedRunCore;}
namespace speed {
struct BodyHit {uint32_t body=0;double t=0;godot::Vector2 point;};
class FieldSystem {
public:
    static void initialize(RunRuntime &);
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
    static double body_gap(const RunRuntime &,godot::Vector2,double radius);
    static godot::Vector2 push_out(const RunRuntime &,godot::Vector2,double margin);
    static godot::Vector2 boundary_accel(const RunRuntime &,godot::Vector2);
    static void collide_ship(RunRuntime &);
    static bool validate(const godot::RunState &,const ContentBundle &);
};
}
