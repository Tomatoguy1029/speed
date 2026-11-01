#include "run_core.h"
#include "../cpp/runtime/lifecycle.h"
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_lifecycle(const Dictionary &config) {
    if (runtime.state.started || runtime.state.closed) return false;
    const char *keys[] = {"death_freeze_time", "death_explosion_time", "death_game_over_time"};
    double times[3];
    for (int i = 0; i < 3; ++i) {
        if (!config.has(keys[i])) return false;
        const Variant value = config[keys[i]];
        if ((value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) || !std::isfinite(double(value)) || double(value) < 0) return false;
        times[i] = value;
    }
    if (!std::isfinite(times[0] + times[1] + times[2])) return false;
    runtime.state.death_freeze = times[0]; runtime.state.death_explosion = times[1]; runtime.state.death_game_over = times[2];
    runtime.state.lifecycle_ready = true;
    return true;
}

bool SpeedRunCore::check_run_end() {
    // 部品単位の比較では、実験場と同様にHPが尽きても更新を続ける。
    if (runtime.state.lifecycle_ready && runtime.state.phase == Phase::Play && runtime.state.ship.hp <= 0) {
        runtime.state.sequence_t = 0;
        Dictionary event; event["pos"] = runtime.state.ship.pos; emit_event("ship_death", event);
        runtime.state.phase = Phase::Dying;
        runtime.state.hitstop = 0;
    }
    return runtime.state.phase != Phase::Play;
}

void SpeedRunCore::step_death(double real_dt) {
    runtime.state.sequence_t += real_dt;
    const double t1 = runtime.state.death_freeze, t2 = t1 + runtime.state.death_explosion, t3 = t2 + runtime.state.death_game_over;
    if (runtime.state.sequence_t >= t1 && runtime.state.sequence_t - real_dt < t1) {
        Dictionary event; event["pos"] = runtime.state.ship.pos; emit_event("ship_explode", event);
    }
    if (runtime.state.sequence_t >= t2 && runtime.state.sequence_t - real_dt < t2) emit_event("game_over");
    if (runtime.state.sequence_t >= t3 && runtime.api_configured) {speed::Lifecycle::finish(runtime,speed::ResultKind::Death);return;}
    if (runtime.state.sequence_t >= t3) {
        runtime.state.draw.drawing = false; runtime.state.draw.tracing = false;
        runtime.state.ship.vel = Vector2();
        runtime.state.control.world_real_accum = runtime.state.control.world_dt_accum = 0; runtime.state.control.world_steps = 0; runtime.state.hitstop = 0;
        runtime.state.phase = Phase::Ended;
    }
}
