// Copied from core

#pragma once

#include <od/objects/heads/Head.h>
#include <Grain.h>
#include <MonoGrain.h>
#include <StereoGrain.h>
#include <atomic>

namespace fdelay
{

  class GranularHead : public od::Head
  {
  public:
    GranularHead(int channelCount, int grainCount = 16);
    virtual ~GranularHead();

    virtual void setSample(od::Sample *sample);

#ifndef SWIGLUA
    virtual void process();
    od::Outlet mLeftOutput{"Left Out"};
    od::Outlet mRightOutput{"Right Out"};
    od::Inlet mTrigger{"Trigger"};
    od::Inlet mSpeed{"Speed"};
    od::Parameter mDuration{"Duration"};
    od::Parameter mStart{"Start"};
    od::Parameter mGain{"Gain"};
    od::Parameter mPan{"Pan"};
    od::Parameter mSquash{"Squash"};

    int getGrainCount();
    Grain *getGrain(int index);

#endif

  protected:
    float *mpStart = 0;
    float mSpeedAdjustment = 1.0f;
    int mOutputChannelCount;

    std::vector<StereoGrain> mStereoGrains;
    std::vector<StereoGrain *> mFreeStereoGrains;
    std::vector<StereoGrain *> mActiveStereoGrains;

    std::vector<MonoGrain> mMonoGrains;
    std::vector<MonoGrain *> mFreeMonoGrains;
    std::vector<MonoGrain *> mActiveMonoGrains;

    // gain compensation (indexed by number of free grains)
    std::vector<float> mGainCompensation;

    StereoGrain *getNextFreeStereoGrain();
    MonoGrain *getNextFreeMonoGrain();
    void setMaximumGrainCount(int n);
    void processAnyMono();
    void processStereoToStereo();
    void stopAllGrains();

  private:
    typedef Head Base;
    std::atomic<bool> mEnabled{false};
  };

} /* namespace fdelay */
