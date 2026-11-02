#include "run_core.h"
#include "../cpp/systems/attack_system.h"
#include "../cpp/systems/enemy_system.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

bool SpeedRunCore::configure_population(const Dictionary &config) {
    if (runtime.state.started || runtime.state.closed || !runtime.state.spawn_timeline_ready) return false;
    Population parsed;
    const char *keys[] = {"spawn_recycle_scale", "spawn_region_cap", "spawn_margin", "field_radius", "planet_radius"};
    double *values[] = {&parsed.recycle_scale, &parsed.region_cap, &parsed.margin, &parsed.field_radius, &parsed.planet_radius};
    for (int i = 0; i < 5; ++i) {
        const Variant value = config.get(keys[i], Variant());
        if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value)) || double(value) < 0) return false;
        *values[i] = value;
    }
    for (const auto &definition : runtime.content->definitions) {
        const auto found = std::find_if(runtime.state.spawn_timeline.types.begin(), runtime.state.spawn_timeline.types.end(), [&](const auto &type) { return type.id == definition.id; });
        if (found == runtime.state.spawn_timeline.types.end()) return false;
        parsed.maximum.push_back(found->maximum);
    }
    parsed.type_counts.resize(runtime.content->definitions.size()); parsed.effective.resize(runtime.content->definitions.size());
    parsed.region_types.resize(runtime.content->definitions.size() * 5);
    parsed.ready = true; runtime.state.population = std::move(parsed);
    return true;
}

Variant SpeedRunCore::population_spawn_point(double extra) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.motion_ready || !runtime.state.population.ready || !std::isfinite(extra)) return Variant();
    auto &p = runtime.state.population;
    for (int attempt = 0; attempt < 24; ++attempt) {
        double weights[4], total = 0;
        for (int edge = 0; edge < 4; ++edge) {
            weights[edge] = double(edge < 2 ? runtime.state.view_half.y : runtime.state.view_half.x) / (p.edges[edge] + 8);
            total += weights[edge];
        }
        double roll = runtime.state.control.rng.randf() * total;
        int side = 0;
        while (side < 3 && roll >= weights[side]) { roll -= weights[side]; ++side; }
        const double margin = p.margin + extra + runtime.state.control.rng.randf() * 80.0;
        const double along = runtime.state.control.rng.randf() * 2.0 - 1.0;
        Vector2 point = runtime.state.view_center;
        if (side < 2) point += Vector2((side == 0 ? -1.0 : 1.0) * (runtime.state.view_half.x + margin), along * runtime.state.view_half.y);
        else point += Vector2(along * runtime.state.view_half.x, (side == 2 ? -1.0 : 1.0) * (runtime.state.view_half.y + margin));
        const double radius = point.length();
        if (radius < p.field_radius + 200.0 && radius > p.planet_radius + 150.0) {
            ++p.edges[side]; return point;
        }
    }
    return Variant();
}

