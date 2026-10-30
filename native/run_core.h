#pragma once
#include "runtime_data.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <unordered_map>

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
    bool motion_ready = false;
    bool started = false;
    bool closed = false;
    double time = 0.0;
    int64_t ticks = 0;
protected:
    static void _bind_methods();
public:
    bool configure(const Dictionary &data);
    bool start(int64_t seed, int64_t first_id = 1);
    bool set_motion_context(Vector2 ship, Vector2 center, Vector2 half);
    int64_t spawn_enemy(StringName type, Vector2 position);
    bool remove_enemy(int64_t id);
    Array enemies_snapshot() const;
    bool step(double delta);
    void close();
    Dictionary inspect() const;
};
}
