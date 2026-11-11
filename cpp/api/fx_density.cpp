// 動く残り火の3層密度場。足跡の範囲、加算順、float32への丸めを維持する。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
namespace {
double smooth(double a,double b,double x) {const double t=std::clamp((x-a)/(b-a),0.0,1.0);return t*t*(3-2*t);}
}
int SpeedFxRaster::density_field(PackedVector2Array points,PackedFloat64Array radii,PackedByteArray layers,Vector2i origin,int width,int height,Dictionary settings,PackedColorArray palette,double fade,double light_strength) {
    reference_flags_=0;
    if (width<=0 || height<=0 || palette.size()<3 || points.size()!=radii.size() || points.size()!=layers.size()) return 0;
    density_.resize(size_t(width)*height*3);
    std::fill(density_.begin(),density_.end(),0);
    for (int i=0;i<points.size();++i) {
        const double radius=radii[i];
        const Vector2 point=points[i];
        const int channel=layers[i];
        if (radius<0.3 || channel>2) continue;
        const int x0=std::max(0,int(std::floor(point.x-radius-origin.x))),x1=std::min(width-1,int(std::ceil(point.x+radius-origin.x)));
        const int y0=std::max(0,int(std::floor(point.y-radius-origin.y))),y1=std::min(height-1,int(std::ceil(point.y+radius-origin.y)));
        for (int y=y0;y<=y1;++y) for (int x=x0;x<=x1;++x) {
            const double dx=(x+origin.x+0.5-point.x)/radius,dy=(y+origin.y+0.5-point.y)/radius,d2=dx*dx+dy*dy;
            if (d2>=1) continue;
            const size_t index=(size_t(y)*width+x)*3+channel;
            density_[index]=float(double(density_[index])+std::exp(-d2*3.2)*(1-smooth(0.72,1,std::sqrt(d2))));
        }
    }
    const auto read=[&](double x,double y,int channel) {
        const int ix=std::clamp(int(std::floor(x+0.5)),0,width-1),iy=std::clamp(int(std::floor(y+0.5)),0,height-1);
        return density_[(size_t(iy)*width+ix)*3+channel];
    };
    struct Mask {Dictionary keys;double cell;Vector2 origin,logical_origin;};
    std::vector<Mask> masks;
    const Array input_masks=settings.get("masks",Array());
    for (int i=0;i<input_masks.size();++i) {
        const Dictionary row=input_masks[i];
        masks.push_back({row["keys"],row["cell"],row["origin"],row["logical_origin"]});
    }
    const auto visible=[&](int x,int y) {
        if (masks.empty()) return true;
        for (const auto &mask:masks) {
            if (mask.cell<=0) continue;
            const Vector2 world=mask.origin+(Vector2(x+0.5,y+0.5)-mask.logical_origin)/wl_;
            const uint64_t key=(uint64_t(uint32_t(int64_t(std::floor(world.x/mask.cell))))<<32)|uint32_t(int64_t(std::floor(world.y/mask.cell)));
            if (mask.keys.has(int64_t(key))) return true;
        }
        return false;
    };
    const double clock=settings["clock"],logical_pixel=settings["logical_pixel"],deformation=settings["deformation"],v_gain=settings["v_gain"],v_deformation=settings["v_deformation"],threshold=settings["threshold"],glow_radius=settings["glow_radius"];
    const PackedFloat64Array strengths=settings["strengths"];
    const int edge=bool(settings.get("include_edge",false))?1:0;
    if (strengths.size()<3) return 0;
    for (int y=std::max(0,-origin.y);y<std::min(height,h_+edge-origin.y);++y) {
        const int py=y+origin.y;
        const double wy=py*logical_pixel;
        for (int x=std::max(0,-origin.x);x<std::min(width,w_+edge-origin.x);++x) {
            const int px=x+origin.x;
            const double wx=px*logical_pixel;
            const double u=(std::sin(wy*0.075-clock*4.4)+std::sin(wx*0.11+wy*0.033+clock*2.1))*deformation,v=std::cos(wx*0.08+clock*3)*v_gain*v_deformation;
            if (!visible(px,py) || read(x+u,y+v,0)<threshold) continue;
            const bool inner=read(x+u,y+v,1)>=threshold,core=inner && read(x+u,y+v,2)>=threshold;
            const int level=core?2:inner?1:0;
            reference_dot(Vector2(px,py),palette[level],1,fade);
            if ((px&3)==0 && (py&3)==0) reference_glow(Vector2(px,py),glow_radius,palette[level],strengths[level],fade,light_strength);
        }
    }
    return reference_flags_;
}
}
