#include <Once.h>
#include <od/config.h>
#include <hal/ops.h>

namespace yloop
{
  Once::Once()
  {
    addInput(mGate);
    addInput(mReset);
    addParameter(mTimeMax);
    addParameter(mTimeParameter);
    addParameter(mHighAfterOnceParameter);
    addOutput(mTimeOut);
    addOutput(mHighAfterOnceOut);
  }

  Once::~Once()
  {
  }

  void Once::process()
  {
    float *gate = mGate.buffer();
    float *reset = mReset.buffer();
    float *time = mTimeOut.buffer();
    float *once = mHighAfterOnceOut.buffer();
    float max = mTimeMax.target();

    if (reset[globalConfig.frameLength - 1] > 0.2f) {
      mResettable = true;
    }
    if (mResettable && reset[globalConfig.frameLength - 1] < 0.1f) {
      mResettable = false;
      mOnce = 0;
    }
    if (mTime == 0.0f) {
      mTime = max;
    }
    
    for (int i = 0; i < globalConfig.frameLength; i++) {
      if (mOnce == 0) {
        if (gate[i] > 0.0f) {
          mTime = max;
          mHighCount++;
        } else if (mHighCount > 0) {
          mTime = MIN(mHighCount * globalConfig.samplePeriod, max);
          mHighCount = 0;
          mOnce = 1;
        }
      }

      time[i] = mTime;
      once[i] = mOnce;
    }
    mTimeParameter.hardSet(mTime);
    mHighAfterOnceParameter.hardSet(mOnce);

  }
} /* namespace yloop */