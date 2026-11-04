#pragma once
#include <godot_cpp/variant/vector2.hpp>
#include "entity_store.h"
#include <array>
#include <map>
#include <set>
#include <algorithm>
#include <cmath>
#include <godot_cpp/variant/rect2.hpp>
#include <vector>
#include <cstdint>
#include <cstddef>
#include <utility>
namespace speed {
enum class CrystalSource : uint8_t { Direct,Enemy,StrongGold };
struct CrystalOrigin {
    CrystalSource source=CrystalSource::Direct;
    uint32_t definition=0;
    int64_t enemy_id=-1;
    double run_time=0,world_time=0;
};
struct CrystalState {
    godot::Vector2 pos;
    double value=0;
    uint64_t order=0;
    bool alive=false,pulled=false;
    uint8_t kind=0;
    uint64_t id=0;
    CrystalOrigin origin;
    godot::Vector2 velocity;
    double wait=0;
};
struct CrystalCollection {CrystalState crystal;double actual_xp=0;bool was_absorber=false;};
struct CoinState {godot::Vector2 pos;bool alive=true,pulled=false;};
enum class CapsuleKind {Heal,Magnet,CometWeapon};
struct CapsuleState {godot::Vector2 pos;double age=0;CapsuleKind kind=CapsuleKind::Heal;uint32_t weapon=0;bool drop=true;};
struct CrystalTotal {uint64_t count=0;double base_xp=0,actual_xp=0;};
struct CrystalCargo {EnemyHandle owner;int64_t enemy_id=0;std::vector<CrystalState> crystals;};
struct CrystalQueryStats {size_t cells=0,candidates=0;};
struct PickupState {
    std::vector<size_t> nearest_gems(godot::Rect2 area,godot::Vector2 ship,size_t limit,CrystalQueryStats *stats=nullptr) const;
    // Derived indexes: rebuilt from crystals when restoring a checkpoint.
    using Cell=std::pair<double,double>;
    std::map<Cell,std::set<size_t>> gem_cells;
    std::set<size_t> moving_gems;
    static Cell cell(godot::Vector2 pos) {return {std::floor(double(pos.x)/128.0),std::floor(double(pos.y)/128.0)};}
    void index_gem(size_t row) {
        const auto &g=gems[row];gem_cells[cell(g.pos)].insert(row);
        if (g.wait>0 || g.pulled) moving_gems.insert(row);else moving_gems.erase(row);
    }
    void unindex_gem(size_t row) {
        const auto key=cell(gems[row].pos);auto found=gem_cells.find(key);
        if (found!=gem_cells.end()) {found->second.erase(row);if (found->second.empty()) gem_cells.erase(found);}
        moving_gems.erase(row);
    }
    void move_gem(size_t row,godot::Vector2 pos) {
        if (cell(gems[row].pos)!=cell(pos)) {unindex_gem(row);gems[row].pos=pos;index_gem(row);}
        else {gems[row].pos=pos;if (gems[row].wait>0 || gems[row].pulled) moving_gems.insert(row);else moving_gems.erase(row);}
    }
    void rebuild_gem_index() {
        gem_cells.clear();moving_gems.clear();
        for (size_t row=0;row<gems.size();++row) {if (gems[row].alive) index_gem(row);}
    }
    std::vector<size_t> query_gems(godot::Rect2 area) const {
        std::vector<size_t> rows;const auto lo=cell(area.position),hi=cell(area.position+area.size);
        const auto append=[&](const auto &bucket) {for (auto row:bucket) if (area.has_point(gems[row].pos)) rows.push_back(row);};
        // Large queries iterate occupied cells rather than enormous empty coordinate ranges.
        if ((hi.first-lo.first+1)*(hi.second-lo.second+1)>double(gem_cells.size())) {
            for (const auto &entry:gem_cells) if (entry.first.first>=lo.first && entry.first.first<=hi.first && entry.first.second>=lo.second && entry.first.second<=hi.second) append(entry.second);
        } else for (size_t x=0;x<size_t(hi.first-lo.first+1);++x) for (size_t y=0;y<size_t(hi.second-lo.second+1);++y) {
            auto found=gem_cells.find({lo.first+double(x),lo.second+double(y)});if (found!=gem_cells.end()) append(found->second);
        }
        std::sort(rows.begin(),rows.end());return rows;
    }
    std::vector<size_t> eviction_rows(size_t count,godot::Rect2 view,godot::Vector2 ship) const {
        std::vector<size_t> rows;rows.reserve(size_t(live_gems));
        for (size_t row=0;row<gems.size();++row) if (gems[row].alive) rows.push_back(row);
        const auto before=[&](size_t a,size_t b) {
            const auto &x=gems[a],&y=gems[b];
            const bool xv=view.has_point(x.pos),yv=view.has_point(y.pos);
            if (xv!=yv) return !xv;
            if (x.value!=y.value) return x.value<y.value;
            const auto xd=x.pos.distance_squared_to(ship),yd=y.pos.distance_squared_to(ship);
            if (xd!=yd) return xd>yd;
            return x.order<y.order;
        };
        std::partial_sort(rows.begin(),rows.begin()+count,rows.end(),before);
        rows.resize(count);return rows;
    }
    std::vector<CrystalCargo> cargo;
    std::vector<CrystalState> gems;
    std::vector<CoinState> coins;
    std::vector<CapsuleState> capsules;
    std::vector<size_t> free_gems,free_coins;
    std::vector<std::pair<size_t,uint64_t>> gem_queue;
    size_t gem_queue_head=0;
    uint64_t next_ground_order=0,gem_absorber_id=0;
    int64_t live_gems=0,gem_absorber=-1;
    double xp_dropped=0,collected_actual_xp=0;
    uint64_t next_id=1,gold_rolls=0,gold_won=0;
    std::array<CrystalTotal,3> supplied{},collected{},lost{};
};
}
