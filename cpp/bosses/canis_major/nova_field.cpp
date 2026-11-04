#include "nova_field.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>

namespace speed {
namespace {
struct Point {double x=0,y=0;};
using Polygon=std::vector<Point>;
double cross(Point a,Point b,Point c) {return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);}
Polygon hull(Polygon points) {
    std::sort(points.begin(),points.end(),[](Point a,Point b){return a.x<b.x || (a.x==b.x && a.y<b.y);});
    points.erase(std::unique(points.begin(),points.end(),[](Point a,Point b){return a.x==b.x && a.y==b.y;}),points.end());
    if (points.size()<3) return {};
    Polygon out;out.reserve(points.size()*2);
    for (const auto &p:points) {while (out.size()>1 && cross(out[out.size()-2],out.back(),p)<=0) out.pop_back();out.push_back(p);}
    const size_t lower=out.size();
    for (auto it=points.rbegin()+1;it!=points.rend();++it) {while (out.size()>lower && cross(out[out.size()-2],out.back(),*it)<=0) out.pop_back();out.push_back(*it);}
    out.pop_back();return out;
}
Polygon clip(const Polygon &in,int axis,double edge,bool lower) {
    Polygon out;if (in.empty()) return out;out.reserve(in.size()+2);
    auto coordinate=[axis](Point p){return axis==0?p.x:p.y;};
    auto inside=[&](Point p){return lower?coordinate(p)>=edge:coordinate(p)<=edge;};
    Point a=in.back();bool a_in=inside(a);
    for (Point b:in) {
        const bool b_in=inside(b);
        if (a_in!=b_in) {const double u=(edge-coordinate(a))/(coordinate(b)-coordinate(a));out.push_back({a.x+(b.x-a.x)*u,a.y+(b.y-a.y)*u});}
        if (b_in) out.push_back(b);
        a=b;a_in=b_in;
    }
    return out;
}
double area(const Polygon &p) {double sum=0;if (p.size()<3) return 0;for (size_t i=0;i<p.size();++i) {const auto &a=p[i],&b=p[(i+1)%p.size()];sum+=a.x*b.y-a.y*b.x;}return std::abs(sum)*0.5;}
bool span(const Polygon &p,double y,double &lo,double &hi) {
    lo=std::numeric_limits<double>::infinity();hi=-lo;
    for (size_t i=0;i<p.size();++i) {
        const auto a=p[i],b=p[(i+1)%p.size()];
        if (a.y==b.y) {if (a.y==y) {lo=std::min({lo,a.x,b.x});hi=std::max({hi,a.x,b.x});}continue;}
        if (y<std::min(a.y,b.y) || y>std::max(a.y,b.y)) continue;
        const double x=a.x+(b.x-a.x)*(y-a.y)/(b.y-a.y);lo=std::min(lo,x);hi=std::max(hi,x);
    }
    return lo<=hi;
}
void raster(const Polygon &polygon,uint32_t width,uint32_t height,std::vector<uint8_t> &plane) {
    if (polygon.size()<3) return;
    double min_y=polygon[0].y,max_y=min_y;
    for (auto p:polygon) {min_y=std::min(min_y,p.y);max_y=std::max(max_y,p.y);}
    const int first=std::max(0,int(std::floor(min_y))),last=std::min(int(height)-1,int(std::ceil(max_y))-1);
    for (int y=first;y<=last;++y) {
        const auto row=clip(clip(polygon,1,y,true),1,y+1,false);if (row.size()<3) continue;
        double min_x=row[0].x,max_x=min_x;for (auto p:row) {min_x=std::min(min_x,p.x);max_x=std::max(max_x,p.x);}
        const int begin=std::max(0,int(std::floor(min_x))),end=std::min(int(width)-1,int(std::ceil(max_x))-1);
        double lo0,hi0,lo1,hi1;const bool full=span(polygon,y,lo0,hi0) && span(polygon,y+1,lo1,hi1);
        const double left=full?std::max(lo0,lo1):0,right=full?std::min(hi0,hi1):0;
        for (int x=begin;x<=end;++x) {
            const double coverage=full && x>=left && x+1<=right?1.0:std::clamp(area(clip(clip(row,0,x,true),0,x+1,false)),0.0,1.0);
            const int source=std::clamp(int(std::lround(coverage*255.0)),0,255);auto &dest=plane[size_t(y)*width+x];
            dest=uint8_t(std::min(255,source+(int(dest)*(255-source)+127)/255));
        }
    }
}
void accumulate_blurred(const std::vector<uint8_t> &plane,uint32_t width,uint32_t height,std::vector<uint8_t> &sum) {
    constexpr double sigma=0.8;std::array<double,7> kernel{};double total=0;
    for (int k=-3;k<=3;++k) {kernel[k+3]=std::exp(-(k*k)/(2*sigma*sigma));total+=kernel[k+3];}
    for (auto &v:kernel) v/=total;
    std::vector<double> horizontal(plane.size(),0);
    for (uint32_t y=0;y<height;++y) for (uint32_t x=0;x<width;++x)
        for (int k=-3;k<=3;++k) {const int sx=int(x)+k;if (sx>=0 && sx<int(width)) horizontal[size_t(y)*width+x]+=plane[size_t(y)*width+sx]*kernel[k+3];}
    for (uint32_t y=0;y<height;++y) for (uint32_t x=0;x<width;++x) {
        double value=0;for (int k=-3;k<=3;++k) {const int sy=int(y)+k;if (sy>=0 && sy<int(height)) value+=horizontal[size_t(sy)*width+x]*kernel[k+3];}
        auto &dest=sum[size_t(y)*width+x];
        const int source=std::clamp(int(std::lround(value/9.0)),0,255);
        dest=uint8_t(std::min(255,int(dest)+source));
    }
}
}

