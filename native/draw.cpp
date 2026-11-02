#include "../cpp/behaviors/weapons/bipolar.h"
#include "../cpp/behaviors/weapons/dashRangeDrone.h"
#include "../cpp/behaviors/weapons/massTow.h"
#include "run_core.h"
#include "../cpp/behaviors/weapons/afterimage.h"
#include "../cpp/systems/field.h"
#include "../cpp/behaviors/traits/fullCharge.h"
#include "../cpp/behaviors/traits/rampage.h"
#include "../cpp/behaviors/traits/killSonic.h"
#include "../cpp/behaviors/traits/runUp.h"
#include "../cpp/behaviors/traits/vortex.h"
#include "../cpp/behaviors/weapons/sonic.h"
#include "../cpp/behaviors/weapons/endBlast.h"
#include "../cpp/behaviors/weapons/mines.h"
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_draw(const Dictionary &config, const Dictionary &stats) {
    if (runtime.state.started || runtime.state.closed) return false;
    DrawConfig c{};
    const char *keys[] = {"draw_min_charge", "draw_length", "draw_step", "draw_confirm_delay", "draw_run_time", "draw_time_scale", "draw_run_slow_ref", "draw_run_scale_min", "boost_duration", "carry", "launch_ratio", "glide_speed_ratio", "capacity", "charge_time", "length_mult"};
    double *fields[] = {&c.min_charge, &c.length, &c.point_step, &c.confirm_delay, &c.run_time, &c.time_scale, &c.slow_ref, &c.scale_min, &c.boost_duration, &c.carry, &c.launch_ratio, &c.glide_ratio, &c.capacity, &c.charge_time, &c.length_mult};
    for (int i = 0; i < 15; ++i) {
        const Dictionary &source = i < 12 ? config : stats;
        if (!source.has(keys[i])) return false;
        const Variant value = source[keys[i]];
        if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        *fields[i] = double(value);
        if (!std::isfinite(*fields[i]) || *fields[i] < 0) return false;
    }
    if (c.length <= 0 || c.run_time <= 0 || c.capacity <= 0 || c.charge_time <= 0 || c.length_mult <= 0 || c.scale_min > 1) return false;
    runtime.state.draw_config = c;
    runtime.state.draw = Draw();
    runtime.state.draw_ready = true;
    return true;
}

double SpeedRunCore::world_scale() const {
    if (runtime.state.draw.drawing) return runtime.state.draw_config.time_scale;
    if (runtime.state.draw.tracing) return std::clamp(runtime.state.draw_config.slow_ref / std::max(1.0, runtime.state.draw.speed), runtime.state.draw_config.scale_min, 1.0);
    return 1.0;
}

void SpeedRunCore::begin_draw(bool press, Vector2 pen, int64_t clock_msec) {
    runtime.state.draw.before_speed = runtime.state.ship.vel.length();
    runtime.state.ship.glide = false;
    runtime.state.draw.drawing = true;
    runtime.state.draw.started = press;
    runtime.state.draw.blocked = false;
    runtime.state.draw.full_charge = runtime.state.draw.gauge >= 1.0 - 1e-6;
    runtime.state.draw.start_charge = runtime.state.draw.gauge;
    runtime.state.draw.amount = runtime.state.draw_config.capacity * runtime.state.draw.gauge;
    runtime.state.draw.limit = runtime.state.draw_config.length * runtime.state.draw.amount * (runtime.state.ship_config.max_speed / runtime.state.ship_config.base_max_speed) * runtime.state.draw_config.length_mult;
    runtime.state.draw.length = 0;
    runtime.state.draw.points.clear();
    if (press) { runtime.state.draw.points.append(pen); runtime.state.draw.first_msec = clock_msec; }
    emit_event("draw_start");
}

