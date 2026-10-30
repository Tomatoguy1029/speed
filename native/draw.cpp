#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_draw(const Dictionary &config, const Dictionary &stats) {
    if (started || closed) return false;
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
    draw_config = c;
    draw = Draw();
    draw_ready = true;
    return true;
}

double SpeedRunCore::world_scale() const {
    if (draw.drawing) return draw_config.time_scale;
    if (draw.tracing) return std::clamp(draw_config.slow_ref / std::max(1.0, draw.speed), draw_config.scale_min, 1.0);
    return 1.0;
}

void SpeedRunCore::begin_draw(bool press, Vector2 pen, int64_t clock_msec) {
    draw.before_speed = ship.vel.length();
    ship.glide = false;
    draw.drawing = true;
    draw.started = press;
    draw.blocked = false;
    draw.full_charge = draw.gauge >= 1.0 - 1e-6;
    draw.start_charge = draw.gauge;
    draw.amount = draw_config.capacity * draw.gauge;
    draw.limit = draw_config.length * draw.amount * (ship_config.max_speed / ship_config.base_max_speed) * draw_config.length_mult;
    draw.length = 0;
    draw.points.clear();
    if (press) { draw.points.append(pen); draw.first_msec = clock_msec; }
    emit_event("draw_start");
}

void SpeedRunCore::extend_draw(Vector2 pen, double camera_zoom) {
    const Vector2 last = draw.points[draw.points.size() - 1];
    const Vector2 d = pen - last;
    const double length = d.length();
    if (length < draw_config.point_step) return;
    const double remain = draw.limit - draw.length;
    if (remain <= 0.5) return;
    const double added = std::min(length, remain);
    if (added < 1) return;
    const Vector2 u = d / length;
    draw.points.append(last + u * added);
    draw.length += added;
    if (draw.points.size() < 3) return;
    const int64_t i = draw.points.size() - 2;
    const Vector2 a = draw.points[i - 1], b = draw.points[i], c = draw.points[i + 1];
    if ((b - a).normalized().dot((c - b).normalized()) < 0.5) return;
    Vector2 offset = ((a + c) * 0.5 - b) * 0.5;
    offset = offset.limit_length(2.5 / std::max(camera_zoom, 0.01));
    const Vector2 corrected = b + offset;
    const double old_length = double(a.distance_to(b)) + double(b.distance_to(c));
    const double new_length = double(a.distance_to(corrected)) + double(corrected.distance_to(c));
    draw.points.set(i, corrected);
    draw.length += new_length - old_length;
}

void SpeedRunCore::commit_draw() {
    if (draw.points.size() < 2) { draw.drawing = false; draw.points.clear(); return; }
    draw.gauge = std::max(0.0, draw.gauge - draw.start_charge * std::min(1.0, draw.length / draw.limit));
    auto points = draw.points;
    if (ship.pos.distance_to(points[0]) > 1) points.insert(0, ship.pos);
    const Vector2 dir = (points[1] - points[0]).normalized();
    const double sp = ship.vel.length();
    const double along = sp > 0 ? std::max(0.0, double(ship.vel.dot(dir)) / sp) : 0.0;
    const double carried = sp * draw_config.carry * along;
    const double thrust = ship_config.max_speed * draw_config.launch_ratio * draw.amount;
    const double limit = ship_config.max_speed * std::max(1.0, draw.amount);
    draw.speed = std::max(std::max(std::min(carried + thrust, limit), sp * along), 1.0);
    ship.vel = dir * draw.speed;
    ship.boost_t = draw_config.boost_duration;
    ship.fade_t = 0;
    ship.heading = dir;
    ++draw.dash_id;
    draw.total = 0;
    draw.lengths.clear();
    for (int64_t i = 1; i < points.size(); ++i) {
        const double length = points[i].distance_to(points[i - 1]);
        draw.lengths.append(length);
        draw.total += length;
    }
    draw.rate = std::max(draw.speed, draw.total / draw_config.run_time);
    // GDScriptで共有する描線配列にも、機体から始点までの区間が加わる。
    draw.points = points;
    draw.path = points;
    draw.progress = 0;
    draw.segment = 0;
    draw.seg_pos = 0;
    draw.drawing = false;
    draw.tracing = true;
    draw.inside.clear(); draw.passes.clear(); dash_stop = 0;
    Dictionary launch; launch["pos"] = ship.pos; launch["dir"] = dir; launch["gauge"] = draw.amount;
    emit_event("launch", launch);
}

