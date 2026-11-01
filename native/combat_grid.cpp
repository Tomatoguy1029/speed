#include "run_core.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

void SpeedRunCore::reset_enemy_bounds() {
    const float infinity = std::numeric_limits<float>::infinity();
    Vector2 lo(infinity, infinity), hi(-infinity, -infinity);
    for (const auto &enemy : runtime.state.enemies) {
        if (!enemy.alive || enemy.dead) continue;
        lo = lo.min(enemy.pos); hi = hi.max(enemy.pos);
    }
    runtime.state.grid.used.clear();
    if (lo.x == infinity) { runtime.state.grid.cols = runtime.state.grid.rows = 0; return; }
    runtime.state.grid.origin = lo - Vector2(runtime.state.grid.cell * 4.0, runtime.state.grid.cell * 4.0);
    runtime.state.grid.cols = int64_t((double(hi.x) - runtime.state.grid.origin.x) / runtime.state.grid.cell) + 5;
    runtime.state.grid.rows = int64_t((double(hi.y) - runtime.state.grid.origin.y) / runtime.state.grid.cell) + 5;
    runtime.state.grid.head.assign(runtime.state.grid.cols * runtime.state.grid.rows, -1);
}

bool SpeedRunCore::rebuild_enemy_grid(double cell_size) {
    if (!runtime.state.started || runtime.state.closed || !std::isfinite(cell_size) || cell_size <= 0) return false;
    runtime.state.grid.max_radius = 0;
    if (runtime.state.grid.next.size() < runtime.state.enemies.size()) runtime.state.grid.next.resize(runtime.state.enemies.size(), -1);
    if (runtime.state.grid.cols == 0 || runtime.state.grid.cell != cell_size) { runtime.state.grid.cell = cell_size; reset_enemy_bounds(); }
    if (runtime.state.grid.cols == 0) return true;
    for (auto cell : runtime.state.grid.used) runtime.state.grid.head[cell] = -1;
    runtime.state.grid.used.clear();
    for (size_t row = 0; row < runtime.state.enemies.size(); ++row) {
        const auto &enemy = runtime.state.enemies[row];
        if (!enemy.alive || enemy.dead) { runtime.state.grid.next[row] = -1; continue; }
        runtime.state.grid.max_radius = std::max(runtime.state.grid.max_radius, enemy.radius);
        const int64_t cx = std::floor((double(enemy.pos.x) - runtime.state.grid.origin.x) / runtime.state.grid.cell);
        const int64_t cy = std::floor((double(enemy.pos.y) - runtime.state.grid.origin.y) / runtime.state.grid.cell);
        if (cx < 0 || cy < 0 || cx >= runtime.state.grid.cols || cy >= runtime.state.grid.rows) {
            reset_enemy_bounds();
            return rebuild_enemy_grid(cell_size);
        }
        const int64_t cell = cy * runtime.state.grid.cols + cx;
        if (runtime.state.grid.head[cell] == -1) runtime.state.grid.used.push_back(cell);
        runtime.state.grid.next[row] = runtime.state.grid.head[cell];
        runtime.state.grid.head[cell] = row;
    }
    return true;
}

std::vector<size_t> SpeedRunCore::query_enemy_rows(Vector2 lo, Vector2 hi) const {
    std::vector<size_t> out;
    if (runtime.state.grid.cols == 0 || hi.x < runtime.state.grid.origin.x || hi.y < runtime.state.grid.origin.y ||
            lo.x > runtime.state.grid.origin.x + runtime.state.grid.cols * runtime.state.grid.cell || lo.y > runtime.state.grid.origin.y + runtime.state.grid.rows * runtime.state.grid.cell) return out;
    const int64_t x0 = std::clamp(int64_t((double(lo.x) - runtime.state.grid.origin.x) / runtime.state.grid.cell), int64_t(0), runtime.state.grid.cols - 1);
    const int64_t x1 = std::clamp(int64_t((double(hi.x) - runtime.state.grid.origin.x) / runtime.state.grid.cell), int64_t(0), runtime.state.grid.cols - 1);
    const int64_t y0 = std::clamp(int64_t((double(lo.y) - runtime.state.grid.origin.y) / runtime.state.grid.cell), int64_t(0), runtime.state.grid.rows - 1);
    const int64_t y1 = std::clamp(int64_t((double(hi.y) - runtime.state.grid.origin.y) / runtime.state.grid.cell), int64_t(0), runtime.state.grid.rows - 1);
    for (int64_t y = y0; y <= y1; ++y) for (int64_t x = x0; x <= x1; ++x) {
        int64_t row = runtime.state.grid.head[y * runtime.state.grid.cols + x];
        while (row != -1) {
            if (size_t(row) < runtime.state.enemies.size() && runtime.state.enemies[row].alive && !runtime.state.enemies[row].dead) out.push_back(row);
            row = runtime.state.grid.next[row];
        }
    }
    return out;
}

PackedInt64Array SpeedRunCore::query_enemy_ids(Vector2 lo, Vector2 hi) const {
    PackedInt64Array out;
    if (!runtime.state.started || runtime.state.closed || !lo.is_finite() || !hi.is_finite() || lo.x > hi.x || lo.y > hi.y) return out;
    for (size_t row : query_enemy_rows(lo, hi)) out.append(runtime.state.enemies[row].id);
    return out;
}
