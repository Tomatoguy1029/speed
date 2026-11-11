// draco_fx.gd のpixelFX由来の炎と闇。doubleの途中値を保ち、元の画素順で合成する。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
namespace {
double hash(double n) {const double value=std::sin(n*127.1+311.7)*43758.5453;return value-std::floor(value);}
double noise(double x,double seed) {const double i=std::floor(x),f=x-i,a=hash(i*1.37+seed*7.1),b=hash((i+1)*1.37+seed*7.1);return (a+(b-a)*(f*f*(3-2*f)))*2-1;}
double smooth(double a,double b,double x) {const double t=std::clamp((x-a)/(b-a),0.0,1.0);return t*t*(3-2*t);}
}
int SpeedFxRaster::canvas_flame_blade(Dictionary shape,PackedColorArray palette,Array layers,double fade) {
    reference_flags_=0;
    const double x=shape["x"],y=shape["y"],ux=shape["ux"],uy=shape["uy"],length=shape["length"],width=shape["width"],bend=shape["bend"],time=shape["time"],seed=shape["seed"],jitter=shape["jitter"],wobble=shape["wobble"];
    if (length<1) return 0;
    const double nx=-uy,ny=ux;
    for (int i=0;i<layers.size();++i) {
        const Array layer=layers[i];if (layer.size()<3) continue;
        const double lw=layer[0],lh=layer[1];const int index=layer[2];
        if (index<0 || index>=palette.size()) continue;
        const Color color=palette[index];const double full=length*lh;
        for (double r=0;r<=full;r+=0.5) {
            const double u=r/std::max(1.0,full),half=width*lw*std::pow(1-u,0.85)*std::min(1.0,(r+1.5)/3.5)+noise(time*9+ r*0.45,seed)*jitter;
            if (half<0.3) continue;
            const double off=bend*u*u*lh+noise(time*4+r*0.2,seed+7)*u*wobble,cx=x+ux*r+nx*off,cy=y+uy*r+ny*off;
            for (double q=-half;q<=half;q+=0.5) reference_dot(Vector2(std::floor(cx+nx*q),std::floor(cy+ny*q)),color,1,fade);
        }
    }
    return reference_flags_;
}
int SpeedFxRaster::draco_dark_fall(Vector2 center,double age,double warning,double radius,double clock,PackedColorArray palette,double fade) {
    reference_flags_=0;
    if (palette.size()<8 || warning<=0 || radius<=0) return 0;
    const double k=std::clamp(age/warning,0.0,1.0),rr=radius*(1.8+(0.8-1.8)*smooth(0,1,k)),on=smooth(0,0.14,age);
    const int extent=int(std::ceil(rr*1.3));
    for (int y=-extent;y<=extent;++y) for (int x=-extent;x<=extent;++x) {
        const double d=Vector2(x,y).length()/rr;
        if (d>1.3) continue;
        const double edge=1+0.2*noise(std::atan2(double(y),double(x))*2+7+clock*2.4,17),e=d/edge;
        if (e>1.06) continue;
        const Vector2 point(std::floor(double(center.x)+x),std::floor(double(center.y)+y));
        if (e>0.93) reference_blend(point,palette[2],0.9*on*(1.06-e)/0.13,fade);
        else reference_blend(point,palette[e<0.6?7:6],(0.62+0.3*k)*on,fade);
    }
    return reference_flags_;
}
}