bool CanisNovaField::update(RunRuntime &r,BossBodyState &body,CanisNovaState &field,godot::Vector2 source,double range) {
    const auto &camera=r.state.control;
    if (camera.logical_size.x<=0 || camera.logical_size.y<=0 || camera.camera_zoom<=0 || r.content->canis_nova_fx.empty() || r.content->canis_nova_hull.size()<3) return false;
    constexpr uint32_t height=225;
    const uint32_t width=std::max(1,int(std::lround(camera.logical_size.x/camera.logical_size.y*height)));
    const int64_t frame=int64_t(std::floor(r.state.world_time*24.0));
    if (field.field_frame==frame && field.field_width==width && field.field_height==height && !field.field_alpha.empty()) return true;
    const double cell=(camera.logical_size.y/height)/camera.camera_zoom;
    const godot::Vector2 origin=camera.camera_center-godot::Vector2(width*cell,height*cell)*0.5;
    const auto &fx=r.content->canis_nova_fx.front();const double dimension=std::max(fx.source_width,fx.source_height);
    std::vector<Polygon> shapes;
    for (const auto &m:body.canis.led) {
        if (!r.state.enemy_handles.contains(m.actor)) continue;
        const auto &e=r.state.enemies[m.actor.slot];if (e.dead) continue;
        const auto &definition=r.content->definitions[e.definition];
        const double size=e.radius*definition.sprite_scale*2.0/dimension,angle=e.facing+definition.sprite_angle,c=std::cos(angle),s=std::sin(angle);
        Polygon shape;shape.reserve(r.content->canis_nova_hull.size());
        for (const auto &p:r.content->canis_nova_hull) shape.push_back({e.pos.x+(p.x*c-p.y*s)*size,e.pos.y+(p.x*s+p.y*c)*size});
        shapes.push_back(std::move(shape));
    }
    std::vector<uint8_t> sum(size_t(width)*height,0);
    for (int light_index=0;light_index<9;++light_index) {
        const double radius=light_index==0?0:24.0*std::sqrt((light_index-0.5)/8.0),angle=(light_index-1)*2.399963;
        const Point light{source.x+std::cos(angle)*radius,source.y+std::sin(angle)*radius};
        std::vector<uint8_t> plane(sum.size(),0);
        for (const auto &shape:shapes) {
            Polygon projected;projected.reserve(shape.size()*2);
            for (auto p:shape) {
                projected.push_back({(p.x-origin.x)/cell,(p.y-origin.y)/cell});
                const double dx=p.x-light.x,dy=p.y-light.y,d=std::hypot(dx,dy);
                const double scale=d>0?range*1.5/d:0;
                projected.push_back({(light.x+dx*scale-origin.x)/cell,(light.y+dy*scale-origin.y)/cell});
            }
            raster(hull(std::move(projected)),width,height,plane);
        }
        accumulate_blurred(plane,width,height,sum);
    }
    field.field_alpha=std::move(sum);
    field.field_origin=origin;field.field_cell=cell;field.field_width=width;field.field_height=height;field.field_frame=frame;++field.field_revision;
    return true;
}

bool CanisNovaField::safe(const RunRuntime &r,const CanisNovaState &field,godot::Vector2 source,double range) {
    const auto ship=r.state.ship_pos;const double radius=r.state.ship_config.ship_radius;
    if (ship.distance_to(source)-radius>range) return true;
    if (field.field_alpha.empty() || field.field_cell<=0) return false;
    const double px=(ship.x-field.field_origin.x)/field.field_cell,py=(ship.y-field.field_origin.y)/field.field_cell,pr=radius/field.field_cell;
    for (int y=int(std::floor(py-pr));y<=int(std::ceil(py+pr));++y) for (int x=int(std::floor(px-pr));x<=int(std::ceil(px+pr));++x) {
        const double dx=px-std::clamp(px,double(x),double(x+1)),dy=py-std::clamp(py,double(y),double(y+1));
        if (dx*dx+dy*dy>pr*pr) continue;
        if (x<0 || y<0 || x>=int(field.field_width) || y>=int(field.field_height) || field.field_alpha[size_t(y)*field.field_width+x]<250) return false;
    }
    return true;
}
}
