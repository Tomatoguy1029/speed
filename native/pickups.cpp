#include "run_core.h"
#include "../cpp/systems/progression.h"
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
    // 共通回収は倍率を一度適用して最終XPを渡す。旧比較入口は撤去まで分ける。
    if (runtime.state.loadout.ready && kind == StringName("gem")) speed::ProgressionSystem::add_experience(*this,value*runtime.state.pickup_config.xp_mult*runtime.state.loadout.xp_gain_mult);
    else if (runtime.state.legacy_progression.ready && kind == StringName("gem")) add_xp(value);
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
