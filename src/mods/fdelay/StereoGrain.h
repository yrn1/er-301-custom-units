// Copied from core

#pragma once

#include <Grain.h>

namespace fdelay
{

    class StereoGrain : public Grain
    {
    public:
        StereoGrain();
        virtual ~StereoGrain();

        void synthesize(float *left, float *right);

    protected:
        inline void incrementPhase();

        float mFifoL[3] = {0, 0, 0};
        float mFifoR[3] = {0, 0, 0};
    };

} /* namespace fdelay */
