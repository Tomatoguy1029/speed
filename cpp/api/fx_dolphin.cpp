// いるか座の音波。dolphin_reference.gd と同じ画素・描画順で帯と円弧を描く。
#include "fx_raster.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
namespace godot {
namespace {
constexpr double TAU=6.28318530717958647692;
double mix1(double a,double b,double t) {return a+(b-a)*t;}
double hash1(double x) {const double v=std::sin(x*127.1+311.7)*43758.5453;return v-std::floor(v);}
}
int SpeedFxRaster::dolphin_band(Vector2 center,double radius,double a0,double a1,double width,PackedColorArray palette,double alpha,double dissolve,double fade) {
    reference_flags_=0;
    if (radius<=0 || width<=0 || alpha<=0 || palette.size()<3) return 0;
    alpha=std::max(0.14,alpha);
    const int steps=std::max(8,int(std::round((a1-a0)*radius*2)));
    for (int i=0;i<=steps;++i) {
        const double u=double(i)/steps,angle=mix1(a0,a1,u),ww=width*std::pow(std::min(1.0,std::min(u,1-u)/0.22),0.75);
        if (ww<0.3) continue;
        for (double q=-ww;q<=ww;q+=0.5) {
            const double e=q/ww,x=center.x+std::cos(angle)*(radius+q),y=center.y+std::sin(angle)*(radius+q);
            if (dissolve<=0 || hash1(std::round(x)*12.9898+std::round(y)*78.233)>=dissolve) reference_dot(Vector2(std::floor(x),std::floor(y)),palette[e>0.55?0:e> -0.45?1:2],alpha,fade);
        }
    }
    return reference_flags_;
}
int SpeedFxRaster::dolphin_arc(Vector2 center,double radius,double a0,double a1,Color color,double alpha,double fade) {
    reference_flags_=0;
    for (int y=std::max(0,int(std::floor(center.y-radius)));y<=std::min(h_-1,int(std::ceil(center.y+radius)));++y) {
        for (int x=std::max(0,int(std::floor(center.x-radius)));x<=std::min(w_-1,int(std::ceil(center.x+radius)));++x) {
            const Vector2 d=Vector2(x+0.5,y+0.5)-center;
            const double length=d.length(),angle=Math::fposmod(double(d.angle())-a0,TAU);
            if (length<=radius && length>=radius-1 && angle<=a1-a0) reference_dot(Vector2(x,y),color,alpha,fade);
        }
    }
    return reference_flags_;
}


}
