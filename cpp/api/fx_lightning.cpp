// 雷の線を同じ半画素間隔で押し、重なる画素には最も明るい段を残す。
// aquila_lightning.gd の pixelFX 由来の式・帰属に従う。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
#include <unordered_map>
namespace godot {
int SpeedFxRaster::lightning_ink(Array paths,double strength,PackedColorArray colors,double scale,bool thin,double glow_strength,double fade,double light_strength) {
    reference_flags_=0;
    if (strength<=0.02 || colors.size()<8) return 0;
    std::unordered_map<int,int> grid;
    const auto mark=[&](int x,int y,int level) {
        if (x<0 || y<0 || x>=w_ || y>=h_) return;
        auto &saved=grid[y*w_+x];
        saved=std::max(saved,level);
    };
    const auto stamp=[&](Vector2 point,double radius,int level) {
        if (radius<=0.5) {mark(int(std::floor(point.x)),int(std::floor(point.y)),level);return;}
        for (int y=std::max(0,int(std::floor(point.y-radius)));y<=std::min(h_-1,int(std::ceil(point.y+radius)));++y)
            for (int x=std::max(0,int(std::floor(point.x-radius)));x<=std::min(w_-1,int(std::ceil(point.x+radius)));++x)
                if (Vector2(x+0.5,y+0.5).distance_squared_to(point)<=radius*radius) mark(x,y,level);
    };
    for (int path_index=0;path_index<paths.size();++path_index) {
        const Dictionary path=paths[path_index];
        const double width=path["width"];
        const bool trunk=width>=1;
        if (!trunk && strength<0.5) continue;
        const double outer=thin?(trunk && strength>0.45?1.2:0):((trunk?(strength>0.6?2.1:1.6):1.1)*scale);
        const double body=thin?0.5:((trunk?(strength>0.6?1.3:0.8):0.5)*scale);
        const Array points=path["points"];
        for (int i=0;i+1<points.size();++i) {
            const Vector2 a=points[i],b=points[i+1];
            const double length=std::max(1.0,double(a.distance_to(b)));
            for (double d=0;d<=length;d+=0.5) {
                const Vector2 point=a+(b-a)*d/length;
                if (outer>0) stamp(point,outer,1);
                stamp(point,body,trunk?3:2);
                if (trunk && strength>0.3) stamp(point,0,4);
            }
        }
        for (int i=0;i+1<points.size();i+=3)
            reference_glow(points[i],(trunk?(thin?8.0:14.0):6.0)*scale,colors[4],glow_strength*strength*width,fade,light_strength);
    }
    const int levels[]={2,4,5,7};
    for (const auto &pixel:grid) reference_dot(Vector2(pixel.first%w_,pixel.first/w_),colors[levels[pixel.second-1]],1,fade);
    return reference_flags_;
}
int SpeedFxRaster::aquila_cracks(Array paths,Vector2 center,double heat,PackedColorArray colors,double fade) {
    reference_flags_=0;
    if (colors.size()<7) return 0;
    const Color dark(20/255.0f,16/255.0f,32/255.0f);
    for (int row=0;row<paths.size();++row) {
        const Dictionary path=paths[row];const Array points=path["points"];
        for (int i=0;i<points.size();++i) {
            const Vector2 point=center+Vector2(points[i]);
            const double n=point.x*7.1+point.y*3.3,value=std::sin(n*127.1+311.7)*43758.5453;
            const double h=heat*(1-0.5*double(i)/points.size())-(value-std::floor(value))*0.25;
            const Color color=h>0.6?colors[6]:h>0.35?colors[4]:h>0.12?colors[2]:dark;
            reference_dot(point,color,1,fade);
        }
    }
    return reference_flags_;
}
int SpeedFxRaster::aquila_wake(Array history,double clock,double strength,PackedColorArray colors,double fade,double light_strength) {
    reference_flags_=0;
    if (history.size()<2 || strength<=0 || colors.size()<7) return 0;
    for (int i=1;i<history.size();++i) {
        const Dictionary previous=history[i-1],current=history[i];
        const Vector2 a=logical(previous["pos"]),b=logical(current["pos"]),delta=b-a;
        const double u=std::clamp((clock-double(current["time"]))/0.45,0.0,1.0);
        if (u>=1) continue;
        const double width=(1-u)*2.2*strength;
        double length=delta.length();if (length==0) length=1;
        const Vector2 normal=Vector2(-delta.y,delta.x)/length;
        for (double d=0;d<=length;d+=0.5) {
            const Vector2 point=a+delta*d/length;
            for (double q=-width;q<=width;q+=0.5) {
                const double edge=std::abs(q)/std::max(width,0.01);
                const Color color=edge<0.35 && u<0.4?colors[6]:u<0.5?colors[5]:u<0.75?colors[4]:colors[3];
                reference_dot(point+normal*q,color,1,fade);
            }
        }
        if (i%3==0) reference_glow(b,6*(1-u)+2,colors[4],0.3*(1-u)*strength,fade,light_strength);
    }
    return reference_flags_;
}

}
