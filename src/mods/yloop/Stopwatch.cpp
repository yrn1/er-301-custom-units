#include <Stopwatch.h>
#include <od/config.h>
#include <hal/ops.h>

namespace yloop
{
  Stopwatch::Stopwatch()
  {
    addInput(mInput);
    addParameter(mMax);
    addParameter(mValue);
    addOutput(mOutput);
  }

  Stopwatch::~Stopwatch()
  {
  }

  void Stopwatch::process()
  {
    float *in = mInput.buffer();
    float *out = mOutput.buffer();
    float max = mMax.target();
    for (uint32_t i = 0; i < globalConfig.frameLength; i++) {
      if (in[i] > 0.0f) {
        mHighCount++;
        out[i] = MIN(mHighCount * globalConfig.samplePeriod, max) + 20 * globalConfig.frameLength * globalConfig.samplePeriod;
      } else {
        if (mHighCount > 0) {
          mTime = MIN(mHighCount * globalConfig.samplePeriod, max) + 20 * globalConfig.frameLength * globalConfig.samplePeriod;
          mHighCount = 0;
        }
        out[i] = mTime;
      }
    }
    mValue.hardSet(out[globalConfig.frameLength - 1]);
  }
} /* namespace yloop */