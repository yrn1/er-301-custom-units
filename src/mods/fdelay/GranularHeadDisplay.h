// Copied from core

#pragma once

#include <od/graphics/sampling/HeadDisplay.h>
#include <GranularHead.h>

namespace fdelay
{

    class GranularHeadDisplay : public od::HeadDisplay
    {
    public:
        GranularHeadDisplay(GranularHead *head, int left, int bottom, int width, int height);
        virtual ~GranularHeadDisplay();

#ifndef SWIGLUA
        virtual void draw(od::FrameBuffer &fb);

        GranularHead *granularHead()
        {
            return (GranularHead *)mpHead;
        }
#endif
    };

} /* namespace fdelay */
