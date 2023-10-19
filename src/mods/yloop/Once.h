#pragma once

#include <od/objects/Object.h>

namespace yloop
{
  class Once : public od::Object
  {
  public:
    Once();
    virtual ~Once();

#ifndef SWIGLUA
    virtual void process();
    od::Inlet mGate{"Gate"};
    od::Inlet mReset{"Reset on Low"};
    od::Parameter mTimeMax{"Max Time"};
    od::Parameter mTimeParameter{"Time"};
    od::Parameter mHighAfterOnceParameter{"High After Once"};
    od::Outlet mTimeOut{"Time"};
    od::Outlet mHighAfterOnceOut{"High After Once"};
#endif

  private:
    uint32_t mHighCount = 0;
    float mTime = 0.0f;
    uint8_t mOnce = 1;
    bool mResettable = true;
  };
} /* namespace yloop */
