// おおいぬ座の戦闘側の炎画素と、猟犬の通過跡。描画の順序と丸めを元のPainterにそろえる。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
int SpeedFxRaster::canis_pixels(PackedInt32Array pixels,Vector2 origin,double cell,PackedColorArray palette,double fade,double light_strength) {
    reference_flags_=0;
    if (cell<=0 || palette.size()<3 || pixels.size()%3!=0) return 0;
    for (int i=0;i<pixels.size();i+=3) {
        const int x=pixels[i],y=pixels[i+1],layer=pixels[i+2];
        if (layer<0 || layer>2) continue;
        const Vector2 point=logical(origin+Vector2(x+0.5,y+0.5)*cell);
        const Color color=palette[layer];
        reference_dot(point,color,1,fade);
        if ((x&3)==0 && (y&3)==0) reference_glow(point,2,color,layer==2?0.10:layer==1?0.05:0.02,fade,light_strength);
    }
    return reference_flags_;
}
int SpeedFxRaster::canis_hound_trails(Array trails,double clock,PackedColorArray palette,double fade,double light_strength) {
    reference_flags_=0;
    if (palette.size()<9) return 0;
    const auto hash=[](double n) {const double v=std::sin(n*127.1+311.7)*43758.5453;return v-std::floor(v);};
    const auto blended_disc=[&](Vector2 at,double radius,Color color,double alpha) {
        if (radius<0.5) {reference_blend(at,color,alpha,fade);return;}
        const int saved=reference_flags_;
        reference_flags_=saved|canvas_circle(at.x,at.y,radius,color,alpha,fade,true);
    };
    const auto solid=[&](Vector2 at,double radius,Color color) {
        if (radius<0.6) reference_dot(at,color,1,fade);
        else blended_disc(at,radius,color,1);
    };
    for (int row=0;row<trails.size();++row) {
        const Dictionary actor=trails[row];const PackedVector2Array points=actor["points"];
        const double until=actor["until"],radius=actor["radius"],k=clock<until?1:1-std::clamp((clock-until)/0.4,0.0,1.0);
        if (points.is_empty() || k<=0) continue;
        const int index=actor["index"];
        for (int i=0;i<points.size();++i) {
            const double f=double(i+1)/points.size(),drop=i%3==0?1:0.55;
            const Vector2 point=logical(points[i])+Vector2((hash(i*3.1+index)-0.5)*2,(hash(i*5.7+index)-0.5)*2);
            const double left=std::max(0.05,f*k),size=(0.8+2.6*f)*drop*radius*wl_*0.22,age=1-left;
            const double heat=std::min(0.999,std::pow(age,0.62)+hash(i+index*7)*0.1),r=size*(0.55+0.45*std::min(1.0,age*7))*(1-age*0.55);
            const int color_index=std::min(7,int(std::floor(heat*8)));
            const Color color=palette[color_index];
            if (color_index>=7) {blended_disc(point,r,color,std::min(1.0,left*3)*0.85);continue;}
            solid(point,r,palette[std::min(8,color_index+2)]);
            solid(point+Vector2(-r*0.16,-r*0.22),r*0.78,color);
            if (r>1.6) solid(point+Vector2(0,-r*0.9),r*0.42,color);
            if (color_index<=3 && r>1.8) solid(point+Vector2(-r*0.28,-r*0.34),r*0.36,palette[std::max(0,color_index-1)]);
            if (color_index<6) reference_glow(point,r*2.4+2,color,0.14*left,fade,light_strength);
        }
    }
    return reference_flags_;
}
}
