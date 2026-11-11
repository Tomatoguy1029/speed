// fx_reference_primitives.gdの定規座用描画。pixelFX由来の式とMITの帰属は同スクリプトに従う。
#include "fx_raster.h"
#include <godot_cpp/variant/vector3.hpp>
#include <algorithm>
#include <array>
#include <cmath>

namespace godot {
namespace {
constexpr int BAYER[] = {0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
double smooth(double a,double b,double x) {const double t=std::clamp((x-a)/(b-a),0.0,1.0);return t*t*(3-2*t);}
double hash(double x) {const double v=std::sin(x*127.1+311.7)*43758.5453;return v-std::floor(v);}
double positive_mod(double x) {return x-std::floor(x);}
std::array<Color,5> palette(Color color) {
    std::array<Color,5> result;
    // 元のrampはVector2の係数を読むため、その単精度への丸めも合わせる。
    const float scale[]={0.35f,0.6f,1,1,1},white[]={0,0,0,0.45f,1};
    for (int i=0;i<5;++i) {
        const auto channel=[&](double c) {const double base=c*scale[i];return float(std::round((base+(1-base)*white[i])*255)/255);};
        result[i]=Color(channel(color.r),channel(color.g),channel(color.b));
    }
    return result;
}
}

// fx_reference_canvas.Painter の切り捨て・ディザ・色の量子化をそのまま使う。
void SpeedFxRaster::reference_dot(Vector2 p,Color color,double alpha,double fade) {
    if (alpha<=0 || color.a<=0) return;
    const int x=int(std::floor(p.x)),y=int(std::floor(p.y));
    const double a=alpha*fade;
    double k=1;
    if (a>=0.12 && a<0.999) k=0.2+0.8*a;
    else if (a<1 && a<=(BAYER[((y&3)<<2)|(x&3)]+0.5)/16.0) return;
    if (x<0 || x>=w_ || y<0 || y>=h_) return;
    auto *q=c_+(y*w_+x)*4;
    q[0]=uint8_t(std::clamp(double(color.r),0.0,1.0)*255*k);
    q[1]=uint8_t(std::clamp(double(color.g),0.0,1.0)*255*k);
    q[2]=uint8_t(std::clamp(double(color.b),0.0,1.0)*255*k);
    q[3]=k!=1?255:uint8_t(std::clamp(double(color.a),0.0,1.0)*255);
    if (q[3]) reference_flags_|=1;
}
void SpeedFxRaster::reference_light(Vector2 p,Color color,double strength) {
    if (strength<=0.004) return;
    const int x=int(std::floor(p.x)),y=int(std::floor(p.y));
    if (x<0 || x>=w_ || y<0 || y>=h_) return;
    auto *q=l_+(y*w_+x)*4;
    q[0]=uint8_t(std::min(255,int(q[0]+int(double(color.r)*255)*strength)));
    q[1]=uint8_t(std::min(255,int(q[1]+int(double(color.g)*255)*strength)));
    q[2]=uint8_t(std::min(255,int(q[2]+int(double(color.b)*255)*strength)));
    if (q[0] || q[1] || q[2]) reference_flags_|=2;
}
void SpeedFxRaster::reference_glow_line(Vector2 a,Vector2 b,double radius,Color color,double strength) {
    if (radius<1 || strength<=0.004) return;
    const Vector2 delta=b-a;
    const double l2=std::max(double(delta.length_squared()),0.000000001);
    for (int y=std::max(0,int(std::floor(std::min(a.y,b.y)-radius)));y<=std::min(h_-1,int(std::ceil(std::max(a.y,b.y)+radius)));++y) {
        double from=0,to=1;
        if (std::abs(delta.y)>0.000001) {
            const double t0=(y+0.5-radius-a.y)/delta.y,t1=(y+0.5+radius-a.y)/delta.y;
            from=std::clamp(std::min(t0,t1),0.0,1.0);to=std::clamp(std::max(t0,t1),0.0,1.0);
        }
        const double left=std::min(a.x+delta.x*from,a.x+delta.x*to)-radius-1;
        const double right=std::max(a.x+delta.x*from,a.x+delta.x*to)+radius+1;
        for (int x=std::max(0,int(std::floor(left)));x<=std::min(w_-1,int(std::ceil(right)));++x) {
            const Vector2 p(x+0.5,y+0.5);
            const double u=std::clamp(double((p-a).dot(delta))/l2,0.0,1.0);
            const double d=p.distance_to(a+delta*u)/radius;
            if (d<1) reference_light(Vector2(x,y),color,(1-d)*(1-d)*strength);
        }
    }
}

int SpeedFxRaster::ruler_beam(Vector2 a,Vector2 b,double width,double time,Color color,double alpha,double fade,double light_strength) {
    reference_flags_=0;
    const auto colors=palette(color);
    const Vector2 delta=b-a;
    const double length=delta.length();
    if (length<1) return 0;
    const Vector2 direction=delta/length,normal(-direction.y,direction.x);
    alpha=std::clamp(alpha,0.0,1.0);
    for (double d=0;d<=length;d+=0.5) {
        const double ends=std::min(1.0,(d+2)/4);
        const double width_at=width*(1+0.1*std::sin(d*0.35-time*40))*ends;
        const int pulse=positive_mod(d*0.03-time*3)<0.06?1:0;
        const Vector2 point=a+direction*d;
        for (double off=-width_at*1.25;off<=width_at*1.25;off+=0.5) {
            const double q=std::abs(off)/std::max(width_at,0.01);
            int level=q<0.25?0:q<0.45?1:q<0.7?2:q<0.95?3:4;
            level=std::max(0,level-pulse);
            reference_dot(point+normal*off,colors[4-level],alpha*(level==4?0.45:1),fade);
        }
        if ((int(std::floor(d*2+0.5))&5)==0) reference_light(point,colors[2],0.25*alpha*fade*light_strength);
    }
    reference_glow_line(a,b,width*2.6+3,colors[2],0.35*alpha*fade*light_strength);
    return reference_flags_;
}

int SpeedFxRaster::ruler_rail(Vector2 a,Vector2 b,Dictionary options,double fade,double light_strength) {
    reference_flags_=0;
    const auto colors=palette(options["color"]);
    const Vector2 delta=b-a;
    const double length=delta.length();
    if (length<1) return 0;
    const Vector2 direction=delta/length,normal(-direction.y,direction.x);
    const double k=std::clamp(double(options["k"]),0.0,1.0);
    const double seed=options.get("seed",0),time=double(options.get("time",0))/4;
    const double side=double(options.get("rail",2.2))*(0.6+0.4*k),intensity=options.get("intensity",1);
    std::array<Vector3,11> packets;
    for (int i=0;i<11;++i) {
        const double key=seed*3.17+i*19.13,speed=hash(key+2)<0.5?1:2;
        packets[i]=Vector3(positive_mod(hash(key+1)+speed*time),0.035+(0.102-0.035)*hash(key+5),0.22+(0.67-0.22)*hash(key+7));
    }
    for (double d=0;d<=length;++d) {
        double envelope=smooth(0,6,d)*smooth(0,14,length-d);
        if (options.has("reveal")) {const double reveal=double(options["reveal"])*length;envelope*=smooth(reveal,reveal-8,d);}
        if (envelope<=0.04) continue;
        const double along=d/length;
        double total=0;
        for (const auto &packet:packets) {const double distance=positive_mod(along-packet.x+0.5)-0.5;total+=std::exp(-std::pow(distance/packet.y,2))*packet.z;}
        const double flow=1-std::exp(-total*0.9);
        const Vector2 point=a+direction*d;
        const double brightness=envelope*(0.35+0.65*k)*(0.7+0.6*flow)*intensity;
        const int level=brightness>0.95?4:brightness>0.62?3:brightness>0.3?2:1;
        reference_dot(point,colors[level],1,fade);
        reference_light(point,colors[2],0.16*envelope*(0.4+k)*(0.6+flow)*intensity*fade*light_strength);
        reference_light(point+normal*side,colors[2],0.22*envelope*(0.3+0.7*k)*(0.6+0.6*flow)*intensity*fade*light_strength);
        reference_light(point-normal*side,colors[1],0.18*envelope*(0.3+0.7*k)*(0.6+0.6*flow)*intensity*fade*light_strength);
    }
    reference_glow_line(a,b,2.5+2*k,colors[2],0.10*k*intensity*fade*light_strength);
    return reference_flags_;
}
}
