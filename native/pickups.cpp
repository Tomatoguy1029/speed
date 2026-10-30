#include "run_core.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::configure_pickups(const Dictionary &config, const Dictionary &stats) {
    if (started || closed) return false;
    PickupConfig c;
    const char *keys[] = {"drop_base", "drop_max", "drop_power_exp", "big_crystal_shift_time", "xp_bonus", "xp_mult"};
    double *values[] = {&c.drop_base, &c.drop_max, &c.drop_power, &c.shift_time, &c.xp_bonus, &c.xp_mult};
    for (int i = 0; i < 6; ++i) {
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
    pickup_config = std::move(c); pickups_ready = true;
    return true;
}

void SpeedRunCore::drop_gem(Vector2 position, double value) {
    if (live_gems > pickup_config.gem_max) {
        while (gem_queue_head < gem_queue.size()) {
            const auto entry = gem_queue[gem_queue_head++];
            auto &old = gems[entry.first];
            if (old.alive && old.seq == entry.second) {
                value += old.value;
                old.alive = false;
                free_gems.push_back(entry.first);
                --live_gems;
                break;
            }
        }
        if (gem_queue_head >= 1024 && gem_queue_head * 2 >= gem_queue.size()) {
            gem_queue.erase(gem_queue.begin(), gem_queue.begin() + gem_queue_head);
            gem_queue_head = 0;
        }
    }
    const double angle = rng->randf() * (2.0 * Math_PI);
    const Vector2 at = position + Vector2::from_angle(angle) * 8.0;
    size_t row = gems.size();
    if (free_gems.empty()) gems.emplace_back();
    else { row = free_gems.back(); free_gems.pop_back(); }
    gems[row] = {at, value, next_gem_seq, true, false};
    gem_queue.push_back({row, next_gem_seq++});
    ++live_gems;
}

void SpeedRunCore::drop_enemy_pickups(const Enemy &enemy) {
    const auto &def = definitions[enemy.definition];
    const auto &c = pickup_config;
    const double value = def.xp * c.xp_mult * (c.xp_bonus > 0 ? c.xp_bonus : 1.0);
    xp_dropped += value;
    drop_gem(enemy.pos, value);
    if (rng->randf() < 0.03) {
        const double angle = rng->randf() * (2.0 * Math_PI);
        const double share = rng->randf();
        coins.push_back({enemy.pos + Vector2::from_angle(angle) * share * def.radius, true, false});
    }
    if (rng->randf() < std::min(c.drop_max, c.drop_base * std::pow(def.xp, c.drop_power))) {
        const double fraction = std::clamp(time / c.shift_time, 0.0, 1.0);
        std::vector<float> weights;
        double total = 0;
        for (size_t k = 0; k < c.xp.size(); ++k) {
            const double weight = Math::lerp(c.start_weights[k], c.end_weights[k], fraction);
            weights.push_back(weight); total += weight;
        }
        double roll = rng->randf() * total;
        size_t tier = weights.size() - 1;
        for (size_t k = 0; k < weights.size(); ++k) { roll -= weights[k]; if (roll < 0) { tier = k; break; } }
        xp_dropped += c.xp[tier];
        drop_gem(enemy.pos, c.xp[tier]);
    }
}

Dictionary SpeedRunCore::pickups_snapshot() const {
    Array visible_gems, visible_coins;
    for (const auto &gem : gems) if (gem.alive) {
        Dictionary row; row["pos"] = gem.pos; row["value"] = gem.value; row["seq"] = gem.seq; row["pulled"] = gem.pulled;
        visible_gems.append(row);
    }
    for (const auto &coin : coins) if (coin.alive) {
        Dictionary row; row["pos"] = coin.pos; row["pulled"] = coin.pulled; visible_coins.append(row);
    }
    Dictionary out; out["gems"] = visible_gems; out["coins"] = visible_coins; out["xp_dropped"] = xp_dropped;
    return out;
}
