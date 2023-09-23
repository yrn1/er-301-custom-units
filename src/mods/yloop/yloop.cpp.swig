%module yloop_libyloop
%include <od/glue/mod.cpp.swig>

%{

#undef SWIGLUA

#include <Stopwatch.h>

#define SWIGLUA

%}

%include <Stopwatch.h>
