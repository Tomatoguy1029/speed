// ぎょしゃ座の轍とやまねこ座の爪。共通画素描画と同じ式・色・順序を使う。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
namespace {
constexpr double PI=3.141592653589793;
double mix1(double a,double b,double t) {return a+(b-a)*t;}
double smooth(double a,double b,double x) {const double t=std::clamp((x-a)/(b-a),0.0,1.0);return t*t*(3-2*t);}
double hash1(double x) {const double v=std::sin(x*127.1+311.7)*43758.5453;return v-std::floor(v);}
}
void SpeedFxRaster::reference_glow(Vector2 center,double radius,Color color,double strength) {
    if (radius<1 || strength<=0.004) return;
    for (int y=std::max(0,int(std::floor(center.y-radius)));y<=std::min(h_-1,int(std::ceil(center.y+radius)));++y) {
        for (int x=std::max(0,int(std::floor(center.x-radius)));x<=std::min(w_-1,int(std::ceil(center.x+radius)));++x) {
            const double d=Vector2(x+0.5,y+0.5).distance_to(center)/radius;
            if (d<1) reference_light(Vector2(x,y),color,(1-d)*(1-d)*strength);
        }
    }
}
int SpeedFxRaster::auriga_trail(PackedVector2Array points,PackedFloat64Array strengths,double width,PackedColorArray palette,double clock,double fade,double light_strength) {
    reference_flags_=0;
    if (points.size()<2 || strengths.size()!=points.size() || palette.size()<5) return 0;
    const auto random=[](int x,int y,int seed) {
        uint32_t h=0x9e3779b9;
        for (int n:{x,y,seed}) {h=(h^uint32_t(n))*0x85ebca6b;h^=h>>13;h*=0xc2b2ae35;h^=h>>16;}
        return double(h)/4294967296.0;
    };
    const auto noise=[&](double x,double y) {
        const int ix=int(std::floor(x)),iy=int(std::floor(y));
        const double fx=x-ix,fy=y-iy,ux=fx*fx*(3-2*fx),uy=fy*fy*(3-2*fy);
        return mix1(mix1(random(ix,iy,3),random(ix+1,iy,3),ux),mix1(random(ix,iy+1,3),random(ix+1,iy+1,3),ux),uy)*2-1;
    };
    double total=0,cumulative=0;
    for (int i=1;i<points.size();++i) total+=points[i-1].distance_to(points[i]);
    for (int i=1;i<points.size();++i) {
        const Vector2 delta=points[i]-points[i-1];
        const double length=delta.length();
        if (length<0.01) continue;
        const Vector2 u=delta/length,normal(-u.y,u.x);
        for (double d=0;d<length;d+=0.5) {
            const double c=cumulative+d,k=mix1(strengths[i-1],strengths[i],d/length);
            if (k<=0.01) continue;
            const double taper=std::pow(std::min({1.0,c/10.0,(total-c)/6.0}),0.7);
            const double h=width*(0.7+0.9*(noise(c*0.22,clock*9)*0.5+0.5))*k*taper;
            if (h<0.3) continue;
            const Vector2 point=points[i-1]+u*d;
            for (double q=-h;q<=h;q+=0.5) {
                const double edge=std::abs(q)/h;
                const int level=edge<0.25?4:edge<0.5?3:edge<0.8?2:1;
                const Vector2 at=point+normal*q;
                reference_dot(at,palette[level],k*(edge>0.8?0.6:1),fade);
            }
            if ((int(std::round(c*2))&3)==0) reference_light(point,palette[2],0.22*k*fade*light_strength);
        }
        cumulative+=length;
    }
    return reference_flags_;
}
int SpeedFxRaster::lynx_scratch(Vector2 origin,double angle,double side,double size,double span,double cut,PackedColorArray palette,Dictionary settings,double fade,double light_strength) {
    reference_flags_=0;
    if (palette.size()<5 || size<=0) return 0;
    const double gap=settings["gap"],space0=settings["space0"],space1=settings["space1"];
    const double alpha=std::min(1.0,double(settings["intensity"]));
    const Vector2 forward=Vector2::from_angle(angle),across=Vector2(-forward.y,forward.x)*side;
    const auto at=[&](double progress) {
        const Vector2 center=origin+(across*(0.12+gap)-forward*0.70)*size;
        const double phi=-PI/2+span*(1-progress);
        return center+(across*1.15*std::cos(phi)-forward*0.85*std::sin(phi))*size;
    };
    const auto mark=[&](int k,double progress) {
        const Vector2 tangent=(at(std::min(1.0,progress+0.01))-at(std::max(0.0,progress-0.01))).normalized();
        return at(progress)+Vector2(-tangent.y,tangent.x)*((k-1)*mix1(space0,space1,progress)*size);
    };
    constexpr double from[3]={0.03,0,0.05},to[3]={0.9,1,0.86};
    const int count=std::max(10,int(std::floor(size*wl_*1.6+0.5)));
    const double thickness=0.07*size*wl_*0.9;
    for (int k=0;k<3;++k) {
        for (int i=0;i<count;++i) {
            const double m=double(i)/count,a=mix1(from[k],to[k],m),b=mix1(from[k],to[k],double(i+1)/count);
            if (a>cut) break;
            const Vector2 start=logical(mark(k,a)),end=logical(mark(k,std::min(cut,b)));
            const double width=thickness*smooth(0,0.1,m)*std::pow(1-m,0.7)*(0.85+0.3*hash1(k*17+std::floor(m*9)));
            if (width<0.25) {reference_dot(start,palette[3],alpha*0.8,fade);continue;}
            const Vector2 direction=end-start,normal=Vector2(-direction.y,direction.x).normalized();
            for (double q=-width;q<=width;q+=0.5) {
                const double edge=std::abs(q)/width;
                const Vector2 point=start+normal*q;
                reference_dot(point,palette[edge<0.4?4:edge<0.75?3:2],alpha,fade);
            }
            if (i%3==0) reference_light(start,palette[2],0.25*alpha*fade*light_strength);
        }
        if (cut<to[k] && cut>from[k]) reference_glow(logical(mark(k,cut)),4,palette[4],0.6*alpha*fade*light_strength);
    }
    return reference_flags_;
}
}
