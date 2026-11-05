#include "fire_history.h"
#include <cmath>

namespace speed {
namespace {
uint64_t key(int32_t x,int32_t y) {return (uint64_t(uint32_t(x))<<32)|uint32_t(y);}
}
void CanisFireHistory::stamp(const std::vector<CanisFirePixel> &pixels,godot::Vector2 view_origin,double world_scale,double clock) {
    if (!(world_scale>0) || !std::isfinite(world_scale) || !std::isfinite(clock) || !view_origin.is_finite()) return;
    if (cell<=0) cell=1.0/world_scale;
    for (const auto &pixel:pixels) {
        const godot::Vector2 at=view_origin+godot::Vector2((pixel.x+.5)/world_scale,(pixel.y+.5)/world_scale);
        const auto px=int32_t(std::floor(at.x/cell)),py=int32_t(std::floor(at.y/cell));
        if (!footprint.insert(key(px,py)).second) continue;
        deposit(at,clock,true);
    }
}
void CanisFireHistory::deposit(godot::Vector2 at,double clock,bool pixel) {
    if (!at.is_finite() || !std::isfinite(clock)) return;
    const double c=std::cos(angle),s=std::sin(angle);const auto relative=at-origin;
    const auto along=int32_t(std::floor((relative.x*c+relative.y*s)/45.0));
    const auto across=int32_t(std::floor((-relative.x*s+relative.y*c)/45.0));
    const auto group=key(along,across);
    auto found=deposit_cells.find(group);
    if (found==deposit_cells.end()) {
        const auto start_frame=uint32_t(int64_t(std::floor(started*60.0+.5)));
        const uint32_t seed=(uint32_t(along)*73856093u)^(uint32_t(across)*19349663u)^(start_frame*83492791u);
        deposits.push_back({at,clock,seed,{}});
        found=deposit_cells.emplace(group,deposits.size()-1).first;
    }
    auto &entry=deposits[found->second];entry.updated=clock;if (pixel) entry.pixels.push_back(at);
}
}
