#pragma once
#include <cstdint>
#include <vector>

namespace speed {
struct CanisFireFieldInput {
    double world_scale=0,origin_x=0,origin_y=0,angle=0,length=0,width=0,age=0,duration=0,alpha=0,speed_rate=1,spikes=0;
    uint32_t logical_width=0,logical_height=0;
    int32_t seed=0;
};
struct CanisFirePixel {int32_t x=0,y=0;uint8_t layer=0;};
class CanisFireField {
public:
    // 入力座標は試作の論理画素。判定／表示の両方がこの出力を使う。
    static std::vector<CanisFirePixel> raster(const CanisFireFieldInput &);
};
}