void SpeedRunCore::extend_draw(Vector2 pen, double camera_zoom) {
    const Vector2 last = runtime.state.draw.points[runtime.state.draw.points.size() - 1];
    const Vector2 d = pen - last;
    const double length = d.length();
    if (length < runtime.state.draw_config.point_step) return;
    const double remain = runtime.state.draw.limit - runtime.state.draw.length;
    if (remain <= 0.5) return;
    double added = std::min(length, remain);
    const auto hit=speed::FieldSystem::first_body_hit(runtime,last,last+d/length*added,runtime.state.ship_config.ship_radius);
    if (hit) {added=std::max(0.0,hit->t*added-2.0);runtime.state.draw.blocked=true;}
    if (added < 1) return;
    const Vector2 u = d / length;
    runtime.state.draw.points.append(last + u * added);
    runtime.state.draw.length += added;
    if (runtime.state.draw.points.size() < 3) return;
    const int64_t i = runtime.state.draw.points.size() - 2;
    const Vector2 a = runtime.state.draw.points[i - 1], b = runtime.state.draw.points[i], c = runtime.state.draw.points[i + 1];
    if ((b - a).normalized().dot((c - b).normalized()) < 0.5) return;
    Vector2 offset = ((a + c) * 0.5 - b) * 0.5;
    offset = offset.limit_length(2.5 / std::max(camera_zoom, 0.01));
    const Vector2 corrected = b + offset;
    if (speed::FieldSystem::first_body_hit(runtime,a,corrected,runtime.state.ship_config.ship_radius) || speed::FieldSystem::first_body_hit(runtime,corrected,c,runtime.state.ship_config.ship_radius)) return;
    const double old_length = double(a.distance_to(b)) + double(b.distance_to(c));
    const double new_length = double(a.distance_to(corrected)) + double(corrected.distance_to(c));
    runtime.state.draw.points.set(i, corrected);
    runtime.state.draw.length += new_length - old_length;
}

void SpeedRunCore::commit_draw() {
    if (runtime.state.draw.points.size() < 2) { runtime.state.draw.drawing = false; runtime.state.draw.points.clear(); return; }
    runtime.state.draw.gauge = std::max(0.0, runtime.state.draw.gauge - runtime.state.draw.start_charge * std::min(1.0, runtime.state.draw.length / runtime.state.draw.limit));
    auto points = runtime.state.draw.points;
    if (runtime.state.ship.pos.distance_to(points[0]) > 1) points.insert(0, runtime.state.ship.pos);
    const Vector2 dir = (points[1] - points[0]).normalized();
    const double sp = runtime.state.ship.vel.length();
    const double along = sp > 0 ? std::max(0.0, double(runtime.state.ship.vel.dot(dir)) / sp) : 0.0;
    const double carried = sp * runtime.state.draw_config.carry * along;
    const double thrust = runtime.state.ship_config.max_speed * runtime.state.draw_config.launch_ratio * runtime.state.draw.amount;
    const double limit = runtime.state.ship_config.max_speed * std::max(1.0, runtime.state.draw.amount);
    runtime.state.draw.speed = std::max(std::max(std::min(carried + thrust, limit), sp * along), 1.0);
    runtime.state.ship.vel = dir * runtime.state.draw.speed;
    runtime.state.ship.boost_t = runtime.state.draw_config.boost_duration;
    runtime.state.ship.fade_t = 0;
    runtime.state.ship.heading = dir;
    ++runtime.state.draw.dash_id;
    runtime.state.draw.total = 0;
    runtime.state.draw.lengths.clear();
    for (int64_t i = 1; i < points.size(); ++i) {
        const double length = points[i].distance_to(points[i - 1]);
        runtime.state.draw.lengths.append(length);
        runtime.state.draw.total += length;
    }
    runtime.state.draw.rate = std::max(runtime.state.draw.speed, runtime.state.draw.total / runtime.state.draw_config.run_time);
    // GDScriptで共有する描線配列にも、機体から始点までの区間が加わる。
    runtime.state.draw.points = points;
    runtime.state.draw.path = points;
    runtime.state.draw.progress = 0;
    runtime.state.draw.segment = 0;
    runtime.state.draw.seg_pos = 0;
    runtime.state.draw.drawing = false;
    runtime.state.draw.tracing = true;
    speed::RunUpBehavior::launch(runtime);
    speed::FullChargeBehavior::launch(runtime);
    speed::RampageBehavior::launch(runtime);
    speed::SonicBehavior::launch(runtime);
    speed::KillSonicBehavior::launch(runtime);
    for (const auto &owned:runtime.state.loadout.weapons) {
        const auto &id=runtime.content->equipment[owned.definition-1].external_id;
        if (id=="W27") speed::AfterimageBehavior::launch(runtime);
        else if (id=="W22") speed::BipolarBehavior::launch(runtime);
        else if (id=="W26") speed::DashRangeDroneBehavior::launch(runtime);
    }
    runtime.state.draw.inside.clear(); runtime.state.draw.passes.clear(); runtime.state.dash_stop = 0;
    Dictionary launch; launch["pos"] = runtime.state.ship.pos; launch["dir"] = dir; launch["gauge"] = runtime.state.draw.amount;
    emit_event("launch", launch);
}

