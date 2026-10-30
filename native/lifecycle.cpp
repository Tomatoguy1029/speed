#include "run_core.h"
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_lifecycle(const Dictionary &config) {
    if (started || closed) return false;
    const char *keys[] = {"death_freeze_time", "death_explosion_time", "death_game_over_time"};
    double times[3];
    for (int i = 0; i < 3; ++i) {
        if (!config.has(keys[i])) return false;
        const Variant value = config[keys[i]];
        if ((value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) || !std::isfinite(double(value)) || double(value) < 0) return false;
        times[i] = value;
    }
    if (!std::isfinite(times[0] + times[1] + times[2])) return false;
    death_freeze = times[0]; death_explosion = times[1]; death_game_over = times[2];
    lifecycle_ready = true;
    return true;
}

bool SpeedRunCore::check_run_end() {
    // 部品単位の比較では、実験場と同様にHPが尽きても更新を続ける。
    if (lifecycle_ready && phase == Phase::Play && ship.hp <= 0) {
        sequence_t = 0;
        Dictionary event; event["pos"] = ship.pos; emit_event("ship_death", event);
        phase = Phase::Dying;
        hitstop = 0;
    }
    return phase != Phase::Play;
}

void SpeedRunCore::step_death(double real_dt) {
    sequence_t += real_dt;
    const double t1 = death_freeze, t2 = t1 + death_explosion, t3 = t2 + death_game_over;
    if (sequence_t >= t1 && sequence_t - real_dt < t1) {
        Dictionary event; event["pos"] = ship.pos; emit_event("ship_explode", event);
    }
    if (sequence_t >= t2 && sequence_t - real_dt < t2) emit_event("game_over");
    if (sequence_t >= t3) {
        draw.drawing = false; draw.tracing = false;
        ship.vel = Vector2();
        world_accum = 0; world_steps = 0; hitstop = 0;
        phase = Phase::Ended;
    }
}
