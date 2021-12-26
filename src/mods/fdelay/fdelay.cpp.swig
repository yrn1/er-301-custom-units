%module fdelay_libfdelay
%include <od/glue/mod.cpp.swig>

%{

#undef SWIGLUA

#include <Grain.h>
#include <MonoGrain.h>
#include <StereoGrain.h>
#include <MonoManualGrainDelay.h>
#include <GranularHead.h>
#include <GranularHeadDisplay.h>

#define SWIGLUA

%}

%include <Grain.h>
%include <MonoGrain.h>
%include <StereoGrain.h>
%include <MonoManualGrainDelay.h>
%include <GranularHead.h>
%include <GranularHeadDisplay.h>
