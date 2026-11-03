#pragma once
#include <godot_cpp/variant/dictionary.hpp>
#include <chrono>
#include <cstdint>
#include <map>
#include <string>
#include <string_view>
#include <set>
namespace speed {
class RunRuntime;
struct MetricSample {int64_t total_us=0,count=0,max_us=0;std::map<std::string,int64_t> window_max;};
struct OutputMetrics {
    int64_t fixed_steps=0,commands=0,events_emitted=0,events_acked=0;
    MetricSample sim,output_build;
    bool detail_active=false;
    std::set<std::string> readers;
    std::map<std::string,MetricSample> detail;
    std::map<std::string,MetricSample> render_rows;
};
// 表示用の内訳だけを測る。ゲーム状態・乱数・保持点には触れない。
class MetricsDetailTimer {
    MetricSample *sample=nullptr;
    std::chrono::steady_clock::time_point began;
public:
    MetricsDetailTimer(OutputMetrics &metrics,std::string_view name,std::string_view suffix={}) {
        if (metrics.detail_active) {
            sample=&metrics.detail[std::string(name)+std::string(suffix)];
            for (const auto &reader:metrics.readers) sample->window_max.try_emplace(reader,0);
            began=std::chrono::steady_clock::now();
        }
    }
    ~MetricsDetailTimer();
};
class MetricsTimer {
    MetricSample &sample;
    std::chrono::steady_clock::time_point began=std::chrono::steady_clock::now();
public:
    explicit MetricsTimer(MetricSample &value):sample(value) {}
    ~MetricsTimer();
};
class MetricsBuilder {public: static void flush_observations(RunRuntime &); static void diagnostic(RunRuntime &,godot::StringName,const godot::Dictionary &,uint32_t detail=1); static void set_recording(RunRuntime &,bool,uint32_t level=2); static godot::Dictionary read(const RunRuntime &,const std::string &reader={}); static godot::Dictionary recording(const RunRuntime &,bool);};
}
