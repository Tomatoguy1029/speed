#pragma once
#include <godot_cpp/variant/dictionary.hpp>
#include <chrono>
#include <cstdint>
namespace speed {
class RunRuntime;
struct MetricSample {int64_t total_us=0,count=0,max_us=0;};
struct OutputMetrics {
    int64_t fixed_steps=0,commands=0,events_emitted=0,events_acked=0;
    MetricSample sim,output_build;
};
class MetricsTimer {
    MetricSample &sample;
    std::chrono::steady_clock::time_point began=std::chrono::steady_clock::now();
public:
    explicit MetricsTimer(MetricSample &value):sample(value) {}
    ~MetricsTimer();
};
class MetricsBuilder {public: static godot::Dictionary read(const RunRuntime &);};
}
