// 共通の円形の光。画素中心の距離と乗算順をPainter.glowとそろえる。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
int SpeedFxRaster::canvas_glow(Vector2 center,double radius,Color color,double strength,double fade,double light_strength) {
    reference_flags_=0;
    if (radius<1 || strength<=0.004) return 0;
    for (int y=std::max(0,int(std::floor(center.y-radius)));y<=std::min(h_-1,int(std::ceil(center.y+radius)));++y) {
        for (int x=std::max(0,int(std::floor(center.x-radius)));x<=std::min(w_-1,int(std::ceil(center.x+radius)));++x) {
            const double d=Vector2(x+0.5,y+0.5).distance_to(center)/radius;
            if (d<1) reference_light(Vector2(x,y),color,(1-d)*(1-d)*strength*fade*light_strength);
        }
    }
    return reference_flags_;
}
}
