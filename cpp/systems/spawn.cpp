#include "../api/run_core.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

bool SpeedRunCore::configure_refill(const Dictionary &config) {
    if (runtime.state.started || runtime.state.closed || !runtime.state.population.ready) return false;
    const Variant cap = config.get("spawn_total_cap", Variant());
    const Variant interval = config.get("spawn_refill_time", Variant());
    for (const Variant &value : {cap, interval}) {
        if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return false;
    }
    if (double(cap) < 0 || double(interval) <= 0) return false;
    auto supported = [&](StringName id) {
        auto found = std::find_if(runtime.content->definitions.begin(), runtime.content->definitions.end(), [&](const auto &d) { return d.id == id; });
        return found != runtime.content->definitions.end() && found->spawn_ready && found->scaling.ready;
    };
    for (const auto &phase : runtime.state.spawn_timeline.phases) for (const auto &entry : phase.mix) if (!supported(entry.first)) return false;
    for (const auto &phase : runtime.state.spawn_timeline.phases) if (phase.wave_interval > 0 && !String(phase.wave_type).is_empty() && !supported(phase.wave_type)) return false;
    for (const auto &curve : runtime.state.spawn_timeline.curves) if (!supported(curve.type)) return false;
    runtime.state.population.total_cap = cap; runtime.state.population.refill_time = interval;
    runtime.state.population.refill_ready = true;
    return true;
}

// 比較入口と実験場の切替。ラン内のボーナス・攻撃管理の移行後は、その状態から同じ値を更新する。
bool SpeedRunCore::set_population_mode(bool enabled, bool bonus, bool blocked) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.population.refill_ready) return false;
    runtime.state.population.frame_enabled = enabled; runtime.state.population.bonus = bonus; runtime.state.population.blocked = blocked;
    return true;
}

Dictionary SpeedRunCore::refill_snapshot() const {
    Dictionary out;
    if (runtime.state.closed || !runtime.state.population.refill_ready) return out;
    out["accumulator"] = runtime.state.population.accumulator;
    out["phase"] = runtime.state.population.phase_id;
    out["wave_time"] = runtime.state.population.wave_time;
    return out;
}

