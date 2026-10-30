#pragma once
#include "runtime_data.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <unordered_map>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {
// 可変状態は各ランが所有する。終了した実体は再利用しない。
class SpeedRunCore : public RefCounted {
    GDCLASS(SpeedRunCore, RefCounted)
    Ref<RandomNumberGenerator> rng;
    std::vector<speed::EnemyDefinition> definitions;
    struct Enemy {
        int64_t id = 0;
        size_t definition = 0;
        Vector2 pos, vel;
        double hp = 0.0, facing = 0.0, age = 0.0, fire_t = 0.0;
        bool alive = false;
    };
    std::vector<Enemy> enemies;
    std::vector<size_t> free_rows;
    std::unordered_map<int64_t, size_t> rows_by_id;
    int64_t next_id = 1;
    Vector2 ship_pos, view_center, view_half;
    struct Ship {
        Vector2 pos, vel, heading = Vector2(0, -1);
        double hp = 0, hurt = 0, invuln = 0, shield_flash = 0, shield_t = 0;
        double boost_t = 0, fade_t = 0, glide_t = 0, glide_speed = 0, peak_speed = 0;
        bool glide = false;
    } ship;
    struct ShipConfig {
        double start_radius, base_max_speed, stick_dead_zone, mouse_dead_zone, steer_cruise;
        double glide_hold, glide_fade, cruise_floor, energy_cut, cruise_drag, overcap_decay;
        double field_radius, boundary_push, ship_radius, crash_restitution, ship_hurt_time;
        double max_hp, max_speed, turn_rate, acceleration, glide_duration_mult, invulnerability;
    } ship_config{};
    struct DrawConfig {
        double min_charge, length, point_step, confirm_delay, run_time, time_scale, slow_ref, scale_min;
        double boost_duration, carry, launch_ratio, glide_ratio, capacity, charge_time, length_mult;
    } draw_config{};
    struct Draw {
        double gauge = 1, start_charge = 0, amount = 0, limit = 0, length = 0, before_speed = 0;
        double speed = 0, rate = 0, seg_pos = 0, total = 0, progress = 0;
        bool drawing = false, started = false, blocked = false, full_charge = false, tracing = false;
        int64_t first_msec = 0, dash_id = 0, segment = 0;
        PackedVector2Array points, path;
        PackedFloat32Array lengths;
    } draw;
    bool draw_ready = false;
    void begin_draw(bool press, Vector2 pen, int64_t clock_msec);
    void extend_draw(Vector2 pen, double camera_zoom);
    void commit_draw();
    void end_trace(bool completed);
    bool ship_ready = false;
    void steer_ship(double want, double dt);
    void move_ship(double dt, Vector2 accel);
    bool motion_ready = false;
    bool started = false;
    bool closed = false;
    double time = 0.0;
    int64_t ticks = 0;
protected:
    static void _bind_methods();
public:
    bool configure(const Dictionary &data);
    bool configure_ship(const Dictionary &config, const Dictionary &stats);
    bool step_ship(double real_dt, double world_dt, const Dictionary &input);
    Dictionary ship_snapshot() const;
    bool configure_draw(const Dictionary &config, const Dictionary &stats);
    bool handle_draw(const Dictionary &input, int64_t clock_msec, double camera_zoom);
    bool step_draw(double real_dt);
    double world_scale() const;
    Dictionary draw_snapshot() const;
    bool start(int64_t seed, int64_t first_id = 1);
    bool set_motion_context(Vector2 ship, Vector2 center, Vector2 half);
    int64_t spawn_enemy(StringName type, Vector2 position);
    bool remove_enemy(int64_t id);
    Array enemies_snapshot() const;
    PackedFloat32Array enemy_buffer(StringName type, double scale, double angle_offset) const;
    bool step(double delta);
    void close();
    Dictionary inspect() const;
};
}