bool SpeedRunCore::handle_draw(const Dictionary &input, int64_t clock_msec, double camera_zoom) {
    speed::InputFrame frame;
    if (!speed::decode_input(input,frame,false)) return false;
    return handle_draw_input(frame,clock_msec,camera_zoom);
}

bool SpeedRunCore::handle_draw_input(const speed::InputFrame &input, int64_t clock_msec, double camera_zoom) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !runtime.state.draw_ready || clock_msec < 0 || !std::isfinite(camera_zoom) || camera_zoom <= 0) return false;
    const bool press = input.press, alt = input.alt_press;
    const bool touch = input.touch, release = input.pen_release;
    const Vector2 pen = input.pen;
    if (!runtime.state.draw.drawing && !runtime.state.draw.tracing) {
        if ((press || alt) && runtime.state.draw_config.capacity * runtime.state.draw.gauge >= runtime.state.draw_config.min_charge) begin_draw(press, pen, clock_msec);
        return true;
    }
    if (!runtime.state.draw.drawing) return true;
    if (!runtime.state.draw.started) {
        if (press) { runtime.state.draw.started = true; runtime.state.draw.points.append(pen); runtime.state.draw.first_msec = clock_msec; }
        else if (touch && release) { runtime.state.draw.drawing = false; runtime.state.draw.points.clear(); }
        return true;
    }
    if (bool(input.has_cursor)) extend_draw(pen, camera_zoom);
    if (touch && (release || alt)) commit_draw();
    else if (runtime.state.draw.length >= runtime.state.draw.limit - 0.5 || runtime.state.draw.blocked) commit_draw();
    else if (press && clock_msec - runtime.state.draw.first_msec >= runtime.state.draw_config.confirm_delay * 1000.0 && runtime.state.draw.points.size() >= 2) commit_draw();
    return true;
}

void SpeedRunCore::end_trace(bool completed) {
    runtime.state.draw.tracing = false;
    for (const auto &owned:runtime.state.loadout.weapons) {
        const auto &id=runtime.content->equipment[owned.definition-1].external_id;
        if (id=="W27") speed::AfterimageBehavior::end(runtime);
        else if (id=="W26") speed::DashRangeDroneBehavior::end(runtime);
        else if (id=="W22") speed::BipolarBehavior::end(runtime);
        else if (id=="W21") speed::MassTowBehavior::end(runtime);
        else if (id=="W29") speed::EndBlastBehavior::end(runtime);
        else if (id=="W07") speed::MinesBehavior::end(runtime);
    }
    for (const auto &owned:runtime.state.loadout.traits) {
        if (runtime.state.phase!=RunState::Phase::Play) break;
        const auto &id=runtime.content->equipment[owned.definition-1].external_id;
        if (id=="T05") speed::KillSonicBehavior::end(runtime);
        else if (id=="T33") speed::RampageBehavior::end(runtime);
        else if (id=="T03") speed::VortexBehavior::end(runtime);
    }
    speed::FullChargeBehavior::end(runtime);
    const double speed = std::max(double(runtime.state.ship.vel.length()), runtime.state.draw.before_speed);
    const Vector2 direction = runtime.state.ship.vel.is_zero_approx() ? runtime.state.ship.heading : runtime.state.ship.vel.normalized();
    runtime.state.ship.vel = direction * speed;
    runtime.state.ship.heading = direction;
    if (completed) {
        runtime.state.ship.glide = true;
        runtime.state.ship.glide_t = 0;
        runtime.state.ship.glide_speed = std::max(speed * runtime.state.draw_config.glide_ratio, runtime.state.ship_config.max_speed * runtime.state.ship_config.steer_cruise);
        runtime.state.ship.vel = direction * runtime.state.ship.glide_speed;
        runtime.state.ship.boost_t = runtime.state.draw_config.boost_duration;
    }
    Dictionary event; event["completed"] = completed; emit_event("trace_end", event);
}

