include scripts/utils.mk

LIBNAME ?= lib$(PKGNAME)
SDKPATH ?= er-301
src_dir = src/$(PKGNAME)

c_sources    := $(call rwildcard, $(src_dir), *.c)
cpp_sources  := $(call rwildcard, $(src_dir), *.cpp)
swig_sources := $(call rwildcard, $(src_dir), *.cpp.swig)

assets      := $(call rwildcard, $(src_dir)/assets, *)
sources     := $(c_sources) $(cpp_sources) $(swig_sources)
headers     := $(call rwildcard, $(src_dir), *.h)

# Do you need any additional preprocess symbols?
symbols = 

# Determine ARCH if it's not provided...
# linux | darwin | am335x
ifndef ARCH
  SYSTEM_NAME := $(shell uname -s)
  ifeq ($(SYSTEM_NAME),Linux)
    ARCH = linux
  else ifeq ($(SYSTEM_NAME),Darwin)
    ARCH = darwin
  else
    $(error Unsupported system $(SYSTEM_NAME))
  endif
endif

# Use the linux source files unless we're building am335x
arch_source = linux
ifeq ($(ARCH),am335x)
  arch_source = am335x
endif

# Determine PROFILE if it's not provided...
# testing | release | debug
PROFILE ?= testing

out_dir = $(PROFILE)/$(ARCH)
lib_file = $(out_dir)/$(LIBNAME).so
package_file = $(out_dir)/$(PKGNAME)-$(PKGVERSION).pkg

swig_interface = $(filter %.cpp.swig,$(sources))
swig_wrapper = $(addprefix $(out_dir)/,$(swig_interface:%.cpp.swig=%_swig.cpp))
swig_object = $(swig_wrapper:%.cpp=%.o)

c_sources = $(filter %.c,$(sources))
cpp_sources = $(filter %.cpp,$(sources))

objects = $(addprefix $(out_dir)/,$(c_sources:%.c=%.o))
objects += $(addprefix $(out_dir)/,$(cpp_sources:%.cpp=%.o))
objects += $(swig_object)

includes  = $(src_dir)
includes += $(SDKPATH) $(SDKPATH)/arch/$(arch_source)

ifeq ($(ARCH),am335x)
  CFLAGS.am335x = -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard -mabi=aapcs -Dfar= -D__DYNAMIC_REENT__
  LFLAGS = -nostdlib -nodefaultlibs -r

  include $(SDKPATH)/scripts/am335x.mk
endif

ifeq ($(ARCH),linux)
  CFLAGS.linux = -Wno-deprecated-declarations -msse4 -fPIC
  LFLAGS = -shared

  include $(SDKPATH)/scripts/linux.mk
endif

ifeq ($(ARCH),darwin)
  INSTALLROOT.darwin = ~/.od/front
  CFLAGS.darwin = -Wno-deprecated-declarations -msse4 -fPIC
  LFLAGS = -dynamic -undefined dynamic_lookup -lSystem

  include $(SDKPATH)/scripts/darwin.mk
endif

CFLAGS.common = -Wall -ffunction-sections -fdata-sections
CFLAGS.speed = -O3 -ftree-vectorize -ffast-math
CFLAGS.size = -Os

CFLAGS.release = $(CFLAGS.speed) -Wno-unused
CFLAGS.testing = $(CFLAGS.speed) -DBUILDOPT_TESTING
CFLAGS.debug = -g -DBUILDOPT_TESTING

CFLAGS += $(CFLAGS.common) $(CFLAGS.$(ARCH)) $(CFLAGS.$(PROFILE))
CFLAGS += $(addprefix -I,$(includes)) 
CFLAGS += $(addprefix -D,$(symbols))

# swig-specific flags
SWIGFLAGS = -lua -no-old-metatable-bindings -nomoduleglobal -small -fvirtual
SWIGFLAGS += $(addprefix -I,$(includes)) 
CFLAGS.swig = $(CFLAGS.common) $(CFLAGS.$(ARCH)) $(CFLAGS.size)
CFLAGS.swig += $(addprefix -I,$(includes)) -I$(SDKPATH)/libs/lua54
CFLAGS.swig += $(addprefix -D,$(symbols))

#######################################################
# Rules

all: $(package_file)

$(swig_wrapper): $(headers) Makefile

$(objects): $(headers) Makefile

$(lib_file): $(objects)
	@echo [LINK $@]
	@$(CC) $(CFLAGS) -o $@ $(objects) $(LFLAGS)

$(package_file): $(lib_file) $(assets)
	@echo [ZIP $@]
	@rm -f $@
	@$(ZIP) -j $@ $(lib_file) $(assets)

list: $(package_file)
	@unzip -l $(package_file)

clean:
	rm -rf $(out_dir)

dist-clean:
	rm -rf testing release debug

install: $(package_file)
	cp $(package_file) $(INSTALLROOT.$(ARCH))/ER-301/packages/

install-sd:
	cp $(package_file) /Volumes/NO\ Name/ER-301/packages/

# C/C++ compilation rules

$(out_dir)/%.o: %.c
	@echo [C $<]
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) -std=gnu11 -c $< -o $@

$(out_dir)/%.o: %.cpp
	@echo [C++ $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

# SWIG wrapper rules

.PRECIOUS: $(out_dir)/%_swig.c $(out_dir)/%_swig.cpp

$(out_dir)/%_swig.cpp: %.cpp.swig
	@echo [SWIG $<]
	@mkdir -p $(@D)
	@$(SWIG) -fvirtual -fcompact -c++ $(SWIGFLAGS) -o $@ $<

$(out_dir)/%_swig.o: $(out_dir)/%_swig.cpp
	@echo [C++ $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS.swig) -std=gnu++11 -c $< -o $@
