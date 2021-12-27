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

  float MonoManualGrainDelay::getMaxDelay()
  {
    return mMaxDelayInSeconds;
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

  void MonoManualGrainDelay::setMaxDelay(float secs)
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
    float *in = mInput.buffer();
    float *out = mOutput.buffer();

    mSampleFifo.pop(FRAMELENGTH);
    mSampleFifo.pushMono(in, FRAMELENGTH);

    // zero the output buffer
    memset(out, 0, sizeof(float) * FRAMELENGTH);

    float *trig = mTrigger.buffer();
    float *speed = mSpeed.buffer();

    for (int i = 0; i < FRAMELENGTH; i++)
    {
      if (trig[i] > 0.0f)
      {
        MonoGrain *grain = getNextFreeGrain();
        if (grain)
        {
          float delay = mDelay.value();
          int duration = mDuration.value() * globalConfig.sampleRate;
          int needed = duration * speed[i] + 1;

          int targetDelay = delay * globalConfig.sampleRate;
          if (targetDelay < needed) {
            targetDelay = needed;
          }
          int start;
          if (targetDelay < mMaxDelayInSamples)
          {
            start = mMaxDelayInSamples - targetDelay;
          }
          else
          {
            targetDelay = mMaxDelayInSamples;
            start = 0;
            duration = mMaxDelayInSamples / speed[i];
          }

          // translate to fifo offset
          start += mSampleFifo.offsetToRecent(mMaxDelayInSamples + globalConfig.frameLength);

          float gain = mGainCompensation[mFreeGrains.size()];

          grain->init(start, duration, speed[i], gain, 0.0f);
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
