#include "run_core.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

namespace {
bool number(const Variant &value, double &out) {
    if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
    out = value;
    return std::isfinite(out);
}
bool name(const Variant &value, StringName &out) {
    if (value.get_type() != Variant::STRING && value.get_type() != Variant::STRING_NAME) return false;
    out = value;
    return !String(out).is_empty();
}
bool weights(const Dictionary &source, std::vector<std::pair<StringName, double>> &out) {
    const Array keys = source.keys();
    for (int i = 0; i < keys.size(); ++i) {
        StringName id; double weight;
        if (!name(keys[i], id) || !number(source[keys[i]], weight)) return false;
        out.emplace_back(id, weight);
    }
    return true;
}
double sample(const speed::SpawnTimeline::Curve &curve, double at) {
    const auto &points = curve.points;
    if (points.empty()) return 0;
    if (points.size() == 1 || at <= points.front().time) return points.front().value;
    if (at >= points.back().time) return points.back().value;
    size_t k = 0;
    while (k < points.size() - 2 && at > points[k + 1].time) ++k;
    const auto &p = points[k]; const auto &q = points[k + 1];
    const double h = std::max(q.time - p.time, 0.0001), s = (at - p.time) / h, s2 = s * s, s3 = s2 * s;
    return (2*s3 - 3*s2 + 1)*p.value + (s3 - 2*s2 + s)*h*p.slope + (-2*s3 + 3*s2)*q.value + (s3 - s2)*h*q.slope;
}
}

