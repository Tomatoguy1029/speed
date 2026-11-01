#include "run_core.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_pickups(const Dictionary &config, const Dictionary &stats) {
    if (runtime.state.started || runtime.state.closed) return false;
    PickupConfig c;
    const char *keys[] = {"drop_base", "drop_max", "drop_power_exp", "big_crystal_shift_time", "xp_bonus", "xp_mult", "xp_pickup_radius", "pickup_radius", "pickup_speed_mult"};
    double *values[] = {&c.drop_base, &c.drop_max, &c.drop_power, &c.shift_time, &c.xp_bonus, &c.xp_mult, &c.xp_radius, &c.coin_radius, &c.speed_mult};
    for (int i = 0; i < 9; ++i) {
        const Dictionary &source = i < 5 ? config : stats;
        if (!source.has(keys[i])) return false;
        const Variant value = source[keys[i]];
        if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        *values[i] = double(value);
        if (!std::isfinite(*values[i]) || *values[i] < 0) return false;
    }
    if (c.shift_time <= 0 || !config.has("gem_max")) return false;
    const Variant maximum = config["gem_max"];
    if ((maximum.get_type() != Variant::INT && maximum.get_type() != Variant::FLOAT) ||
            !std::isfinite(double(maximum)) || double(maximum) < 0 || double(maximum) > INT32_MAX || std::floor(double(maximum)) != double(maximum)) return false;
    c.gem_max = int64_t(maximum);
    const char *arrays[] = {"big_crystal_xp", "big_crystal_weights_start", "big_crystal_weights_end"};
    std::vector<double> *dest[] = {&c.xp, &c.start_weights, &c.end_weights};
    for (int i = 0; i < 3; ++i) {
        if (!config.has(arrays[i])) return false;
        const Variant input = config[arrays[i]];
        if (input.get_type() != Variant::ARRAY && input.get_type() != Variant::PACKED_FLOAT32_ARRAY) return false;
        const Array values = input;
        if (values.is_empty()) return false;
        for (int64_t k = 0; k < values.size(); ++k) {
            const Variant v = values[k];
            if ((v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT) || !std::isfinite(double(v)) || double(v) < 0) return false;
            dest[i]->push_back(double(v));
        }
    }
    if (c.xp.size() != c.start_weights.size() || c.xp.size() != c.end_weights.size()) return false;
    runtime.state.pickup_config = std::move(c); runtime.state.pickups_ready = true;
    return true;
}

void SpeedRunCore::drop_gem(Vector2 position, double value) {
    if (runtime.state.live_gems > runtime.state.pickup_config.gem_max) {
        while (runtime.state.gem_queue_head < runtime.state.gem_queue.size()) {
            const auto entry = runtime.state.gem_queue[runtime.state.gem_queue_head++];
            auto &old = runtime.state.gems[entry.first];
            if (old.alive && old.seq == entry.second) {
                value += old.value;
                old.alive = false;
                runtime.state.free_gems.push_back(entry.first);
                --runtime.state.live_gems;
                break;
            }
        }
        if (runtime.state.gem_queue_head >= 1024 && runtime.state.gem_queue_head * 2 >= runtime.state.gem_queue.size()) {
            runtime.state.gem_queue.erase(runtime.state.gem_queue.begin(), runtime.state.gem_queue.begin() + runtime.state.gem_queue_head);
            runtime.state.gem_queue_head = 0;
        }
    }
    const double angle = runtime.state.rng->randf() * (2.0 * godot::Math::PI);
    const Vector2 at = position + Vector2::from_angle(angle) * 8.0;
    size_t row = runtime.state.gems.size();
    if (runtime.state.free_gems.empty()) runtime.state.gems.emplace_back();
    else { row = runtime.state.free_gems.back(); runtime.state.free_gems.pop_back(); }
    runtime.state.gems[row] = {at, value, runtime.state.next_gem_seq, true, false};
    runtime.state.gem_queue.push_back({row, runtime.state.next_gem_seq++});
    ++runtime.state.live_gems;
}

void SpeedRunCore::drop_enemy_pickups(const Enemy &enemy) {
    const auto &c = runtime.state.pickup_config;
    const double value = enemy.xp * c.xp_mult * (c.xp_bonus > 0 ? c.xp_bonus : 1.0);
    runtime.state.xp_dropped += value;
    drop_gem(enemy.pos, value);
    const int64_t coin_count = enemy.elite ? 3 + runtime.state.rng->randi_range(0, 3) : (runtime.state.rng->randf() < 0.03 ? 1 : 0);
    for (int64_t k = 0; k < coin_count; ++k) {
        const double angle = runtime.state.rng->randf() * (2.0 * godot::Math::PI);
        const double share = runtime.state.rng->randf();
        const Coin coin{enemy.pos + Vector2::from_angle(angle) * share * enemy.radius, true, false};
        if (runtime.state.free_coins.empty()) runtime.state.coins.push_back(coin);
        else { runtime.state.coins[runtime.state.free_coins.back()] = coin; runtime.state.free_coins.pop_back(); }
    }
    if (runtime.state.rng->randf() < std::min(c.drop_max, c.drop_base * std::pow(enemy.xp, c.drop_power))) {
        const double fraction = std::clamp(runtime.state.time / c.shift_time, 0.0, 1.0);
        std::vector<float> weights;
        double total = 0;
        for (size_t k = 0; k < c.xp.size(); ++k) {
            const double weight = Math::lerp(c.start_weights[k], c.end_weights[k], fraction);
            weights.push_back(weight); total += weight;
        }
        double roll = runtime.state.rng->randf() * total;
        size_t tier = weights.size() - 1;
        for (size_t k = 0; k < weights.size(); ++k) { roll -= weights[k]; if (roll < 0) { tier = k; break; } }
        runtime.state.xp_dropped += c.xp[tier];
        drop_gem(enemy.pos, c.xp[tier]);
    }
}

