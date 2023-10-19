%module yloop_libyloop
%include <od/glue/mod.cpp.swig>

%{

#undef SWIGLUA

#include <Stopwatch.h>
#include <Once.h>

#define SWIGLUA

%}

%include <Stopwatch.h>
%include <Once.h>