double SpeedRunCore::survey_population(double target) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.motion_ready || !runtime.state.population.ready || !std::isfinite(target) || runtime.state.population.maximum.size() != runtime.content->definitions.size()) return std::numeric_limits<double>::quiet_NaN();
    auto &p = runtime.state.population;
    p.edges.fill(0); p.regions.fill(0); p.raw = 0; p.far_rows.clear();
    std::fill(p.type_counts.begin(), p.type_counts.end(), 0);
    std::fill(p.effective.begin(), p.effective.end(), 0);
    std::fill(p.region_types.begin(), p.region_types.end(), 0);
    const Vector2 limit = runtime.state.view_half * p.recycle_scale + Vector2(200,200);
    const double center_x = runtime.state.view_half.x * 0.45, center_y = runtime.state.view_half.y * 0.45;
    std::unordered_set<size_t> entering;
    const Rect2 view(runtime.state.view_center - runtime.state.view_half, runtime.state.view_half * 2.0);
    for (auto &clip : runtime.state.clips) for (auto &group : clip.groups) {
        if (group.arrived) continue;
        for (const auto &member : group.members) {
            if (member.first >= runtime.state.enemies.size()) continue;
            const auto &enemy = runtime.state.enemies[member.first];
            if (enemy.alive && enemy.id == member.second && view.has_point(enemy.pos)) { group.arrived = true; break; }
        }
        if (!group.arrived) for (const auto &member:group.members) if (member.first<runtime.state.enemies.size() && runtime.state.enemies[member.first].alive && !runtime.state.enemies[member.first].dead && runtime.state.enemies[member.first].id==member.second) entering.insert(member.first);
    }
    for (const auto &rows : runtime.state.behavior_rows) for (size_t row : rows) {
        const auto &enemy = runtime.state.enemies[row];
        if (enemy.dead || enemy.is_boss || enemy.role==speed::SpawnRole::BossPart || runtime.state.field.rock_handles.contains(enemy.rock)) continue;
        if (p.maximum[enemy.definition] > 0) ++p.type_counts[enemy.definition];
        const Vector2 relative = enemy.pos - runtime.state.view_center;
        const double x = std::abs(relative.x), y = std::abs(relative.y);
        if (x > limit.x || y > limit.y) { if (!runtime.state.enemy_handles.contains(enemy.parent) && runtime.content->definitions[enemy.definition].kind!=speed::EnemyDefinition::Kind::Crow && runtime.content->definitions[enemy.definition].kind!=speed::EnemyDefinition::Kind::Phoenix && entering.find(row) == entering.end()) p.far_rows.push_back(row); continue; }
        int region = 4;
        if (x >= center_x || y >= center_y) {
            region = x * runtime.state.view_half.y > y * runtime.state.view_half.x ? (relative.x < 0 ? 0 : 1) : (relative.y < 0 ? 2 : 3);
            ++p.edges[region];
        }
        ++p.regions[region]; ++p.region_types[region * runtime.content->definitions.size() + enemy.definition];
    }
    const double cap = target > 0 && p.region_cap > 0 ? target * p.region_cap : std::numeric_limits<double>::infinity();
    double effective = 0;
    for (int region = 0; region < 5; ++region) {
        const int64_t count = p.regions[region];
        p.raw += count;
        if (count == 0) continue;
        const double keep = std::min(1.0, cap / count);
        effective += count * keep;
        for (size_t type = 0; type < runtime.content->definitions.size(); ++type) p.effective[type] += p.region_types[region * runtime.content->definitions.size() + type] * keep;
    }
    // 捕捉中の個体は位置も乱数も進めず、所有者の操作を保持する。
    for (size_t row : p.far_rows) {
        if (runtime.state.enemies[row].held) continue;
        const Variant sampled = population_spawn_point(0.0);
        if (sampled.get_type() != Variant::VECTOR2) continue;
        if (!speed::EnemySystem::relocate(runtime,runtime.state.enemy_handles.at(uint32_t(row)),sampled)) continue;
        effective += 1.0; ++p.raw;
    }
    return effective;
}

Dictionary SpeedRunCore::population_snapshot() const {
    Dictionary out;
    if (!runtime.state.population.ready || runtime.state.closed) return out;
    Array edges;
    for (int64_t count : runtime.state.population.edges) edges.append(count);
    Dictionary counts, effective;
    for (size_t type = 0; type < runtime.content->definitions.size(); ++type) {
        const StringName id = runtime.content->definitions[type].id;
        if (runtime.state.population.type_counts[type] > 0) counts[id] = runtime.state.population.type_counts[type];
        bool present = false;
        for (int region = 0; region < 5; ++region) present = present || runtime.state.population.region_types[region * runtime.content->definitions.size() + type] > 0;
        if (present) effective[id] = runtime.state.population.effective[type];
    }
    out["raw"] = runtime.state.population.raw; out["edges"] = edges; out["type_counts"] = counts; out["per_type"] = effective;
    return out;
}
