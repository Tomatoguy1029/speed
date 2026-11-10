#include "../api/run_core.h"
#include "../content/content_bundle.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
using namespace godot;

bool SpeedRunCore::can_avoid_strong(size_t row) const {
    const auto &e = runtime.state.enemies[row];
    // ボス本体は専用の移動を使い、通常敵の押し合いでは動かさない。
    return e.alive && !e.dead && !e.is_boss && !runtime.state.field.rock_handles.contains(e.rock) && runtime.content->definitions[e.definition].rank <= 2 && e.mode == EnemyMode::Move &&
        !e.held && e.stone <= 0 && e.shove_time <= 0 && e.knock_t <= 0;
}
void SpeedRunCore::capture_avoidance() {
    runtime.workspace.avoidance_ids.resize(runtime.state.enemies.size()); runtime.workspace.avoidance_from.resize(runtime.state.enemies.size());
    for (size_t row = 0; row < runtime.state.enemies.size(); ++row) {
        runtime.workspace.avoidance_ids[row] = can_avoid_strong(row) ? runtime.state.enemies[row].id : -1;
        if (runtime.workspace.avoidance_ids[row] >= 0) runtime.workspace.avoidance_from[row] = runtime.state.enemies[row].pos;
    }
}
double SpeedRunCore::avoidance_clearance(Vector2 point, size_t row, const std::vector<size_t> &candidates) const {
    double gap = std::numeric_limits<double>::infinity();
    for (size_t other : candidates) gap = std::min(gap, double(point.distance_to(runtime.state.enemies[other].pos)) - runtime.state.enemies[row].radius - runtime.state.enemies[other].radius - 2.0);
    return gap;
}
bool SpeedRunCore::avoid_strong(double dt) {
    if (!runtime.state.started || runtime.state.closed || !std::isfinite(dt) || dt < 0) return false;
    if (dt == 0) return true;
    std::vector<size_t> obstacles;
    HashMap<Vector2i, std::vector<size_t>> cells;
    double normal_radius = 0, normal_step = 0;
    for (size_t row = 0; row < runtime.state.enemies.size(); ++row) {
        const auto &e = runtime.state.enemies[row];
        if (!e.alive || e.dead || e.held) continue;
        if (runtime.content->definitions[e.definition].rank >= 3) obstacles.push_back(row);
        else if (row < runtime.workspace.avoidance_ids.size() && runtime.workspace.avoidance_ids[row] == e.id && can_avoid_strong(row)) {
            normal_radius = std::max(normal_radius, e.radius); normal_step = std::max(normal_step, e.speed * dt);
        }
    }
    if (obstacles.empty() || normal_radius <= 0) return true;
    constexpr double cell_size = 160.0;
    auto cell_of = [cell_size](Vector2 p) { return Vector2i(int32_t(std::floor(p.x / cell_size)), int32_t(std::floor(p.y / cell_size))); };
    for (size_t row : obstacles) {
        const auto &e = runtime.state.enemies[row]; const double extent = e.radius + normal_radius + normal_step + 2.0;
        // GDScriptは減算をdoubleで行ってからセル座標を作る。
        const Vector2i lo(int32_t(std::floor((double(e.pos.x)-extent)/cell_size)),int32_t(std::floor((double(e.pos.y)-extent)/cell_size)));
        const Vector2i hi(int32_t(std::floor((double(e.pos.x)+extent)/cell_size)),int32_t(std::floor((double(e.pos.y)+extent)/cell_size)));
        for (int64_t y = lo.y; y <= hi.y; ++y) for (int64_t x = lo.x; x <= hi.x; ++x) cells[Vector2i(x,y)].push_back(row);
    }
    for (size_t row = 0; row < std::min(runtime.workspace.avoidance_ids.size(), runtime.state.enemies.size()); ++row) {
        auto &e = runtime.state.enemies[row];
        if (runtime.workspace.avoidance_ids[row] != e.id || !can_avoid_strong(row)) continue;
        const Vector2 from = runtime.workspace.avoidance_from[row];
        const auto *candidates = cells.getptr(cell_of(from)); if (!candidates) continue;
        const Vector2 intended = e.pos - from; const double limit = e.speed * dt;
        if (limit <= 0 || intended.length() > limit + 0.01) continue;
        Vector2 inside, fallback; double most_inside = -1, near_depth = 0; int64_t near_row = -1;
        for (size_t other : *candidates) {
            if (other == row) continue;
            const auto &obstacle = runtime.state.enemies[other]; const double radius = e.radius + obstacle.radius + 2.0;
            const Vector2 offset = from - obstacle.pos; const double distance_sq = offset.length_squared(); const double reach = radius + limit;
            if (distance_sq > reach * reach) continue;
            if (distance_sq < radius * radius) {
                const double distance = std::sqrt(distance_sq);
                const Vector2 normal = distance > 0.001 ? offset / distance : Vector2::from_angle(double((e.id * 17 + obstacle.id * 31) % 360) * godot::Math::PI / 180.0);
                const double depth = radius - distance; inside += normal * depth;
                if (depth > most_inside) { most_inside = depth; fallback = normal; }
                continue;
            }
            const double next_distance = (from + intended).distance_to(obstacle.pos);
            if (next_distance < radius && radius - next_distance > near_depth) { near_depth = radius - next_distance; near_row = other; }
        }
        Vector2 corrected = intended;
        if (most_inside > 0) {
            Vector2 outward = inside.length_squared() > 0.000001 ? inside.normalized() : fallback;
            const Vector2 tangent = outward.orthogonal(); const double side = e.id % 2 == 0 ? 1.0 : -1.0;
            double best = avoidance_clearance(from + outward * limit, row, *candidates);
            for (Vector2 direction : {tangent * side, tangent * -side, -outward}) {
                const double score = avoidance_clearance(from + direction * limit, row, *candidates);
                if (score > best + 0.0001) { best = score; outward = direction; }
            }
            corrected = outward * limit;
        } else if (near_row >= 0) {
            const Vector2 radial = (from - runtime.state.enemies[near_row].pos).normalized();
            corrected -= radial * std::min(0.0, double(corrected.dot(radial)));
            if (corrected.length_squared() < 0.000001) {
                const double side = (e.id + runtime.state.enemies[near_row].id) % 2 == 0 ? 1.0 : -1.0;
                corrected = radial.orthogonal() * side * intended.length();
            } else corrected = corrected.normalized() * intended.length();
        }
        if (!corrected.is_equal_approx(intended)) {
            if (most_inside <= 0 && avoidance_clearance(from + corrected, row, *candidates) < 0) {
                const Vector2 side = corrected.orthogonal().normalized() * intended.length(), opposite = -side;
                if (avoidance_clearance(from + side, row, *candidates) >= 0) corrected = side;
                else if (avoidance_clearance(from + opposite, row, *candidates) >= 0) corrected = opposite;
                else corrected = Vector2();
            }
            e.pos = from + corrected; e.vel = corrected / dt;
        }
    }
    return true;
}