// 補充の比較入口。クリップ・攻撃予算の接続は別の更新段階で扱う。
bool SpeedRunCore::step_population(double world_dt, bool bonus) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.motion_ready || !runtime.state.population.refill_ready || !std::isfinite(world_dt) || world_dt < 0) return false;
    if (world_dt == 0) return true;
    const Dictionary target = spawn_target(runtime.state.time, bonus);
    if (target.is_empty()) return false;
    size_t phase_index = 0;
    while (phase_index + 1 < runtime.state.spawn_timeline.phases.size() && runtime.state.spawn_timeline.phases[phase_index + 1].start <= runtime.state.time) ++phase_index;
    const auto &current = runtime.state.spawn_timeline.phases[phase_index];
    auto &p = runtime.state.population;
    if (p.phase_id != current.id) {
        p.phase_id = current.id;
        Dictionary event; event["id"] = current.id; emit_event("phase", event);
    }
    const double desired = target["pop"];
    double alive = survey_population(desired);
    int64_t raw = p.raw;
    const double raw_limit = p.total_cap > 0 ? desired * p.total_cap : std::numeric_limits<double>::infinity();
    const double deficit = std::max(0.0, desired - alive);
    const double rate = std::max(current.rate * runtime.state.spawn_timeline.density, deficit / p.refill_time);
    const double cap = std::max(8.0, 8.0 * runtime.state.spawn_timeline.density);
    p.accumulator = std::min(p.accumulator + rate * world_dt, cap);
    const Dictionary surge = target["surge"];
    const bool by_shortage = target.has("per_type");
    const Dictionary per_type = target.get("per_type", Dictionary());
    const Array ids = per_type.keys();
    auto index_of = [&](StringName id) -> size_t {
        return std::find_if(runtime.content->definitions.begin(), runtime.content->definitions.end(), [&](const auto &d) { return d.id == id; }) - runtime.content->definitions.begin();
    };
    for (int64_t attempts = 0; p.accumulator >= 1.0 && alive < desired && raw < raw_limit && attempts < cap; ++attempts) {
        p.accumulator -= 1.0;
        const Variant point = population_spawn_point(0.0);
        if (point.get_type() != Variant::VECTOR2) continue;
        std::vector<std::pair<size_t, double>> candidates;
        double total = 0;
        if (by_shortage) {
            for (int i = 0; i < ids.size(); ++i) {
                const size_t type = index_of(ids[i]);
                if (type == runtime.content->definitions.size()) continue;
                const double shortage = double(per_type[ids[i]]) - p.effective[type];
                if (shortage > 0) { candidates.emplace_back(type, shortage); total += shortage; }
            }
        } else {
            for (const auto &entry : current.mix) {
                const size_t type = index_of(entry.first);
                if (type == runtime.content->definitions.size()) continue;
                const auto meta = std::find_if(runtime.state.spawn_timeline.types.begin(), runtime.state.spawn_timeline.types.end(), [&](const auto &t) { return t.id == entry.first; });
                double weight = entry.second;
                if (meta != runtime.state.spawn_timeline.types.end() && meta->ranged) weight *= 1.0 + double(surge["ranged"]);
                candidates.emplace_back(type, weight); total += weight;
            }
        }
        if (candidates.empty() || total <= 0) continue;
        double roll = runtime.state.control.rng.randf() * total;
        size_t selected = candidates.back().first;
        for (const auto &entry : candidates) {
            if (by_shortage) { roll -= entry.second; if (roll < 0) { selected = entry.first; break; } }
            else { if (roll < entry.second) { selected = entry.first; break; } roll -= entry.second; }
        }
        if (p.maximum[selected] > 0 && p.type_counts[selected] >= p.maximum[selected]) continue;
        const auto &definition = runtime.content->definitions[selected];
        Dictionary options;options["spawn_origin"]=int64_t(speed::SpawnOrigin::Refill);
        options["elite"] = p.maximum[selected] == 0 && runtime.state.control.rng.randf() < 0.01 + double(surge["elite"]);
        options["facing"] = (runtime.state.ship_pos - Vector2(point)).angle();
        if (definition.size_var) options["size"] = definition.scaling.radius * (0.85 + runtime.state.control.rng.randf() * 0.45);
        const size_t before = runtime.state.rows_by_id.size();
        if (spawn_enemy(definition.id, point, options) < 0) return false;
        if (p.maximum[selected] > 0) ++p.type_counts[selected];
        p.effective[selected] += 1.0;
        if (runtime.state.rows_by_id.size() - before > 1) { alive = survey_population(desired); raw = p.raw; }
        else { alive += 1.0; ++raw; }
    }
    if (!bonus && current.wave_interval > 0) {
        p.wave_time += world_dt;
        if (p.wave_time >= current.wave_interval) {
            p.wave_time = 0;
            if (alive < desired && raw < raw_limit) {
                const double remaining = std::min(desired - alive, raw_limit - raw);
                const int64_t count = int64_t(std::min(std::round(30.0 * runtime.state.spawn_timeline.density), std::ceil(remaining)));
                const size_t type = index_of(current.wave_type);
                if (type != runtime.content->definitions.size()) {
                    const size_t before = runtime.state.rows_by_id.size();
                    const bool ring = runtime.state.control.rng.randf() < 0.5;
                    if (ring) {
                        for (int64_t k = 0; k < count; ++k) {
                            if (double(runtime.state.rows_by_id.size() - before) >= remaining) break;
                            const double angle = (double(k) + double(runtime.state.control.rng.randf())) / double(count) * (2.0 * godot::Math::PI);
                            const Vector2 unit(std::cos(angle), std::sin(angle));
                            const double distance = std::min((runtime.state.view_half.x + p.margin) / std::max(0.0001, std::abs(double(unit.x))),
                                (runtime.state.view_half.y + p.margin) / std::max(0.0001, std::abs(double(unit.y)))) + runtime.state.control.rng.randf() * 90.0;
                            Dictionary options; options["facing"] = angle + godot::Math::PI;
                            if (spawn_enemy(current.wave_type, runtime.state.view_center + unit * distance, options) < 0) return false;
                        }
                    } else {
                        const double angle = runtime.state.control.rng.randf() * (2.0 * godot::Math::PI);
                        const Vector2 unit(std::cos(angle), std::sin(angle));
                        for (int64_t k = 0; k < count; ++k) {
                            if (double(runtime.state.rows_by_id.size() - before) >= remaining) break;
                            const double distance = std::min(runtime.state.view_half.x / std::max(0.0001, std::abs(double(unit.x))),
                                runtime.state.view_half.y / std::max(0.0001, std::abs(double(unit.y)))) + p.margin + k * 12.0;
                            const double offset = (runtime.state.control.rng.randf() - 0.5) * 120.0;
                            Dictionary options; options["facing"] = angle + godot::Math::PI;
                            if (spawn_enemy(current.wave_type, runtime.state.ship_pos + unit * distance + Vector2(-unit.y,unit.x) * offset, options) < 0) return false;
                        }
                    }
                    emit_event("wave", Dictionary());
                }
            }
        }
    }
    if (!bonus && runtime.state.clips_ready) return step_clips();
    return true;
}
