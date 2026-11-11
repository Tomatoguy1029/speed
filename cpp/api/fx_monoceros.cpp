// 一角獣の薙ぎ。角の実軌道と同じ順で色を重ね、扇形に含まれる画素だけを調べる。
#include "fx_raster.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
namespace godot {
int SpeedFxRaster::monoceros_crescent(Array points,double head,double tail,double width,PackedColorArray ramp,double age,double radius_scale,double fade,double light_strength) {
    reference_flags_=0;
    if (points.size()<2 || ramp.size()<3 || head-tail<0.005 || width<0.3) return 0;
    const Dictionary first=points[0];const Vector2 center=first["center"],origin=logical(center);
    constexpr double PI=3.14159265358979323846;
    for (int i=0;i<points.size()-1;++i) {
        const Dictionary a=points[i],b=points[i+1];const double av=a["v"],bv=b["v"];
        if (bv<=tail || av>=head || bv-av<0.00001) continue;
        const Vector2 atip=a["tip"],btip=b["tip"];
        const double angle=(atip-center).angle(),span=Math::angle_difference(angle,double((btip-center).angle()));
        if (std::abs(span)<0.00001) continue;
        const double ra=atip.distance_to(center)*wl_*radius_scale,rb=btip.distance_to(center)*wl_*radius_scale;
        const double bounds=std::max(ra,rb)+2.0,outer=std::max(ra,rb)+1.0,inner=std::max(0.0,std::min(ra,rb)-width-1.0);
        Vector2 lo=origin+Vector2(std::cos(angle)*inner,std::sin(angle)*inner),hi=lo;
        const auto include=[&](double theta) {
            for (double r:{inner,outer}) {const Vector2 p=origin+Vector2(std::cos(theta)*r,std::sin(theta)*r);lo=lo.min(p);hi=hi.max(p);}
        };
        include(angle);include(angle+span);
        for (int axis=0;axis<4;++axis) {const double theta=axis*PI/2,f=Math::angle_difference(angle,theta)/span;if (f>=0 && f<=1) include(theta);}
        // 元のshadeの四隅の単精度丸めと、角度計算の境界を保つ。
        const Vector2 original_lo(origin.x-bounds,origin.y-bounds),original_hi(origin.x+bounds,origin.y+bounds);
        const int x0=std::max({0,int(std::floor(original_lo.x)),int(std::floor(lo.x))-2}),x1=std::min({w_-1,int(std::ceil(original_hi.x)),int(std::ceil(hi.x))+2});
        const int y0=std::max({0,int(std::floor(original_lo.y)),int(std::floor(lo.y))-2}),y1=std::min({h_-1,int(std::ceil(original_hi.y)),int(std::ceil(hi.y))+2});
        for (int y=y0;y<=y1;++y) for (int x=x0;x<=x1;++x) {
            const Vector2 delta=Vector2(x+0.5,y+0.5)-origin;
            const double radius=delta.length(),f=Math::angle_difference(angle,double(delta.angle()))/span;
            if (f<0 || f>=1) continue;
            const double edge=ra+(rb-ra)*f;
            if (radius>edge+0.5 || radius<edge-width-1.0) continue;
            const double along=av+(bv-av)*f;
            if (along<tail || along>head) continue;
            const double v=(along-tail)/(head-tail),w=width*std::pow(std::sin(PI*std::pow(v,2.2)),0.6);
            if (w<0.35) continue;
            const double q=(edge-radius)/w;
            if (q<0 || q>1) continue;
            const int index=q<0.22 && age<0.5?0:int(std::round(q*(ramp.size()-1)*0.75+age*2.4-v*0.8+0.4));
            reference_dot(Vector2(x,y),ramp[ramp.size()-1-std::clamp(index,0,int(ramp.size()-1))],std::min(1.0,v/0.4),fade);
        }
        if (bv>=tail && bv<=head) {
            const Vector2 tip=logical(btip),inward=(origin-tip).normalized(),at=origin+(tip-origin)*radius_scale+inward*width*0.4;
            reference_glow(at,5.0+width,ramp[ramp.size()-3],0.22*(1.0-age)*(bv-tail)/(head-tail),fade,light_strength);
        }
    }
    return reference_flags_;
}
}
