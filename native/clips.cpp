#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;
namespace {
bool number(const Variant &v, double &out) {
    if (v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT) return false;
    out = v; return std::isfinite(out);
}
}
bool SpeedRunCore::configure_clips(const Dictionary &data) {
    if (started || closed || !population.ready) return false;
    double version, base_view;
    if (!number(data.get("version", Variant()), version) || version != 1 || !number(data.get("base_view", Variant()), base_view)) return false;
    if (data.get("clips", Variant()).get_type() != Variant::ARRAY || data.get("formations", Variant()).get_type() != Variant::ARRAY) return false;
    const Array source = data["clips"], prepared = data["formations"];
    std::vector<Clip> parsed;
    for (int i = 0; i < source.size(); ++i) {
        if (source[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = source[i]; Clip clip;
        const char *keys[] = {"start", "end", "interval", "priority"};
        double *values[] = {&clip.start, &clip.end, &clip.interval, &clip.priority};
        for (int k = 0; k < 4; ++k) if (!number(row.get(keys[k], Variant()), *values[k])) return false;
        double maximum;
        if (!number(row.get("groups", Variant()), maximum) || maximum < 0 || maximum > INT32_MAX || std::floor(maximum) != maximum || clip.interval < 0) return false;
        clip.maximum = int64_t(maximum);
        if (row.get("types", Variant()).get_type() != Variant::ARRAY || row.get("formations", Variant()).get_type() != Variant::ARRAY) return false;
        const Array types = row["types"], refs = row["formations"];
        for (int k = 0; k < types.size(); ++k) {
            if (types[k].get_type() != Variant::STRING && types[k].get_type() != Variant::STRING_NAME) return false;
            clip.types.push_back(String(types[k]));
        }
        for (int k = 0; k < refs.size(); ++k) {
            double index;
            if (!number(refs[k], index) || index < 0 || index >= prepared.size() || std::floor(index) != index) return false;
            clip.formations.push_back(size_t(index));
        }
        parsed.push_back(std::move(clip));
    }
    if (!configure_formations(prepared, base_view)) return false;
    clips = std::move(parsed); clips_ready = true;
    return true;
}

Array SpeedRunCore::clips_snapshot() const {
    Array out;
    if (closed || !clips_ready) return out;
    for (const auto &clip : clips) {
        Dictionary row; Array groups, arrived;
        for (const auto &group : clip.groups) {
            Array ids; for (const auto &member : group.members) ids.append(member.second);
            groups.append(ids); arrived.append(group.arrived);
        }
        row["next"] = clip.next; row["groups"] = groups; row["arrived"] = arrived; out.append(row);
    }
    return out;
}

bool SpeedRunCore::step_clips() {
    if (!started || closed || !clips_ready || !population.ready || !motion_ready || !ship_ready) return false;
    auto pick = [&](const std::vector<double> &weights) -> int64_t {
        double total = 0; for (double weight : weights) total += weight;
        if (weights.empty() || total <= 0) return -1;
        double roll = rng->randf() * total;
        for (size_t i = 0; i < weights.size(); ++i) { roll -= weights[i]; if (roll < 0) return i; }
        return weights.size() - 1;
    };
    for (size_t n = 0; n < clips.size(); ++n) {
        auto &clip = clips[n];
        std::vector<Clip::Group> retained;
        for (auto &group : clip.groups) {
            bool alive = false;
            for (const auto &member : group.members) {
                if (member.first >= enemies.size()) continue;
                const auto &enemy = enemies[member.first];
                if (enemy.alive && !enemy.dead && enemy.id == member.second) { alive = true; break; }
            }
            if (alive) retained.push_back(std::move(group));
            else {
                Dictionary event; event["clip"] = int64_t(n); event["key"] = group.members.front().second;
                emit_event("clip_group_end", event);
            }
        }
        clip.groups = std::move(retained);
        if (time < clip.start || time >= clip.end || int64_t(clip.groups.size()) >= clip.maximum || time < clip.next) continue;
        std::vector<size_t> candidates;
        for (size_t index : clip.formations) {
            bool capped = false;
            for (const auto &layout : formations[index].layouts) for (const auto &type : layout.types) {
                const auto found = std::find_if(definitions.begin(), definitions.end(), [&](const auto &d) { return d.id == type; });
                if (found == definitions.end()) continue;
                const size_t t = found - definitions.begin();
                if (population.maximum[t] > 0 && population.type_counts[t] >= population.maximum[t]) capped = true;
            }
            if (!capped) candidates.push_back(index);
        }
        const int64_t chosen = pick(std::vector<double>(candidates.size(), 1.0));
        if (chosen < 0) continue;
        const size_t index = candidates[chosen];
        std::vector<double> weights;
        for (const auto &layout : formations[index].layouts) weights.push_back(layout.weight);
        const int64_t selected = pick(weights);
        if (selected < 0) continue;
        const auto &layout = formations[index].layouts[selected];
        const PackedInt64Array ids = spawn_formation(index, selected, -1, clip.types, layout.value, clip.priority, layout.managed);
        if (ids.is_empty()) continue;
        Clip::Group group;
        for (int i = 0; i < ids.size(); ++i) group.members.emplace_back(rows_by_id.at(ids[i]), ids[i]);
        clip.groups.push_back(std::move(group)); clip.next = time + clip.interval;
        Dictionary event; event["clip"] = int64_t(n); event["key"] = ids[0]; event["n"] = int64_t(ids.size());
        emit_event("clip_group", event);
    }
    return true;
}
