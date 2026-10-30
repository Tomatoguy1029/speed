#include "run_core.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void SpeedRunCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "data"), &SpeedRunCore::configure);
    ClassDB::bind_method(D_METHOD("start", "seed"), &SpeedRunCore::start);
    ClassDB::bind_method(D_METHOD("step", "delta"), &SpeedRunCore::step);
    ClassDB::bind_method(D_METHOD("close"), &SpeedRunCore::close);
    ClassDB::bind_method(D_METHOD("inspect"), &SpeedRunCore::inspect);
}

bool SpeedRunCore::start(int64_t seed) {
    if (started || closed) return false;
    rng.instantiate();
    rng->set_seed(seed);
    started = true;
    return true;
}

bool SpeedRunCore::step(double delta) {
    if (!started || closed || !std::isfinite(delta) || delta <= 0.0 || !std::isfinite(time + delta)) return false;
    time += delta;
    ++ticks;
    return true;
}

void SpeedRunCore::close() {
    closed = true;
    rng.unref();
}

Dictionary SpeedRunCore::inspect() const {
    Dictionary out;
    out["active"] = started && !closed;
    out["closed"] = closed;
    out["time"] = time;
    out["ticks"] = ticks;
    out["rng_state"] = rng.is_valid() ? String::num_int64(rng->get_state()) : String();
    return out;
}

// 入力全体を検証してから差し替え、不正な途中結果を残さない。
bool SpeedRunCore::configure(const Dictionary &data) {
    if (started || closed || !data.has("version") ||
            (data["version"].get_type() != Variant::INT && data["version"].get_type() != Variant::FLOAT) || double(data["version"]) != 1.0 ||
            !data.has("enemies") || data["enemies"].get_type() != Variant::ARRAY) return false;
    const Array rows = data["enemies"];
    std::vector<speed::EnemyDefinition> parsed;
    for (int64_t i = 0; i < rows.size(); ++i) {
        if (rows[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = rows[i];
        if (!row.has("id") || row["id"].get_type() != Variant::STRING || String(row["id"]).is_empty() ||
                !row.has("behavior") || row["behavior"].get_type() != Variant::STRING || String(row["behavior"]) != "chase") return false;
        speed::EnemyDefinition def;
        def.id = String(row["id"]);
        for (const auto &previous : parsed) if (previous.id == def.id) return false;
        const char *keys[] = {"hp", "armor", "radius", "speed", "fire_interval"};
        double *values[] = {&def.hp, &def.armor, &def.radius, &def.speed, &def.fire_interval};
        for (int k = 0; k < 5; ++k) {
            if (!row.has(keys[k])) return false;
            const Variant value = row[keys[k]];
            if (value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) return false;
            *values[k] = double(value);
            if (!std::isfinite(*values[k]) || *values[k] < 0.0) return false;
        }
        if (def.hp <= 0.0 || def.radius <= 0.0 || !row.has("color") || row["color"].get_type() != Variant::ARRAY) return false;
        const Array color = row["color"];
        if (color.size() != 4) return false;
        for (int k = 0; k < 4; ++k) {
            const Variant value = color[k];
            if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) || !std::isfinite(double(value))) return false;
            def.color[k] = double(value);
        }
        parsed.push_back(def);
    }
    definitions = std::move(parsed);
    return true;
}
