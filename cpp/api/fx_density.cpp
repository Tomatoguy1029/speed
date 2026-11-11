// 動く残り火の3層密度場。足跡の範囲、加算順、float32への丸めを維持する。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
#include <unordered_set>
#include <godot_cpp/variant/packed_int64_array.hpp>
namespace godot {
namespace {
double smooth(double a,double b,double x) {const double t=std::clamp((x-a)/(b-a),0.0,1.0);return t*t*(3-2*t);}
}
int SpeedFxRaster::density_field(PackedVector2Array points,PackedFloat64Array radii,PackedByteArray layers,Vector2i origin,int width,int height,Dictionary settings,PackedColorArray palette,double fade,double light_strength) {
    reference_flags_=0;
    if (width<=0 || height<=0 || palette.size()<3 || points.size()!=radii.size() || points.size()!=layers.size()) return 0;
    const PackedFloat64Array weights=settings.get("weights",PackedFloat64Array());
    if (!weights.is_empty() && weights.size()!=points.size()) return 0;
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
            density_[index]=float(double(density_[index])+(weights.is_empty()?1.0:weights[i])*std::exp(-d2*3.2)*(1-smooth(0.72,1,std::sqrt(d2))));
        }
    }
    const auto read=[&](double x,double y,int channel) {
        const int ix=std::clamp(int(std::floor(x+0.5)),0,width-1),iy=std::clamp(int(std::floor(y+0.5)),0,height-1);
        return density_[(size_t(iy)*width+ix)*3+channel];
    };
    struct Mask {std::unordered_set<int64_t> keys;double cell;Vector2 origin,logical_origin;};
    std::vector<Mask> masks;
    const Array input_masks=settings.get("masks",Array());
    for (int i=0;i<input_masks.size();++i) {
        const Dictionary row=input_masks[i];
        Mask mask;mask.cell=row["cell"];mask.origin=row["origin"];mask.logical_origin=row["logical_origin"];
        if (row.has("cells")) {
            const PackedInt64Array cells=row["cells"];mask.keys.reserve(cells.size());
            for (int64_t k=0;k<cells.size();++k) mask.keys.insert(cells[k]);
        } else {
            const Dictionary keys=row["keys"];const Array cells=keys.keys();mask.keys.reserve(cells.size());
            for (int64_t k=0;k<cells.size();++k) mask.keys.insert(int64_t(cells[k]));
        }
        masks.push_back(std::move(mask));
    }
    const auto visible=[&](int x,int y) {
        if (masks.empty()) return true;
        for (const auto &mask:masks) {
            if (mask.cell<=0) continue;
            const Vector2 world=mask.origin+(Vector2(x+0.5,y+0.5)-mask.logical_origin)/wl_;
            const uint64_t key=(uint64_t(uint32_t(int64_t(std::floor(world.x/mask.cell))))<<32)|uint32_t(int64_t(std::floor(world.y/mask.cell)));
            if (mask.keys.count(int64_t(key))) return true;
        }
        return false;
    };
    const double clock=settings["clock"],logical_pixel=settings["logical_pixel"],deformation=settings["deformation"],v_gain=settings["v_gain"],v_deformation=settings["v_deformation"],threshold=settings["threshold"],glow_radius=settings["glow_radius"];
    const PackedFloat64Array strengths=settings["strengths"];
    const bool local=settings.get("local",false),smoke=settings.get("smoke",false);
    const double offset_x=settings.get("offset_x",0.0),offset_y=settings.get("offset_y",0.0);
    const int edge=bool(settings.get("include_edge",false))?1:0;
    if (strengths.size()<3) return 0;
    // 密度場は全体を保持し、描画だけを光の届く余白付きで画面内へ絞る。
    const double margin=std::max(0.0,glow_radius)+2;
    const int x0=local?std::max(0,int(std::floor(-offset_x-origin.x-margin))):std::max(0,-origin.x);
    const int x1=local?std::min(width,int(std::ceil(w_-offset_x-origin.x+margin))):std::min(width,w_+edge-origin.x);
    const int y0=local?std::max(0,int(std::floor(-offset_y-origin.y-margin))):std::max(0,-origin.y);
    const int y1=local?std::min(height,int(std::ceil(h_-offset_y-origin.y+margin))):std::min(height,h_+edge-origin.y);
    if (x0>=x1 || y0>=y1) return 0;
    std::vector<double> vertical_wave(size_t(x1-x0));
    for (int x=x0;x<x1;++x) {
        const double wx=(x+origin.x)*logical_pixel;
        vertical_wave[x-x0]=std::cos(wx*0.08+clock*3)*v_gain*v_deformation;
    }
    for (int y=y0;y<y1;++y) {
        const int py=y+origin.y;
        const double wy=py*logical_pixel,row_wave=std::sin(wy*0.075-clock*4.4);
        for (int x=x0;x<x1;++x) {
            const int px=x+origin.x;
            const double wx=px*logical_pixel;
            const double u=(row_wave+std::sin(wx*0.11+wy*0.033+clock*2.1))*deformation,v=vertical_wave[x-x0];
            if (!visible(px,py) || read(x+u,y+v,0)<threshold) continue;
            const bool inner=read(x+u,y+v,1)>=threshold;
            const Vector2 cell=local?Vector2(offset_x+px+0.5,offset_y+py+0.5):Vector2(px,py);
            if (smoke) {
                const double oldness=read(x+u,y+v,2)/std::max(0.0001,double(read(x+u,y+v,0)));
                const double gone=smooth(0.45,0.95,oldness);
                const double hash=std::sin((px*12.9898+py*78.233)*127.1+311.7)*43758.5453;
                if (hash-std::floor(hash)<gone) continue;
                const Color color=palette[inner?0:1];
                reference_blend(cell,color,(inner?0.55:0.4)*(1-gone*0.35),fade);
            } else {
                const bool core=inner && read(x+u,y+v,2)>=threshold;
                const int level=core?2:inner?1:0;
                reference_dot(cell,palette[level],1,fade);
                if ((px&3)==0 && (py&3)==0) reference_glow(local?Vector2(offset_x+px,offset_y+py):Vector2(px,py),glow_radius,palette[level],strengths[level],fade,light_strength);
            }
        }
    }
    return reference_flags_;
}
}
