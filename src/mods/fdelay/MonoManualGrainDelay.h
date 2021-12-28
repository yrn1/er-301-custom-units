#pragma once

#include <od/objects/Object.h>
#include <od/audio/SampleFifo.h>
#include <MonoGrain.h>
#include <array>

namespace fdelay
{
  class MonoManualGrainDelay : public od::Object
  {
  public:
    MonoManualGrainDelay(float secs, int grainCount = 16);
    virtual ~MonoManualGrainDelay();

    float setMaxDelay(float secs);
    float getMaxDelay();

#ifndef SWIGLUA
    virtual void process();
    od::Inlet mInput{"In"};
    od::Inlet mTrigger{"Trigger"};
    od::Inlet mFreeze{"Freeze"};
    od::Inlet mSpeed{"Speed"};
    od::Parameter mDelay{"Delay"};
    od::Parameter mDuration{"Duration"};
    od::Parameter mSquash{"Squash"};
    od::Outlet mOutput{"Out"};

    int getGrainCount();
    Grain *getGrain(int index);
#endif

  private:
    od::SampleFifo mSampleFifo;

    std::vector<MonoGrain> mGrains;
    std::vector<MonoGrain *> mFreeGrains;
    std::vector<MonoGrain *> mActiveGrains;

    // gain compensation (indexed by number of free grains)
    std::vector<float> mGainCompensation;

    MonoGrain *getNextFreeGrain();
    void setMaximumGrainCount(int n);
    void stopAllGrains();

    float mMaxDelayInSeconds = 0.0f;
    int mMaxDelayInSamples = 0;

    std::atomic<bool> mEnabled{false};
  };
} /* namespace fdelay */