bool SpeedRunCore::configure_spawn_timeline(const Dictionary &data) {
    if (started || closed) return false;
    speed::SpawnTimeline parsed;
    double version;
    if (!number(data.get("version", Variant()), version) || version != 2) return false;
    if (!number(data.get("boss_start", Variant()), parsed.boss_start) || !number(data.get("density", Variant()), parsed.density) || !number(data.get("bonus_pop", Variant()), parsed.bonus_pop)) return false;
    if (parsed.density < 0 || parsed.bonus_pop < 0) return false;
    for (const char *key : {"phases", "curves", "windows"}) if (data.get(key, Variant()).get_type() != Variant::ARRAY) return false;
    const Array phases = data["phases"];
    if (phases.is_empty()) return false;
    for (int i = 0; i < phases.size(); ++i) {
        if (phases[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = phases[i];
        speed::SpawnTimeline::Phase phase;
        if (!name(row.get("id", Variant()), phase.id)) return false;
        const char *keys[] = {"start", "pop_from", "pop_to", "rate", "xp_bonus", "surge_interval", "surge_pop", "surge_ranged", "surge_elite"};
        double *values[] = {&phase.start, &phase.pop_from, &phase.pop_to, &phase.rate, &phase.xp_bonus, &phase.interval, &phase.pop, &phase.ranged, &phase.elite};
        for (int k = 0; k < 9; ++k) if (!number(row.get(keys[k], Variant()), *values[k])) return false;
        if (!number(row.get("wave_interval", Variant()), phase.wave_interval)) return false;
        const Variant wave_type = row.get("wave_type", Variant());
        if (wave_type.get_type() != Variant::STRING && wave_type.get_type() != Variant::STRING_NAME) return false;
        phase.wave_type = wave_type;
        if (i > 0 && phase.start < parsed.phases.back().start) return false;
        double budget;
        if (!number(row.get("attack_budget", Variant()), budget) || budget < 0 || budget > INT32_MAX || std::floor(budget) != budget) return false;
        phase.budget = int64_t(budget);
        if (row.get("mix", Variant()).get_type() != Variant::DICTIONARY || !weights(row["mix"], phase.mix)) return false;
        parsed.phases.push_back(std::move(phase));
    }
    const Array curves = data["curves"];
    for (int i = 0; i < curves.size(); ++i) {
        if (curves[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = curves[i];
        speed::SpawnTimeline::Curve curve;
        if (!name(row.get("type", Variant()), curve.type) || row.get("points", Variant()).get_type() != Variant::ARRAY) return false;
        const Array points = row["points"];
        for (int k = 0; k < points.size(); ++k) {
            if (points[k].get_type() != Variant::ARRAY) return false;
            const Array point = points[k]; speed::SpawnTimeline::Point p;
            if (point.size() != 3 || !number(point[0], p.time) || !number(point[1], p.value) || !number(point[2], p.slope)) return false;
            if (k > 0 && p.time < curve.points.back().time) return false;
            curve.points.push_back(p);
        }
        parsed.curves.push_back(std::move(curve));
    }
    const Array windows = data["windows"];
    for (int i = 0; i < windows.size(); ++i) {
        if (windows[i].get_type() != Variant::ARRAY) return false;
        const Array window = windows[i]; double from, to;
        if (window.size() != 2 || !number(window[0], from) || !number(window[1], to) || (to != -1 && to < from)) return false;
        parsed.windows.emplace_back(from, to == -1 ? std::numeric_limits<double>::infinity() : to);
    }
    if (data.get("types", Variant()).get_type() != Variant::DICTIONARY) return false;
    const Dictionary types = data["types"]; const Array ids = types.keys();
    for (int i = 0; i < ids.size(); ++i) {
        speed::SpawnTimeline::Type type;
        if (!name(ids[i], type.id) || types[ids[i]].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = types[ids[i]];
        if (!number(row.get("rank", Variant()), type.rank) || !number(row.get("max_alive", Variant()), type.maximum) || row.get("ranged", Variant()).get_type() != Variant::BOOL) return false;
        type.ranged = row["ranged"]; parsed.types.push_back(type);
    }
    spawn_timeline = std::move(parsed); spawn_timeline_ready = true;
    population = Population();
    return true;
}

Dictionary SpeedRunCore::spawn_target(double at, bool bonus) const {
    Dictionary out;
    if (!started || closed || !spawn_timeline_ready || !std::isfinite(at) || at < 0) return out;
    const auto &timeline = spawn_timeline;
    size_t n = 0;
    for (size_t k = 1; k < timeline.phases.size(); ++k) {
        if (timeline.phases[k].start > at) break;
        n = k;
    }
    const auto &phase = timeline.phases[n];
    const auto finish = [&](size_t k) { return k + 1 < timeline.phases.size() ? timeline.phases[k + 1].start : std::numeric_limits<double>::infinity(); };
    int64_t steps = 0;
    double progress = 0, pop = 0, ranged = 0, elite = 0;
    bool begun = false;
    const auto add = [&](const speed::SpawnTimeline::Phase &p, int64_t count) {
        steps += count; pop += double(count) * p.pop; ranged += double(count) * p.ranged; elite += double(count) * p.elite;
    };
    for (const auto &window : timeline.windows) {
        if (at < window.first) break;
        for (size_t k = 0; k < timeline.phases.size(); ++k) {
            const auto &p = timeline.phases[k];
            const double end = finish(k), from = std::max(window.first, k > 0 ? p.start : 0.0), to = std::min(at, std::min(window.second, end));
            if (from >= end || to < from) continue;
            if (!begun) { begun = true; add(p, 1); }
            progress += std::max(0.0, to - from) / std::max(1.0, p.interval);
            const double whole = std::floor(progress + 1e-9);
            if (whole >= double(INT64_MAX - steps)) return Dictionary();
            const int64_t count = int64_t(whole);
            if (count > 0) { add(p, count); progress -= count; }
        }
    }
    Dictionary surge; surge["steps"] = steps; surge["pop"] = pop; surge["ranged"] = ranged; surge["elite"] = elite;
    out["phase"] = String(phase.id); out["surge"] = surge; out["rate"] = phase.rate;
    out["xp_bonus"] = phase.xp_bonus; out["attack_budget"] = phase.budget;
    Dictionary per;
    double total = 0;
    if (!timeline.curves.empty()) {
        for (const auto &curve : timeline.curves) {
            const double value = std::max(0.0, sample(curve, at)) * (bonus ? 1.0 : 1.0 + pop);
            per[curve.type] = double(per.get(curve.type, 0.0)) + value;
            total += value;
        }
    } else if (bonus) {
        for (const auto &entry : phase.mix) per[entry.first] = entry.second;
    }
    if (bonus) {
        Dictionary allowed; total = 0;
        const Array ids = per.keys();
        for (int i = 0; i < ids.size(); ++i) {
            const StringName id = ids[i];
            const auto found = std::find_if(timeline.types.begin(), timeline.types.end(), [&](const auto &t) { return t.id == id; });
            if (found == timeline.types.end() || found->maximum > 0 || found->rank > 2) continue;
            double weight = std::max(0.0, double(per[ids[i]]));
            if (timeline.curves.empty() && found->ranged) weight *= 1.0 + ranged;
            if (weight <= 0) continue;
            allowed[id] = weight; total += weight;
        }
        const double target = total > 0 ? timeline.bonus_pop * timeline.density : 0;
        const Array allowed_ids = allowed.keys();
        for (int i = 0; i < allowed_ids.size(); ++i) allowed[allowed_ids[i]] = double(allowed[allowed_ids[i]]) * target / total;
        out["per_type"] = allowed; out["pop"] = target;
    } else if (!timeline.curves.empty()) {
        out["per_type"] = per; out["pop"] = total;
    } else {
        const double end = n + 1 < timeline.phases.size() ? finish(n) : timeline.boss_start;
        const double fraction = std::clamp((at - phase.start) / std::max(0.001, end - phase.start), 0.0, 1.0);
        out["pop"] = (phase.pop_from + (phase.pop_to - phase.pop_from) * fraction) * (timeline.density * (1.0 + pop));
    }
    return out;
}
