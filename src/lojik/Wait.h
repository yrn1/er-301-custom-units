#pragma once

#include <od/objects/Object.h>
#include <sense.h>
#include <OneTime.h>

#define WAIT_MODE_LOW  1
#define WAIT_MODE_HIGH 2

namespace lojik {
  class Wait : public od::Object {
    public:
      Wait();
      virtual ~Wait();

#ifndef SWIGLUA
      virtual void process();
      od::Inlet  mIn     { "In" };
      od::Inlet  mCount  { "Count" };
      od::Inlet  mInvert { "Invert" };
      od::Inlet  mArm    { "Arm" };
      od::Outlet mOut    { "Out" };

      od::Option mSense { "Sense", INPUT_SENSE_LOW };
#endif

    private:
      OneTime mTrigSwitch;
      bool mIsArmed = false;
      int mStep = 0;
  };
}