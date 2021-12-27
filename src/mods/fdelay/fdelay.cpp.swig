%module fdelay_libfdelay
%include <od/glue/mod.cpp.swig>

%{

#undef SWIGLUA

#include <Grain.h>
#include <MonoGrain.h>
#include <MonoManualGrainDelay.h>

#define SWIGLUA

%}

%include <Grain.h>
%include <MonoGrain.h>
%include <MonoManualGrainDelay.h>
