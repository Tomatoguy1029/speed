#include "metrics_builder.h"
#include "frame_builder.h"
#include "../runtime/run_runtime.h"
#include <godot_cpp/variant/array.hpp>
#include <algorithm>
#include <climits>
namespace speed {
MetricsTimer::~MetricsTimer() {
    const int64_t us=std::max<int64_t>(0,std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-began).count());
    sample.total_us+=std::min(us,INT64_MAX-sample.total_us);
    if (sample.count<INT64_MAX) ++sample.count;
    sample.max_us=std::max(sample.max_us,us);
}
godot::Dictionary MetricsBuilder::read(const RunRuntime &run) {
    auto out=FrameBuilder::metrics(run);godot::Dictionary timings;
    const auto packed=[](const MetricSample &sample) {godot::Array values;values.push_back(sample.total_us);values.push_back(sample.count);values.push_back(sample.max_us);return values;};
    timings["sim"]=packed(run.frame_workspace.metrics.sim);timings["output_build"]=packed(run.frame_workspace.metrics.output_build);
    out["timings"]=timings;return out;
}
}
