// 共通Painterの光と単色の円。画素の訪問順・丸め・合成をGDScriptとそろえる。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
int SpeedFxRaster::canvas_glow_line(Vector2 a,Vector2 b,double radius,Color color,double strength,double fade,double light_strength) {
    reference_flags_=0;
    reference_glow_line(a,b,radius,color,strength,fade,light_strength);
    return reference_flags_;
}
int SpeedFxRaster::canvas_glow_ring(Vector2 center,double radius,double width,Color color,double strength,double fade,double light_strength) {
    reference_flags_=0;
    if (width<1 || strength<=0.004) return 0;
    const double extent=radius+width;
    for (int y=std::max(0,int(std::floor(center.y-extent)));y<=std::min(h_-1,int(std::ceil(center.y+extent)));++y) {
        for (int x=std::max(0,int(std::floor(center.x-extent)));x<=std::min(w_-1,int(std::ceil(center.x+extent)));++x) {
            const double d=std::abs(Vector2(x+0.5,y+0.5).distance_to(center)-radius)/width;
            if (d<1) reference_light(Vector2(x,y),color,(1-d)*(1-d)*strength*fade*light_strength);
        }
    }
    return reference_flags_;
}
int SpeedFxRaster::canvas_circle(double cx,double cy,double radius,Color color,double alpha,double fade,bool blended) {
    reference_flags_=0;
    if (radius<0.5 || color.a<=0) return 0;
    const Vector2 lo(cx-radius,cy-radius),hi(cx+radius,cy+radius),center(cx,cy);
    const double r2=radius*radius;
    for (int y=std::max(0,int(std::floor(lo.y)));y<=std::min(h_-1,int(std::ceil(hi.y)));++y) {
        for (int x=std::max(0,int(std::floor(lo.x)));x<=std::min(w_-1,int(std::ceil(hi.x)));++x) {
            const Vector2 delta=blended?Vector2(x+0.5,y+0.5)-center:Vector2(x+0.5-cx,y+0.5-cy);
            if (delta.length_squared()>r2) continue;
            if (!blended) {reference_dot(Vector2(x,y),color,alpha,fade);continue;}
            reference_blend(Vector2(x,y),color,alpha,fade);
        }
    }
    return reference_flags_;
}
int SpeedFxRaster::canvas_beam(double x0,double y0,double x1,double y1,double width,Color color,double alpha,double fade) {
    reference_flags_=0;
    const Vector2 a(x0,y0),b(x1,y1),delta=b-a;
    const double radius=width*0.5,l2=std::max(double(delta.length_squared()),0.000000001);
    const Vector2 lo(std::min(x0,x1)-radius,std::min(y0,y1)-radius),hi(std::max(x0,x1)+radius,std::max(y0,y1)+radius);
    for (int y=std::max(0,int(std::floor(lo.y)));y<=std::min(h_-1,int(std::ceil(hi.y)));++y) {
        for (int x=std::max(0,int(std::floor(lo.x)));x<=std::min(w_-1,int(std::ceil(hi.x)));++x) {
            const Vector2 point(x+0.5,y+0.5);
            const double u=std::clamp(double((point-a).dot(delta))/l2,0.0,1.0);
            if (point.distance_to(a+delta*u)<=radius) reference_dot(Vector2(x,y),color,alpha,fade);
        }
    }
    return reference_flags_;
}

}