Dictionary SpeedRunCore::pickups_snapshot() const {
    Array visible_gems, visible_coins;
    for (const auto &gem : runtime.state.gems) if (gem.alive) {
        Dictionary row; row["pos"] = gem.pos; row["value"] = gem.value; row["seq"] = gem.seq; row["pulled"] = gem.pulled;
        visible_gems.append(row);
    }
    for (const auto &coin : runtime.state.coins) if (coin.alive) {
        Dictionary row; row["pos"] = coin.pos; row["pulled"] = coin.pulled; visible_coins.append(row);
    }
    Dictionary out; out["gems"] = visible_gems; out["coins"] = visible_coins; out["xp_dropped"] = runtime.state.xp_dropped;
    return out;
}

void SpeedRunCore::collect_pickup(StringName kind, double value) {
    // B案は成長側へまとめて渡す。各回収の順序を保ち、カード待ちの判断は成長の所有者が行う。
    if (runtime.state.progression.ready && kind == StringName("gem")) add_xp(value);
    else { Dictionary item; item["kind"] = kind; item["value"] = value; runtime.state.collections.append(item); }
    Dictionary event; event["kind"] = kind; emit_event("pickup", event);
}

Array SpeedRunCore::drain_collections() { Array out = runtime.state.collections; runtime.state.collections = Array(); return out; }

bool SpeedRunCore::step_pickups(double world_dt) {
    if (!runtime.state.started || runtime.state.closed || !runtime.state.ship_ready || !runtime.state.pickups_ready || !std::isfinite(world_dt) || world_dt < 0) return false;
    if (world_dt == 0) return true;
    const double reach = runtime.state.ship_config.ship_radius + 14.0;
    const double gem_radius = runtime.state.pickup_config.xp_radius;
    const double step = (700.0 + runtime.state.ship.vel.length() * 1.2) * runtime.state.pickup_config.speed_mult * world_dt;
    const double far = std::max(gem_radius, reach), far_sq = far * far;
    for (size_t row = 0; row < runtime.state.gems.size(); ++row) {
        auto &gem = runtime.state.gems[row];
        if (!gem.alive) continue;
        if (!gem.pulled && runtime.state.ship.pos.distance_squared_to(gem.pos) >= far_sq) continue;
        const Vector2 p = gem.pos, d = runtime.state.ship.pos - p;
        const double distance = d.length();
        if (distance < gem_radius || gem.pulled) {
            gem.pulled = true;
            gem.pos = p + d / std::max(distance, 1.0) * std::min(step, distance);
        }
        if (distance < reach) {
            collect_pickup("gem", gem.value);
            gem.alive = false;
            runtime.state.free_gems.push_back(row);
            --runtime.state.live_gems;
        }
    }
    const double coin_radius = runtime.state.pickup_config.coin_radius * 1.3;
    const double coin_step = (700.0 + runtime.state.ship.vel.length() * 1.2) * world_dt;
    const double coin_far = std::max(coin_radius, reach), coin_far_sq = coin_far * coin_far;
    for (size_t row = 0; row < runtime.state.coins.size(); ++row) {
        auto &coin = runtime.state.coins[row];
        if (!coin.alive) continue;
        if (!coin.pulled && runtime.state.ship.pos.distance_squared_to(coin.pos) >= coin_far_sq) continue;
        const Vector2 p = coin.pos, d = runtime.state.ship.pos - p;
        const double distance = d.length();
        if (distance < coin_radius || coin.pulled) {
            coin.pulled = true;
            coin.pos = p + d / std::max(distance, 1.0) * std::min(coin_step, distance);
        }
        if (distance < reach) {
            collect_pickup("coin");
            coin.alive = false;
            runtime.state.free_coins.push_back(row);
        }
    }
    return true;
}

PackedFloat32Array SpeedRunCore::pickup_buffer(StringName kind, double size, Color color, Rect2 view) const {
    PackedFloat32Array buffer;
    if (!runtime.state.started || runtime.state.closed || !runtime.state.pickups_ready || !std::isfinite(size) || size <= 0 || !view.position.is_finite() || !view.size.is_finite() || view.size.x < 0 || view.size.y < 0) return buffer;
    const bool is_gem = kind == StringName("gem");
    if (!is_gem && kind != StringName("coin")) return buffer;
    int64_t count = 0;
    if (is_gem) { for (const auto &gem : runtime.state.gems) if (gem.alive && view.has_point(gem.pos)) ++count; }
    else { for (const auto &coin : runtime.state.coins) if (coin.alive && view.has_point(coin.pos)) ++count; }
    buffer.resize(count * 12);
    float *out = buffer.ptrw();
    int64_t index = 0;
    const auto append = [&](Vector2 pos, double radius) {
        out[index++] = radius; out[index++] = 0; out[index++] = 0; out[index++] = pos.x;
        out[index++] = 0; out[index++] = radius; out[index++] = 0; out[index++] = pos.y;
        out[index++] = color.r; out[index++] = color.g; out[index++] = color.b; out[index++] = color.a;
    };
    if (is_gem) {
        for (const auto &gem : runtime.state.gems) if (gem.alive && view.has_point(gem.pos))
            append(gem.pos, size * (gem.value <= 1.0 ? 1.0 : std::min(std::pow(gem.value, 0.2), 3.0)));
    } else { for (const auto &coin : runtime.state.coins) if (coin.alive && view.has_point(coin.pos)) append(coin.pos, size); }
    return buffer;
}
