// Run with the locked godot-cpp headers/library; no Godot instance is required.
#include "../cpp/state/pickup_state.h"
#include <cassert>
#include <iostream>
#include <random>

int main() {
    speed::PickupState state;
    std::mt19937 random(719);
    std::uniform_real_distribution<float> coordinate(-20000,20000);
    for (size_t row=0;row<100000;++row) {
        speed::CrystalState gem;gem.alive=true;gem.id=row+1;gem.pos={coordinate(random),coordinate(random)};
        state.gems.push_back(gem);state.index_gem(row);
    }
    assert(state.moving_gems.empty());
    const auto check=[&](godot::Rect2 area) {
        std::vector<size_t> expected;
        for (size_t row=0;row<state.gems.size();++row) if (state.gems[row].alive && area.has_point(state.gems[row].pos)) expected.push_back(row);
        assert(state.query_gems(area)==expected);
    };
    for (int i=0;i<100;++i) check({{coordinate(random),coordinate(random)},{1600,1000}});
    const auto nearest_check=[&](godot::Rect2 area,godot::Vector2 ship,size_t limit) {
        auto expected=state.query_gems(area);
        const auto distance=[&](size_t row) {const auto p=state.gems[row].pos;const double x=double(p.x)-ship.x,y=double(p.y)-ship.y;return x*x+y*y;};
        std::sort(expected.begin(),expected.end(),[&](size_t a,size_t b) {return distance(a)<distance(b) || (distance(a)==distance(b) && state.gems[a].id<state.gems[b].id);});
        expected.resize(std::min(expected.size(),limit));
        std::sort(expected.begin(),expected.end(),[&](size_t a,size_t b){return state.gems[a].id<state.gems[b].id;});
        speed::CrystalQueryStats stats;
        assert(state.nearest_gems(area,ship,limit,&stats)==expected);
        assert(stats.candidates<=state.gems.size());
    };
    for (int i=0;i<100;++i) nearest_check({{-20000,-20000},{40000,40000}},{coordinate(random),coordinate(random)},size_t(i*7));
    speed::CrystalQueryStats bounded;
    assert(state.nearest_gems({{-20000,-20000},{40000,40000}},{0,0},2048,&bounded).size()==2048);
    assert(bounded.candidates<10000); // Distance bounds skip far cells, not just output rows.
    nearest_check({{30000,30000},{10,10}},{0,0},2048);
    state.gems[0].pulled=true;state.move_gem(0,{-128,-128});
    state.gems[1].wait=0.35;state.move_gem(1,{128,128});
    assert(state.moving_gems==std::set<size_t>({0,1}));
    check({{-128,-128},{256,256}});
    // Retention/collection queries remain uncapped in a dense region.
    for (size_t row=0;row<100000;++row) state.move_gem(row,{0,0});
    assert(state.query_gems({{-1,-1},{2,2}}).size()==100000);
    nearest_check({{-1,-1},{2,2}},{0,0},2048); // Equal-distance IDs, capped.
    state.gems[0].id=200000; // Reused row must not win a tie against older IDs.
    nearest_check({{-1,-1},{2,2}},{0,0},2);
    for (size_t row=2;row<100000;row+=2) {state.unindex_gem(row);state.gems[row].alive=false;}
    state.gems[0].pulled=false;state.move_gem(0,{0,0});
    state.gems[1].wait=0;state.move_gem(1,{0,0});
    assert(state.moving_gems.empty());
    check({{-1,-1},{2,2}});
    state.gems[2].alive=true;state.gems[2].wait=0.2;state.gems[2].pos={-100000,200000};state.index_gem(2);
    auto checkpoint=state;checkpoint.gem_cells.clear();checkpoint.moving_gems.clear();checkpoint.rebuild_gem_index();
    assert(checkpoint.gem_cells==state.gem_cells && checkpoint.moving_gems==state.moving_gems);
    check({{-100001,-300000},{500000,600000}});
    assert(checkpoint.nearest_gems({{-100001,-300000},{500000,600000}},{0,0},2048)==state.nearest_gems({{-100001,-300000},{500000,600000}},{0,0},2048));
    speed::PickupState ties;
    for (int i=0;i<4;++i) {speed::CrystalState gem;gem.alive=true;gem.id=4-i;gem.pos=i==0?godot::Vector2(0,128):i==1?godot::Vector2(256,128):i==2?godot::Vector2(128,0):godot::Vector2(128,256);ties.gems.push_back(gem);ties.index_gem(i);}
    assert(ties.nearest_gems({{-1,-1},{300,300}},{128,128},2)==std::vector<size_t>({3,2}));
    // Rect2 excludes the right edge even if that crystal is closest to the ship.
    assert(ties.nearest_gems({{0,0},{256,256}},{256,128},1)==std::vector<size_t>({2}));
    speed::PickupState cap;
    // Visible low-XP, offscreen high-XP, then equal-XP candidates differing by distance and age.
    for (int i=0;i<5;++i) {speed::CrystalState gem;gem.alive=true;gem.value=i==0?1:i==1?200:50;gem.order=uint64_t(i);gem.pos={float(i==0?0:i==1?10000:i==2?1000:2000),0};cap.gems.push_back(gem);}
    cap.live_gems=5;
    assert(cap.eviction_rows(5,{{-100,-100},{200,200}},{0,0})==std::vector<size_t>({3,4,2,1,0}));
    assert(cap.eviction_rows(2,{{-100,-100},{200,200}},{0,0})==std::vector<size_t>({3,4}));
    std::cout << "pickup index: 100000 crystals, queries, dense view, motion, removal/reuse and restore OK\n";
}
