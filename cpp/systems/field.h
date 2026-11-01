#pragma once
#include "../runtime/run_runtime.h"
#include <optional>
namespace speed {
struct BodyHit {uint32_t body=0;double t=0;godot::Vector2 point;};
class FieldSystem {
public:
    static void initialize(RunRuntime &);
    static std::optional<BodyHit> first_body_hit(const RunRuntime &,godot::Vector2 from,godot::Vector2 to,double radius);
    static double body_gap(const RunRuntime &,godot::Vector2,double radius);
    static godot::Vector2 push_out(const RunRuntime &,godot::Vector2,double margin);
    static godot::Vector2 boundary_accel(const RunRuntime &,godot::Vector2);
    static void collide_ship(RunRuntime &);
    static bool validate(const RunRuntime &);
};
}
