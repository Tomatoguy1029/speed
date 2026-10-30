#include "run_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void SpeedRunCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start", "seed"), &SpeedRunCore::start);
    ClassDB::bind_method(D_METHOD("step", "delta"), &SpeedRunCore::step);
    ClassDB::bind_method(D_METHOD("close"), &SpeedRunCore::close);
    ClassDB::bind_method(D_METHOD("inspect"), &SpeedRunCore::inspect);
}

bool SpeedRunCore::start(int64_t seed) {
    if (started || closed) return false;
    rng.instantiate();
    rng->set_seed(seed);
    started = true;
    return true;
}

bool SpeedRunCore::step(double delta) {
    if (!started || closed || !std::isfinite(delta) || delta <= 0.0 || !std::isfinite(time + delta)) return false;
    time += delta;
    ++ticks;
    return true;
}

void SpeedRunCore::close() {
    closed = true;
    rng.unref();
}

Dictionary SpeedRunCore::inspect() const {
    Dictionary out;
    out["active"] = started && !closed;
    out["closed"] = closed;
    out["time"] = time;
    out["ticks"] = ticks;
    out["rng_state"] = rng.is_valid() ? String::num_int64(rng->get_state()) : String();
    return out;
}
