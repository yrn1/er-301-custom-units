#pragma once

#include <od/objects/Object.h>
#include <od/audio/SampleFifo.h>
#include <MonoGrain.h>
#include <array>

namespace fdelay
{
#define MONOPSD_GRAIN_COUNT 3

  class MonoManualGrainDelay : public od::Object
  {
  public:
    MonoManualGrainDelay(float secs);
    virtual ~MonoManualGrainDelay();

#ifndef SWIGLUA
    virtual void process();
    od::Inlet mInput{"In"};
    od::Inlet mDelay{"Delay"};
    od::Inlet mSpeed{"Speed"};
    od::Outlet mOutput{"Out"};
#endif

    void setMaxDelay(float secs);

  private:
    od::SampleFifo mSampleFifo;
    std::array<MonoGrain, MONOPSD_GRAIN_COUNT> mGrains;

    int mSamplesUntilNextOnset = 0;
    float mMaxDelayInSeconds = 0.0f;
    int mMaxDelayInSamples = 0;
    int mGrainDurationInSamples = 0;
    int mGrainPeriodInSamples = 0;

    MonoGrain *getFreeGrain();
  };
} /* namespace fdelay */