bool SpeedRunCore::handle_draw(const Dictionary &input, int64_t clock_msec, double camera_zoom) {
    if (!started || closed || !ship_ready || !draw_ready || clock_msec < 0 || !std::isfinite(camera_zoom) || camera_zoom <= 0) return false;
    for (const char *key : {"touch", "press", "alt_press", "has_cursor", "pen_release"}) if (input.has(key) && input[key].get_type() != Variant::BOOL) return false;
    if (input.has("pen") && (input["pen"].get_type() != Variant::VECTOR2 || !Vector2(input["pen"]).is_finite())) return false;
    const bool press = input.get("press", false), alt = input.get("alt_press", false);
    const bool touch = input.get("touch", false), release = input.get("pen_release", false);
    const Vector2 pen = input.get("pen", Vector2());
    if (!draw.drawing && !draw.tracing) {
        if ((press || alt) && draw_config.capacity * draw.gauge >= draw_config.min_charge) begin_draw(press, pen, clock_msec);
        return true;
    }
    if (!draw.drawing) return true;
    if (!draw.started) {
        if (press) { draw.started = true; draw.points.append(pen); draw.first_msec = clock_msec; }
        else if (touch && release) { draw.drawing = false; draw.points.clear(); }
        return true;
    }
    if (bool(input.get("has_cursor", false))) extend_draw(pen, camera_zoom);
    if (touch && (release || alt)) commit_draw();
    else if (draw.length >= draw.limit - 0.5 || draw.blocked) commit_draw();
    else if (press && clock_msec - draw.first_msec >= draw_config.confirm_delay * 1000.0 && draw.points.size() >= 2) commit_draw();
    return true;
}

void SpeedRunCore::end_trace(bool completed) {
    draw.tracing = false;
    const double speed = std::max(double(ship.vel.length()), draw.before_speed);
    const Vector2 direction = ship.vel.is_zero_approx() ? ship.heading : ship.vel.normalized();
    ship.vel = direction * speed;
    ship.heading = direction;
    if (completed) {
        ship.glide = true;
        ship.glide_t = 0;
        ship.glide_speed = std::max(speed * draw_config.glide_ratio, ship_config.max_speed * ship_config.steer_cruise);
        ship.vel = direction * ship.glide_speed;
        ship.boost_t = draw_config.boost_duration;
    }
    Dictionary event; event["completed"] = completed; emit_event("trace_end", event);
}

bool SpeedRunCore::step_draw(double real_dt) {
    if (!started || closed || !ship_ready || !draw_ready || !std::isfinite(real_dt) || real_dt < 0) return false;
    if (!draw.tracing) {
        if (!draw.drawing) {
            const double before = draw.gauge;
            draw.gauge = std::min(1.0, draw.gauge + real_dt / (draw_config.charge_time * draw_config.capacity));
            if (before < 1 && draw.gauge >= 1) emit_event("gauge_full");
        }
        return true;
    }
    double dist = draw.rate * real_dt;
    while (dist > 1e-9 && draw.segment < draw.path.size() - 1) {
        const Vector2 a = draw.path[draw.segment], b = draw.path[draw.segment + 1];
        const double length = a.distance_to(b);
        if (length < 1e-6) { ++draw.segment; draw.seg_pos = 0; continue; }
        const Vector2 u = (b - a) / length;
        const double move = std::min(dist, length - draw.seg_pos);
        const Vector2 from = ship.pos;
        for (auto it = draw.inside.begin(); it != draw.inside.end();) {
            const auto &enemy = enemies[it->second];
            const double radius = enemy.radius + trace_radius + 2.0;
            if (!enemy.alive || enemy.dead || enemy.id != it->first || enemy.pos.distance_squared_to(from) > radius * radius) it = draw.inside.erase(it);
            else ++it;
        }
        draw.seg_pos += move;
        dist -= move;
        ship.pos = a + u * draw.seg_pos;
        ship.vel = u * draw.speed;
        ship.heading = u;
        if (combat_ready && collide_ship(from, trace_radius)) { end_trace(false); return true; }
        const double speed = ship.vel.length();
        if (speed < draw.speed) draw.speed = speed;
        if (draw.seg_pos >= length - 1e-9) { ++draw.segment; draw.seg_pos = 0; }
    }
    draw.progress = std::clamp(double(draw.segment) / std::max(1.0, double(draw.path.size() - 1)), 0.0, 1.0);
    if (draw.segment >= draw.path.size() - 1) end_trace(true);
    ship_pos = ship.pos;
    return true;
}

Dictionary SpeedRunCore::draw_snapshot() const {
    Dictionary out;
    if (!draw_ready || closed) return out;
    out["gauge"] = draw.gauge; out["drawing"] = draw.drawing; out["draw_started"] = draw.started;
    out["draw_blocked"] = draw.blocked; out["trace_full_charge"] = draw.full_charge;
    out["draw_start_charge"] = draw.start_charge; out["draw_gauge"] = draw.amount;
    out["draw_limit"] = draw.limit; out["draw_length"] = draw.length; out["draw_points"] = draw.points;
    out["tracing"] = draw.tracing; out["dash_id"] = draw.dash_id; out["trace_path"] = draw.path;
    out["trace_lengths"] = draw.lengths; out["trace_total"] = draw.total; out["trace_progress"] = draw.progress;
    return out;
}