bool SpeedRunCore::step_draw(double real_dt) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !runtime.state.draw_ready || !std::isfinite(real_dt) || real_dt < 0) return false;
    if (!runtime.state.draw.tracing) {
        if (!runtime.state.draw.drawing) {
            const double before = runtime.state.draw.gauge;
            runtime.state.draw.gauge = std::min(1.0, runtime.state.draw.gauge + real_dt / (runtime.state.draw_config.charge_time * runtime.state.draw_config.capacity));
            if (before < 1 && runtime.state.draw.gauge >= 1) emit_event("gauge_full");
        }
        return true;
    }
    const auto trail=[&](Vector2 from) {
        speed::FullChargeBehavior::trail(runtime,from,runtime.state.ship.pos);
        for (const auto &owned:runtime.state.loadout.weapons) {
            if (runtime.state.phase!=RunState::Phase::Play) return;
            if (runtime.content->equipment[owned.definition-1].external_id=="W27") speed::AfterimageBehavior::trail(runtime,from,runtime.state.ship.pos);
            else if (runtime.content->equipment[owned.definition-1].external_id=="W26") speed::DashRangeDroneBehavior::trail(runtime,from,runtime.state.ship.pos);
        }
    };
    double dist = runtime.state.draw.rate * real_dt;
    while (dist > 1e-9 && runtime.state.draw.segment < runtime.state.draw.path.size() - 1) {
        const Vector2 a = runtime.state.draw.path[runtime.state.draw.segment], b = runtime.state.draw.path[runtime.state.draw.segment + 1];
        const double length = a.distance_to(b);
        if (length < 1e-6) { ++runtime.state.draw.segment; runtime.state.draw.seg_pos = 0; continue; }
        const Vector2 u = (b - a) / length;
        const double move = std::min(dist, length - runtime.state.draw.seg_pos);
        const Vector2 from = runtime.state.ship.pos;
        for (auto it = runtime.state.draw.inside.begin(); it != runtime.state.draw.inside.end();) {
            const auto &enemy = runtime.state.enemies[it->second];
            const double radius = enemy.radius + runtime.state.trace_radius + 2.0;
            if (!enemy.alive || enemy.dead || enemy.id != it->first || enemy.pos.distance_squared_to(from) > radius * radius) it = runtime.state.draw.inside.erase(it);
            else ++it;
        }
        runtime.state.draw.seg_pos += move;
        dist -= move;
        runtime.state.ship.pos = a + u * runtime.state.draw.seg_pos;
        runtime.state.ship.vel = u * runtime.state.draw.speed;
        runtime.state.ship.heading = u;
        if (runtime.state.combat_ready && collide_ship(from, runtime.state.trace_radius)) {trail(from);end_trace(false);return true;}
        trail(from);
        if (runtime.state.phase!=RunState::Phase::Play) return true;
        const double speed = runtime.state.ship.vel.length();
        if (speed < runtime.state.draw.speed) runtime.state.draw.speed = speed;
        if (runtime.state.draw.seg_pos >= length - 1e-9) { ++runtime.state.draw.segment; runtime.state.draw.seg_pos = 0; }
    }
    runtime.state.draw.progress = std::clamp(double(runtime.state.draw.segment) / std::max(1.0, double(runtime.state.draw.path.size() - 1)), 0.0, 1.0);
    if (runtime.state.draw.segment >= runtime.state.draw.path.size() - 1) end_trace(true);
    runtime.state.ship_pos = runtime.state.ship.pos;
    return true;
}

Dictionary SpeedRunCore::draw_snapshot() const {
    Dictionary out;
    if (!runtime.state.draw_ready || runtime.state.closed) return out;
    out["gauge"] = runtime.state.draw.gauge; out["drawing"] = runtime.state.draw.drawing; out["draw_started"] = runtime.state.draw.started;
    out["draw_blocked"] = runtime.state.draw.blocked; out["trace_full_charge"] = runtime.state.draw.full_charge;
    out["draw_start_charge"] = runtime.state.draw.start_charge; out["draw_gauge"] = runtime.state.draw.amount;
    out["draw_limit"] = runtime.state.draw.limit; out["draw_length"] = runtime.state.draw.length; out["draw_points"] = runtime.state.draw.points;
    out["tracing"] = runtime.state.draw.tracing; out["dash_id"] = runtime.state.draw.dash_id; out["trace_path"] = runtime.state.draw.path;
    out["trace_lengths"] = runtime.state.draw.lengths; out["trace_total"] = runtime.state.draw.total; out["trace_progress"] = runtime.state.draw.progress;
    return out;
}
