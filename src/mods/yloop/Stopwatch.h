#pragma once

#include <od/objects/Object.h>

namespace yloop
{
  class Stopwatch : public od::Object
  {
  public:
    Stopwatch();
    virtual ~Stopwatch();

#ifndef SWIGLUA
    virtual void process();
    od::Inlet mInput{"In"};
    od::Parameter mMax{"Max"};
    od::Parameter mValue{"Out"};
    od::Outlet mOutput{"Out"};
#endif

  private:
    uint32_t mHighCount = 0;
    float mTime = 0;
  };
} /* namespace yloop */