// 雑魚同士のゆるい押し合い。群れの中でも個体の形が読めるよう、重なりすぎた分の一部だけ毎回位置を戻す。
// 半径の和の CROWD_ALLOW 倍までは重なってよく、それより近いと重さ（半径の2乗）の比で押し合う。
// 移動中でない雑魚は動かない相手として扱う。強敵・ボスは対象外で、雑魚は avoid_strong で回り込む。
// 細かい格子の周り9マスだけを見て、1体が押される相手は CROWD_NEIGHBORS 体までにする。
bool SpeedRunCore::separate_crowd(double dt) {
    if (!runtime.state.started || runtime.state.closed || !std::isfinite(dt) || dt < 0) return false;
    if (dt == 0) return true;
    constexpr double CROWD_ALLOW = 0.7, CROWD_STRENGTH = 0.1, CROWD_REFERENCE_DT = 1.0 / 60.0;
    constexpr int CROWD_NEIGHBORS = 8;
    auto &state = runtime.state; auto &cells = runtime.workspace.crowd_cells; auto &shift = runtime.workspace.crowd_shift;
    cells.clear();
    double cell_size = 0;
    for (size_t row = 0; row < state.enemies.size(); ++row) {
        const auto &e = state.enemies[row];
        if (!e.alive || e.dead || e.is_boss || runtime.content->definitions[e.definition].rank > 2 || e.radius <= 0) continue;
        cell_size = std::max(cell_size, 2.0 * e.radius * CROWD_ALLOW);
        cells.emplace_back(0, uint32_t(row));
    }
    if (cells.size() < 2 || cell_size <= 0) return true;
    auto cell_key = [cell_size](Vector2 p, int64_t dx, int64_t dy) {
        return ((int64_t(std::floor(p.x / cell_size)) + dx) << 32) ^ ((int64_t(std::floor(p.y / cell_size)) + dy) & 0xffffffffLL);
    };
    // 押し出す位置は最後に反映するので、この計算中の移動可否は変わらない。
    auto &movable = runtime.workspace.crowd_movable;
    movable.assign(state.enemies.size(),0);
    for (auto &entry : cells) {
        entry.first = cell_key(state.enemies[entry.second].pos, 0, 0);
        movable[entry.second] = can_avoid_strong(entry.second);
    }
    std::sort(cells.begin(), cells.end());
    shift.assign(state.enemies.size(), Vector2());
    // 基準の1/60秒あたり CROWD_STRENGTH の割合で戻す。更新間隔が変わっても同じ速さで離れる。
    const double rate = 1.0 - std::pow(1.0 - CROWD_STRENGTH, dt / CROWD_REFERENCE_DT);
    // 同じセルの個体は、同じ順序の近傍9セルを調べる。開始位置だけを共有する。
    std::array<decltype(cells.cbegin()),9> neighbor_begins;
    std::array<int64_t,9> neighbor_keys;
    bool neighbors_ready = false;
    int64_t neighbor_cell = 0;
    for (const auto &entry : cells) {
        const size_t row = entry.second;
        if (!movable[row]) continue;
        const auto &e = state.enemies[row]; const double weight = e.radius * e.radius;
        if (!neighbors_ready || neighbor_cell!=entry.first) {
            neighbor_cell = entry.first;
            neighbors_ready = true;
            int neighbor = 0;
            for (int64_t dy = -1; dy <= 1; ++dy) for (int64_t dx = -1; dx <= 1; ++dx) {
                const int64_t key = cell_key(e.pos, dx, dy);
                neighbor_keys[neighbor] = key;
                neighbor_begins[neighbor] = std::lower_bound(cells.cbegin(),cells.cend(),std::make_pair(key,uint32_t(0)));
                ++neighbor;
            }
        }
        int seen = 0;
        for (int neighbor = 0; neighbor < 9 && seen < CROWD_NEIGHBORS; ++neighbor) {
            const int64_t key = neighbor_keys[neighbor];
            for (auto it = neighbor_begins[neighbor]; it != cells.cend() && it->first == key && seen < CROWD_NEIGHBORS; ++it) {
                if (it->second == row) continue;
                const auto &other = state.enemies[it->second];
                const double reach = (e.radius + other.radius) * CROWD_ALLOW;
                Vector2 offset = e.pos - other.pos; double distance = offset.length();
                if (distance >= reach) continue;
                ++seen;
                if (distance < 0.001) { offset = Vector2::from_angle(double((e.id * 17 + other.id * 31) % 360) * godot::Math::PI / 180.0); distance = 1.0; }
                const double share = movable[it->second] ? other.radius * other.radius / (weight + other.radius * other.radius) : 1.0;
                shift[row] += offset / distance * ((reach - distance) * share * rate);
            }
        }
    }
    for (const auto &entry : cells) state.enemies[entry.second].pos += shift[entry.second];
    return true;
}
