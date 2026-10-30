#include "run_core.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

bool SpeedRunCore::configure_population(const Dictionary &config) {
    if (started || closed || !spawn_timeline_ready) return false;
    Population parsed;
    const char *keys[] = {"spawn_recycle_scale", "spawn_region_cap", "spawn_margin", "field_radius", "planet_radius"};
    double *values[] = {&parsed.recycle_scale, &parsed.region_cap, &parsed.margin, &parsed.field_radius, &parsed.planet_radius};
    for (int i = 0; i < 5; ++i) {
        const Variant value = config.get(keys[i], Variant());
        if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value)) || double(value) < 0) return false;
        *values[i] = value;
    }
    for (const auto &definition : definitions) {
        const auto found = std::find_if(spawn_timeline.types.begin(), spawn_timeline.types.end(), [&](const auto &type) { return type.id == definition.id; });
        if (found == spawn_timeline.types.end()) return false;
        parsed.maximum.push_back(found->maximum);
    }
    parsed.type_counts.resize(definitions.size()); parsed.effective.resize(definitions.size());
    parsed.region_types.resize(definitions.size() * 5);
    parsed.ready = true; population = std::move(parsed);
    return true;
}

Variant SpeedRunCore::population_spawn_point(double extra) {
    if (!started || closed || !motion_ready || !population.ready || !std::isfinite(extra)) return Variant();
    auto &p = population;
    for (int attempt = 0; attempt < 24; ++attempt) {
        double weights[4], total = 0;
        for (int edge = 0; edge < 4; ++edge) {
            weights[edge] = double(edge < 2 ? view_half.y : view_half.x) / (p.edges[edge] + 8);
            total += weights[edge];
        }
        double roll = rng->randf() * total;
        int side = 0;
        while (side < 3 && roll >= weights[side]) { roll -= weights[side]; ++side; }
        const double margin = p.margin + extra + rng->randf() * 80.0;
        const double along = rng->randf() * 2.0 - 1.0;
        Vector2 point = view_center;
        if (side < 2) point += Vector2((side == 0 ? -1.0 : 1.0) * (view_half.x + margin), along * view_half.y);
        else point += Vector2(along * view_half.x, (side == 2 ? -1.0 : 1.0) * (view_half.y + margin));
        const double radius = point.length();
        if (radius < p.field_radius + 200.0 && radius > p.planet_radius + 150.0) {
            ++p.edges[side]; return point;
        }
    }
    return Variant();
}

double SpeedRunCore::survey_population(double target) {
    if (!started || closed || !motion_ready || !population.ready || !std::isfinite(target) || population.maximum.size() != definitions.size()) return std::numeric_limits<double>::quiet_NaN();
    auto &p = population;
    p.edges.fill(0); p.regions.fill(0); p.raw = 0; p.far_rows.clear();
    std::fill(p.type_counts.begin(), p.type_counts.end(), 0);
    std::fill(p.effective.begin(), p.effective.end(), 0);
    std::fill(p.region_types.begin(), p.region_types.end(), 0);
    const Vector2 limit = view_half * p.recycle_scale + Vector2(200,200);
    const double center_x = view_half.x * 0.45, center_y = view_half.y * 0.45;
    std::unordered_set<size_t> entering;
    const Rect2 view(view_center - view_half, view_half * 2.0);
    for (auto &clip : clips) for (auto &group : clip.groups) {
        if (group.arrived) continue;
        for (const auto &member : group.members) {
            if (member.first >= enemies.size()) continue;
            const auto &enemy = enemies[member.first];
            if (enemy.alive && enemy.id == member.second && view.has_point(enemy.pos)) { group.arrived = true; break; }
        }
        if (!group.arrived) for (const auto &member : group.members) entering.insert(member.first);
    }
    for (const auto &rows : behavior_rows) for (size_t row : rows) {
        const auto &enemy = enemies[row];
        if (enemy.dead) continue;
        if (p.maximum[enemy.definition] > 0) ++p.type_counts[enemy.definition];
        const Vector2 relative = enemy.pos - view_center;
        const double x = std::abs(relative.x), y = std::abs(relative.y);
        if (x > limit.x || y > limit.y) { if (entering.find(row) == entering.end()) p.far_rows.push_back(row); continue; }
        int region = 4;
        if (x >= center_x || y >= center_y) {
            region = x * view_half.y > y * view_half.x ? (relative.x < 0 ? 0 : 1) : (relative.y < 0 ? 2 : 3);
            ++p.edges[region];
        }
        ++p.regions[region]; ++p.region_types[region * definitions.size() + enemy.definition];
    }
    const double cap = target > 0 && p.region_cap > 0 ? target * p.region_cap : std::numeric_limits<double>::infinity();
    double effective = 0;
    for (int region = 0; region < 5; ++region) {
        const int64_t count = p.regions[region];
        p.raw += count;
        if (count == 0) continue;
        const double keep = std::min(1.0, cap / count);
        effective += count * keep;
        for (size_t type = 0; type < definitions.size(); ++type) p.effective[type] += p.region_types[region * definitions.size() + type] * keep;
    }
    // 代表経路の追跡・盾は、群れ・親子・牽引のない通常個体として再配置する。
    for (size_t row : p.far_rows) {
        const Variant sampled = population_spawn_point(0.0);
        if (sampled.get_type() != Variant::VECTOR2) continue;
        auto &enemy = enemies[row];
        enemy.pos = sampled;
        const Vector2 toward = (ship_pos - enemy.pos).normalized();
        enemy.vel = toward * enemy.speed; enemy.facing = toward.angle();
        enemy.fire_t = definitions[enemy.definition].fire_interval;
        effective += 1.0; ++p.raw;
    }
    return effective;
}

Dictionary SpeedRunCore::population_snapshot() const {
    Dictionary out;
    if (!population.ready || closed) return out;
    Array edges;
    for (int64_t count : population.edges) edges.append(count);
    Dictionary counts, effective;
    for (size_t type = 0; type < definitions.size(); ++type) {
        const StringName id = definitions[type].id;
        if (population.type_counts[type] > 0) counts[id] = population.type_counts[type];
        bool present = false;
        for (int region = 0; region < 5; ++region) present = present || population.region_types[region * definitions.size() + type] > 0;
        if (present) effective[id] = population.effective[type];
    }
    out["raw"] = population.raw; out["edges"] = edges; out["type_counts"] = counts; out["per_type"] = effective;
    return out;
}
