#include "../state/pickup_state.h"

namespace speed {
std::vector<size_t> PickupState::nearest_gems(godot::Rect2 area,godot::Vector2 ship,size_t limit,CrystalQueryStats *stats) const {
    if (stats) *stats={};
    if (!limit || gem_cells.empty()) return {};
    struct Bucket {double distance;const std::set<size_t> *rows;};
    std::vector<Bucket> buckets;
    const auto lo=cell(area.position),hi=cell(area.position+area.size);
    const auto add=[&](const auto &entry) {
        const double x=entry.first.first*128.0,y=entry.first.second*128.0;
        const double dx=std::max({x-double(ship.x),0.0,double(ship.x)-(x+128.0)});
        const double dy=std::max({y-double(ship.y),0.0,double(ship.y)-(y+128.0)});
        buckets.push_back({dx*dx+dy*dy,&entry.second});
    };
    if ((hi.first-lo.first+1)*(hi.second-lo.second+1)>double(gem_cells.size())) {
        for (const auto &entry:gem_cells) if (entry.first.first>=lo.first && entry.first.first<=hi.first && entry.first.second>=lo.second && entry.first.second<=hi.second) add(entry);
    } else for (size_t x=0;x<size_t(hi.first-lo.first+1);++x) for (size_t y=0;y<size_t(hi.second-lo.second+1);++y) {
        auto found=gem_cells.find({lo.first+double(x),lo.second+double(y)});if (found!=gem_cells.end()) add(*found);
    }
    const auto farther=[](const Bucket &a,const Bucket &b) {return a.distance>b.distance;};
    std::make_heap(buckets.begin(),buckets.end(),farther);
    struct Candidate {double distance;uint64_t id;size_t row;};
    const auto better=[](const Candidate &a,const Candidate &b) {return a.distance<b.distance || (a.distance==b.distance && a.id<b.id);};
    std::vector<Candidate> selected;selected.reserve(std::min(limit,gems.size()));
    while (!buckets.empty()) {
        std::pop_heap(buckets.begin(),buckets.end(),farther);const auto bucket=buckets.back();buckets.pop_back();
        // Equal-distance cells must still be visited to resolve ties by stable crystal ID.
        if (selected.size()==limit && bucket.distance>selected.front().distance) break;
        if (stats) ++stats->cells;
        for (size_t row:*bucket.rows) {
            if (stats) ++stats->candidates;
            const auto &gem=gems[row];if (!area.has_point(gem.pos)) continue;
            const double dx=double(gem.pos.x)-ship.x,dy=double(gem.pos.y)-ship.y;
            const Candidate next{dx*dx+dy*dy,gem.id,row};
            if (selected.size()<limit) {selected.push_back(next);std::push_heap(selected.begin(),selected.end(),better);}
            else if (better(next,selected.front())) {std::pop_heap(selected.begin(),selected.end(),better);selected.back()=next;std::push_heap(selected.begin(),selected.end(),better);}
        }
    }
    // Stable painter order, independent of cell traversal and reusable storage rows.
    std::sort(selected.begin(),selected.end(),[](const auto &a,const auto &b){return a.id<b.id;});
    std::vector<size_t> rows;rows.reserve(selected.size());for (const auto &item:selected) rows.push_back(item.row);
    return rows;
}
}
