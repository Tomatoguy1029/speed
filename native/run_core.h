#pragma once
#include "runtime_data.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {
// 可変状態は各ランが所有する。終了した実体は再利用しない。
class SpeedRunCore : public RefCounted {
    GDCLASS(SpeedRunCore, RefCounted)
    Ref<RandomNumberGenerator> rng;
    std::vector<speed::EnemyDefinition> definitions;
    bool started = false;
    bool closed = false;
    double time = 0.0;
    int64_t ticks = 0;
protected:
    static void _bind_methods();
public:
    bool configure(const Dictionary &data);
    bool start(int64_t seed);
    bool step(double delta);
    void close();
    Dictionary inspect() const;
};
}
