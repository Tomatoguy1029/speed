#include "run_core.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;

void SpeedRunCore::reset_enemy_bounds() {
    const float infinity = std::numeric_limits<float>::infinity();
    Vector2 lo(infinity, infinity), hi(-infinity, -infinity);
    for (const auto &enemy : enemies) {
        if (!enemy.alive || enemy.dead) continue;
        lo = lo.min(enemy.pos); hi = hi.max(enemy.pos);
    }
    grid.used.clear();
    if (lo.x == infinity) { grid.cols = grid.rows = 0; return; }
    grid.origin = lo - Vector2(grid.cell * 4.0, grid.cell * 4.0);
    grid.cols = int64_t((double(hi.x) - grid.origin.x) / grid.cell) + 5;
    grid.rows = int64_t((double(hi.y) - grid.origin.y) / grid.cell) + 5;
    grid.head.assign(grid.cols * grid.rows, -1);
}

bool SpeedRunCore::rebuild_enemy_grid(double cell_size) {
    if (!started || closed || !std::isfinite(cell_size) || cell_size <= 0) return false;
    grid.max_radius = 0;
    if (grid.next.size() < enemies.size()) grid.next.resize(enemies.size(), -1);
    if (grid.cols == 0 || grid.cell != cell_size) { grid.cell = cell_size; reset_enemy_bounds(); }
    if (grid.cols == 0) return true;
    for (auto cell : grid.used) grid.head[cell] = -1;
    grid.used.clear();
    for (size_t row = 0; row < enemies.size(); ++row) {
        const auto &enemy = enemies[row];
        if (!enemy.alive || enemy.dead) { grid.next[row] = -1; continue; }
        grid.max_radius = std::max(grid.max_radius, definitions[enemy.definition].radius);
        const int64_t cx = std::floor((double(enemy.pos.x) - grid.origin.x) / grid.cell);
        const int64_t cy = std::floor((double(enemy.pos.y) - grid.origin.y) / grid.cell);
        if (cx < 0 || cy < 0 || cx >= grid.cols || cy >= grid.rows) {
            reset_enemy_bounds();
            return rebuild_enemy_grid(cell_size);
        }
        const int64_t cell = cy * grid.cols + cx;
        if (grid.head[cell] == -1) grid.used.push_back(cell);
        grid.next[row] = grid.head[cell];
        grid.head[cell] = row;
    }
    return true;
}

std::vector<size_t> SpeedRunCore::query_enemy_rows(Vector2 lo, Vector2 hi) const {
    std::vector<size_t> out;
    if (grid.cols == 0 || hi.x < grid.origin.x || hi.y < grid.origin.y ||
            lo.x > grid.origin.x + grid.cols * grid.cell || lo.y > grid.origin.y + grid.rows * grid.cell) return out;
    const int64_t x0 = std::clamp(int64_t((double(lo.x) - grid.origin.x) / grid.cell), int64_t(0), grid.cols - 1);
    const int64_t x1 = std::clamp(int64_t((double(hi.x) - grid.origin.x) / grid.cell), int64_t(0), grid.cols - 1);
    const int64_t y0 = std::clamp(int64_t((double(lo.y) - grid.origin.y) / grid.cell), int64_t(0), grid.rows - 1);
    const int64_t y1 = std::clamp(int64_t((double(hi.y) - grid.origin.y) / grid.cell), int64_t(0), grid.rows - 1);
    for (int64_t y = y0; y <= y1; ++y) for (int64_t x = x0; x <= x1; ++x) {
        int64_t row = grid.head[y * grid.cols + x];
        while (row != -1) {
            if (size_t(row) < enemies.size() && enemies[row].alive && !enemies[row].dead) out.push_back(row);
            row = grid.next[row];
        }
    }
    return out;
}

PackedInt64Array SpeedRunCore::query_enemy_ids(Vector2 lo, Vector2 hi) const {
    PackedInt64Array out;
    if (!started || closed || !lo.is_finite() || !hi.is_finite() || lo.x > hi.x || lo.y > hi.y) return out;
    for (size_t row : query_enemy_rows(lo, hi)) out.append(enemies[row].id);
    return out;
}
