#include "run_core.h"
#include <algorithm>
#include <cmath>
using namespace godot;
namespace {
bool scalar(const Variant &v, double &out) {
    if (v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT) return false;
    out = v; return std::isfinite(out);
}
bool point(const Variant &v, Vector2 &out) {
    if (v.get_type() != Variant::VECTOR2) return false;
    out = v; return out.is_finite();
}
template<class T> int64_t pick(const std::vector<T> &items, const Ref<RandomNumberGenerator> &rng) {
    double total = 0;
    for (const auto &item : items) total += item.weight;
    if (items.empty() || total <= 0) return -1;
    double roll = rng->randf() * total;
    for (size_t k = 0; k < items.size(); ++k) { roll -= items[k].weight; if (roll < 0) return k; }
    return items.size() - 1;
}
}

bool SpeedRunCore::configure_formations(const Array &data, double base_view) {
    if (started || closed || !std::isfinite(base_view) || base_view < 0) return false;
    std::vector<Formation> parsed;
    for (int i = 0; i < data.size(); ++i) {
        if (data[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary source = data[i];
        double version;
        if (!scalar(source.get("version", Variant()), version) || version != 1 || source.get("entries", Variant()).get_type() != Variant::ARRAY || source.get("layouts", Variant()).get_type() != Variant::ARRAY) return false;
        Formation formation;
        const Array entries = source["entries"], layouts = source["layouts"];
        for (int k = 0; k < entries.size(); ++k) {
            if (entries[k].get_type() != Variant::DICTIONARY) return false;
            const Dictionary row = entries[k]; Formation::Entry entry;
            if (!scalar(row.get("weight", Variant()), entry.weight) || !point(row.get("pos", Variant()), entry.pos)) return false;
            formation.entries.push_back(entry);
        }
        for (int k = 0; k < layouts.size(); ++k) {
            if (layouts[k].get_type() != Variant::DICTIONARY) return false;
            const Dictionary row = layouts[k]; Formation::Layout layout;
            if (!scalar(row.get("weight", Variant()), layout.weight) || !scalar(row.get("value", Variant()), layout.value)) return false;
            layout.managed = row.get("managed", Variant());
            if (layout.managed.get_type() != Variant::NIL && layout.managed.get_type() != Variant::BOOL) return false;
            if (row.get("placements", Variant()).get_type() != Variant::ARRAY) return false;
            const Array placements = row["placements"];
            if (placements.size() != entries.size()) return false;
            for (int e = 0; e < placements.size(); ++e) {
                if (placements[e].get_type() != Variant::ARRAY) return false;
                const Array markers = placements[e]; std::vector<Formation::Marker> converted;
                for (int m = 0; m < markers.size(); ++m) {
                    if (markers[m].get_type() != Variant::DICTIONARY) return false;
                    const Dictionary item = markers[m]; Formation::Marker marker;
                    const Variant type = item.get("type", Variant());
                    if (type.get_type() != Variant::STRING && type.get_type() != Variant::STRING_NAME) return false;
                    marker.type = type;
                    if (std::none_of(definitions.begin(), definitions.end(), [&](const auto &d) { return d.id == marker.type; })) return false;
                    if (!point(item.get("offset", Variant()), marker.offset) || !scalar(item.get("rotation", Variant()), marker.rotation)) return false;
                    converted.push_back(marker);
                }
                layout.placements.push_back(std::move(converted));
            }
            formation.layouts.push_back(std::move(layout));
        }
        parsed.push_back(std::move(formation));
    }
    formations = std::move(parsed); formation_base_view = base_view;
    return true;
}

PackedInt64Array SpeedRunCore::spawn_formation(int64_t index, int64_t layout, int64_t entry, const PackedStringArray &types, double value, const Variant &priority, const Variant &managed) {
    PackedInt64Array ids;
    if (!started || closed || !ship_ready || !motion_ready || index < 0 || index >= int64_t(formations.size()) || !std::isfinite(value)) return ids;
    double priority_value = 0;
    if (priority.get_type() != Variant::NIL && !scalar(priority, priority_value)) return ids;
    if (managed.get_type() != Variant::NIL && managed.get_type() != Variant::BOOL) return ids;
    const auto &formation = formations[index];
    const int64_t group = value >= 0 ? next_id : 0;
    const int64_t li = layout >= 0 && layout < int64_t(formation.layouts.size()) ? layout : pick(formation.layouts, rng);
    const int64_t ei = entry >= 0 && entry < int64_t(formation.entries.size()) ? entry : pick(formation.entries, rng);
    if (li < 0 || ei < 0) return ids;
    Vector2 heading = ship.vel.length() > 40.0 ? ship.vel.normalized() : ship.heading;
    if (heading == Vector2()) heading = Vector2(0,-1);
    const double turn = double(heading.angle()) + Math_PI / 2.0;
    const double stretch = std::max(1.0, double(std::min(view_half.x, view_half.y)) * 2.0 / std::max(formation_base_view, 1.0));
    const Vector2 origin = formation.entries[ei].pos * stretch;
    for (const auto &marker : formation.layouts[li].placements[ei]) {
        if (!types.is_empty() && !types.has(String(marker.type))) continue;
        const Vector2 position = ship_pos + (marker.offset + origin).rotated(turn);
        const double facing = turn + marker.rotation - Math_PI / 2.0;
        Dictionary options;
        options["facing"] = facing; options["attack_group"] = group; options["attack_value"] = value;
        if (managed.get_type() != Variant::NIL && group > 0) options["attack_managed"] = managed;
        if (priority.get_type() != Variant::NIL) options["attack_priority"] = priority_value;
        const int64_t id = spawn_enemy(marker.type, position, options);
        if (id < 0) return ids;
        ids.push_back(id);
    }
    return ids;
}
