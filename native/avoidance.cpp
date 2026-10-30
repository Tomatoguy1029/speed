#include "run_core.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

bool SpeedRunCore::can_avoid_strong(size_t row) const {
    const auto &e = enemies[row];
    // 部位・ボス・吸引の状態は各経路の移行時にここへ接続する。
    return e.alive && !e.dead && definitions[e.definition].rank <= 2 && e.mode == EnemyMode::Move &&
        !e.held && e.stone <= 0 && e.shove_time <= 0 && e.knock_t <= 0;
}
void SpeedRunCore::capture_avoidance() {
    avoidance_ids.resize(enemies.size()); avoidance_from.resize(enemies.size());
    for (size_t row = 0; row < enemies.size(); ++row) {
        avoidance_ids[row] = can_avoid_strong(row) ? enemies[row].id : -1;
        if (avoidance_ids[row] >= 0) avoidance_from[row] = enemies[row].pos;
    }
}
double SpeedRunCore::avoidance_clearance(Vector2 point, size_t row, const std::vector<size_t> &candidates) const {
    double gap = std::numeric_limits<double>::infinity();
    for (size_t other : candidates) gap = std::min(gap, double(point.distance_to(enemies[other].pos)) - enemies[row].radius - enemies[other].radius - 2.0);
    return gap;
}
bool SpeedRunCore::avoid_strong(double dt) {
    if (!started || closed || !std::isfinite(dt) || dt < 0) return false;
    if (dt == 0) return true;
    std::vector<size_t> obstacles;
    HashMap<Vector2i, std::vector<size_t>> cells;
    double normal_radius = 0, normal_step = 0;
    for (size_t row = 0; row < enemies.size(); ++row) {
        const auto &e = enemies[row];
        if (!e.alive || e.dead || e.held) continue;
        if (definitions[e.definition].rank >= 3) obstacles.push_back(row);
        else if (row < avoidance_ids.size() && avoidance_ids[row] == e.id && can_avoid_strong(row)) {
            normal_radius = std::max(normal_radius, e.radius); normal_step = std::max(normal_step, e.speed * dt);
        }
    }
    if (obstacles.empty() || normal_radius <= 0) return true;
    constexpr double cell_size = 160.0;
    auto cell_of = [](Vector2 p) { return Vector2i(int32_t(std::floor(p.x / cell_size)), int32_t(std::floor(p.y / cell_size))); };
    for (size_t row : obstacles) {
        const auto &e = enemies[row]; const double extent = e.radius + normal_radius + normal_step + 2.0;
        // GDScriptは減算をdoubleで行ってからセル座標を作る。
        const Vector2i lo(int32_t(std::floor((double(e.pos.x)-extent)/cell_size)),int32_t(std::floor((double(e.pos.y)-extent)/cell_size)));
        const Vector2i hi(int32_t(std::floor((double(e.pos.x)+extent)/cell_size)),int32_t(std::floor((double(e.pos.y)+extent)/cell_size)));
        for (int64_t y = lo.y; y <= hi.y; ++y) for (int64_t x = lo.x; x <= hi.x; ++x) cells[Vector2i(x,y)].push_back(row);
    }
    for (size_t row = 0; row < std::min(avoidance_ids.size(), enemies.size()); ++row) {
        auto &e = enemies[row];
        if (avoidance_ids[row] != e.id || !can_avoid_strong(row)) continue;
        const Vector2 from = avoidance_from[row];
        const auto *candidates = cells.getptr(cell_of(from)); if (!candidates) continue;
        const Vector2 intended = e.pos - from; const double limit = e.speed * dt;
        if (limit <= 0 || intended.length() > limit + 0.01) continue;
        Vector2 inside, fallback; double most_inside = -1, near_depth = 0; int64_t near_row = -1;
        for (size_t other : *candidates) {
            if (other == row) continue;
            const auto &obstacle = enemies[other]; const double radius = e.radius + obstacle.radius + 2.0;
            const Vector2 offset = from - obstacle.pos; const double distance_sq = offset.length_squared(); const double reach = radius + limit;
            if (distance_sq > reach * reach) continue;
            if (distance_sq < radius * radius) {
                const double distance = std::sqrt(distance_sq);
                const Vector2 normal = distance > 0.001 ? offset / distance : Vector2::from_angle(double((e.id * 17 + obstacle.id * 31) % 360) * Math_PI / 180.0);
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
            const Vector2 radial = (from - enemies[near_row].pos).normalized();
            corrected -= radial * std::min(0.0, double(corrected.dot(radial)));
            if (corrected.length_squared() < 0.000001) {
                const double side = (e.id + enemies[near_row].id) % 2 == 0 ? 1.0 : -1.0;
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
