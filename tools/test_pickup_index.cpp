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
    state.gems[0].pulled=true;state.move_gem(0,{-128,-128});
    state.gems[1].wait=0.35;state.move_gem(1,{128,128});
    assert(state.moving_gems==std::set<size_t>({0,1}));
    check({{-128,-128},{256,256}});
    // The render query must return every crystal in a dense visible region.
    for (size_t row=0;row<100000;++row) state.move_gem(row,{0,0});
    assert(state.query_gems({{-1,-1},{2,2}}).size()==100000);
    for (size_t row=2;row<100000;row+=2) {state.unindex_gem(row);state.gems[row].alive=false;}
    state.gems[0].pulled=false;state.move_gem(0,{0,0});
    state.gems[1].wait=0;state.move_gem(1,{0,0});
    assert(state.moving_gems.empty());
    check({{-1,-1},{2,2}});
    state.gems[2].alive=true;state.gems[2].wait=0.2;state.gems[2].pos={-100000,200000};state.index_gem(2);
    auto checkpoint=state;checkpoint.gem_cells.clear();checkpoint.moving_gems.clear();checkpoint.rebuild_gem_index();
    assert(checkpoint.gem_cells==state.gem_cells && checkpoint.moving_gems==state.moving_gems);
    check({{-100001,-300000},{500000,600000}});
    speed::PickupState cap;
    // Visible low-XP, offscreen high-XP, then equal-XP candidates differing by distance and age.
    for (int i=0;i<5;++i) {speed::CrystalState gem;gem.alive=true;gem.value=i==0?1:i==1?200:50;gem.order=uint64_t(i);gem.pos={float(i==0?0:i==1?10000:i==2?1000:2000),0};cap.gems.push_back(gem);}
    cap.live_gems=5;
    assert(cap.eviction_rows(5,{{-100,-100},{200,200}},{0,0})==std::vector<size_t>({3,4,2,1,0}));
    assert(cap.eviction_rows(2,{{-100,-100},{200,200}},{0,0})==std::vector<size_t>({3,4}));
    std::cout << "pickup index: 100000 crystals, queries, dense view, motion, removal/reuse and restore OK\n";
}
