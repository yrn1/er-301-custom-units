#include <MonoManualGrainDelay.h>
#include <od/config.h>
#include <hal/ops.h>
#include <algorithm>
#include <math.h>
#include <string.h>

namespace fdelay
{
  MonoManualGrainDelay::MonoManualGrainDelay(float secs, int grainCount)
  {
    addInput(mInput);
    addInput(mTrigger);
    addInput(mFreeze);
    addInput(mSpeed);
    addParameter(mDelay);
    addParameter(mDuration);
    addParameter(mSquash);
    addOutput(mOutput);

    setMaximumGrainCount(grainCount);
    setMaxDelay(secs);
  }

  MonoManualGrainDelay::~MonoManualGrainDelay()
  {
  }

  int MonoManualGrainDelay::getGrainCount()
  {
    return mGainCompensation.size();
  }

  Grain *MonoManualGrainDelay::getGrain(int index)
  {
    if (index < 0 || index >= (int)mGainCompensation.size())
    {
      return NULL;
    }

    return static_cast<Grain *>(&mGrains[index]);
  }

  void MonoManualGrainDelay::stopAllGrains()
  {
    mFreeGrains.clear();
    for (MonoGrain &grain : mGrains)
    {
      if (grain.mActive)
      {
        grain.stop();
      }
      mFreeGrains.push_back(&grain);
    }
  }

  float MonoManualGrainDelay::getMaxDelay()
  {
    return mMaxDelayInSeconds;
  }

  float MonoManualGrainDelay::setMaxDelay(float secs)
  {
    mEnabled = false;
    stopAllGrains();

    if (secs < 0.0f)
    {
      secs = 0.0f;
    }
    mMaxDelayInSeconds = secs;
    mMaxDelayInSamples = (int)(secs * globalConfig.sampleRate);
    mSampleFifo.setSampleRate(globalConfig.sampleRate);
    mSampleFifo.allocateBuffer(1, mMaxDelayInSamples + 2 * globalConfig.frameLength);
    mSampleFifo.zeroAndFill();

    for (MonoGrain &grain : mGrains)
    {
      grain.setSample(mSampleFifo.getSample());
    }

    mEnabled = true;
    return mMaxDelayInSeconds;
  }

  void MonoManualGrainDelay::setMaximumGrainCount(int n)
  {
    mFreeGrains.clear();
    mFreeGrains.reserve(n);
    mGrains.resize(n);
    // push grains in a reverse memory order for better cache perf
    for (auto i = mGrains.rbegin(); i != mGrains.rend(); i++)
    {
      MonoGrain &grain = *i;
      mFreeGrains.push_back(&grain);
    }

    mGainCompensation.resize(n);
    for (int i = 0; i < n; i++)
    {
      mGainCompensation[i] = 1.0f / sqrtf(n - i);
    }
  }

  MonoGrain *MonoManualGrainDelay::getNextFreeGrain()
  {
    if (mEnabled && mFreeGrains.size() > 0)
    {
      MonoGrain *grain = mFreeGrains.back();
      mFreeGrains.pop_back();
      return grain;
    }
    else
    {
      return 0;
    }
  }

  void MonoManualGrainDelay::process()
  {
    if (!mEnabled)
    {
      return;
    }
    float *in = mInput.buffer();
    float *out = mOutput.buffer();
    float *trig = mTrigger.buffer();
    float *speed = mSpeed.buffer();
    float *freeze = mFreeze.buffer();

    if (freeze[0] <= 0.0f)
    {
      if (mFrozen)
      {
        mFrozen = false;
        for (int i = 0; i < FRAMELENGTH; i++)
        {
          in[i] = in[i] * (float)i / (float)FRAMELENGTH;
        }
      }
      mSampleFifo.pop(FRAMELENGTH);
      mSampleFifo.pushMono(in, FRAMELENGTH);
    }
    else if (!mFrozen)
    {
      mFrozen = true;
      for (int i = 0; i < FRAMELENGTH; i++)
      {
        in[i] = in[i] * (1.0 - (float)i / (float)FRAMELENGTH);
      }
      mSampleFifo.pop(FRAMELENGTH);
      mSampleFifo.pushMono(in, FRAMELENGTH);
    }

    // zero the output buffer
    memset(out, 0, sizeof(float) * FRAMELENGTH);

    for (int i = 0; i < FRAMELENGTH; i++)
    {
      if (trig[i] > 0.0f)
      {
        MonoGrain *grain = getNextFreeGrain();
        if (grain)
        {
          float duration = mDuration.value();
          if (duration >= mMaxDelayInSeconds)
          {
            duration = mMaxDelayInSeconds - 0.01f;
          }
          float delay = mDelay.value() / mMaxDelayInSeconds * (mMaxDelayInSeconds - duration);

          int durationSamples = duration * globalConfig.sampleRate;
          int neededSamples = (durationSamples + 1) * speed[i];
          int delaySamples = delay * globalConfig.sampleRate;

          int start = mMaxDelayInSamples - delaySamples;
          if (start < 0)
          {
            start = 0;
          }
          if (start > mMaxDelayInSamples)
          {
            start = mMaxDelayInSamples;
          }

          start += mSampleFifo.offsetToRecent(mMaxDelayInSamples + globalConfig.frameLength);

          float gain = mGainCompensation[mFreeGrains.size()];

          grain->init(start, durationSamples, speed[i], gain, 0.0f);
          grain->setSquash(mSquash.value());
        }
        // Only try to produce one grain per frame
        break;
      }
    }

    mActiveGrains.clear();
    for (MonoGrain &grain : mGrains)
    {
      if (grain.mActive)
      {
        mActiveGrains.push_back(&grain);
      }
    }

    // sort by sample position for cache coherence
    std::sort(mActiveGrains.begin(), mActiveGrains.end());

    for (MonoGrain *grain : mActiveGrains)
    {
      grain->synthesizeFromMonoToMono(out);
      if (!grain->mActive)
      {
        mFreeGrains.push_back(grain);
      }
    }
  }
} /* namespace fdelay */
