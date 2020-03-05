#=======================================================================
# Makefile for Xcompact3D
#=======================================================================
# Choose pre-processing options
#   -DDOUBLE_PREC - use double-precision
#   -DSAVE_SINGLE - Save 3D data in single-precision
#   -DDEBG        - debuggin xcompact3d.f90
# generate a Git version string
GIT_VERSION := $(shell git describe --tag --long --always)

DEFS = -DDOUBLE_PREC -DVERSION=\"$(GIT_VERSION)\"

LCL = local# local,lad,sdu,archer
IVER = 17# 15,16,17,18
CMP = gcc# intel,gcc
FFT = generic# generic,fftw3

#######CMP settings###########
ifeq ($(CMP),intel)
FC = mpiifort
#FFLAGS = -fpp -O3 -xHost -heap-arrays -shared-intel -mcmodel=large -safe-cray-ptr -g -traceback
FFLAGS = -fpp -O3 -xSSE4.2 -axAVX,CORE-AVX-I,CORE-AVX2 -ipo -fp-model fast=2 -mcmodel=large -safe-cray-ptr
##debuggin test: -check all -check bounds -chintel eck uninit -gen-interfaces -warn interfaces
else ifeq ($(CMP),gcc)
FC = mpif90
#FFLAGS = -O3 -funroll-loops -floop-optimize -g -Warray-bounds -fcray-pointer -x f95-cpp-input
FFLAGS = -cpp  -funroll-loops -floop-optimize -g -Warray-bounds -fcray-pointer -fbacktrace -ffree-line-length-none
#-ffpe-trap=invalid,zero
else ifeq ($(CMP),nagfor)
FC = mpinagfor
FFLAGS = -fpp
else ifeq ($(CMP),cray)
FC = ftn
FFLAGS = -cpp -xHost -O3 -ipo -heaparrays -safe-cray-ptr -g -traceback
PLATFORM=intel
endif


MODDIR = ./mod
DECOMPDIR = ./decomp2d
SRCDIR = ./src
OBJDIR = ./obj
NEWDIRS = $(OBJDIR) $(MODDIR)

### List of files for the main code
DECOMPS = decomp_2d.f90 glassman.f90 fft_$(FFT).f90 io.f90
SRCDECOMP = $(addprefix $(DECOMPDIR)/, $(DECOMPS))
OBJDECOMP = $(SRCDECOMP:$(DECOMPDIR)/%.f90=$(OBJDIR)/%.o)

SRCS= module_param.f90 variables.f90 poisson.f90 derive.f90 schemes.f90 implicit.f90 parameters.f90 *.f90
SRCSRC = $(addprefix $(SRCDIR)/, $(SRCS))
OBJOBJ = $(SRCSRC:$(SRCDIR)/%.f90=$(OBJDIR)/%.o)

SRCS = module_param.f90 variables.f90 poisson.f90 derive.f90 schemes.f90 implicit.f90 forces.f90 BC-User.f90 BC-TGV.f90 BC-Channel-flow.f90 BC-TBL.f90 BC-Cylinder.f90 BC-Lock-exchange.f90 BC-Mixing-layer.f90 BC-dbg-schemes.f90 case.f90 les_models.f90 transeq.f90 navier.f90 time_integrators.f90 filters.f90 parameters.f90 tools.f90 statistics.f90 visu.f90 genepsi3d.f90 xcompact3d.f90
SRCSRC = $(addprefix $(SRCDIR)/, $(SRCS))

### List of files for the post-processing code
PSRC = decomp_2d.f90 module_param.f90 io.f90 variables.f90 schemes.f90 derive.f90 BC-$(FLOW_TYPE).f90 parameters.f90 tools.f90 visu.f90 post.f90

#######FFT settings##########
ifeq ($(FFT),fftw3)
  #FFTW3_PATH=/usr
  #FFTW3_PATH=/usr/lib64
  FFTW3_PATH=/usr/local/Cellar/fftw/3.3.7_1
  INC=-I$(FFTW3_PATH)/include
  LIBFFT=-L$(FFTW3_PATH) -lfftw3 -lfftw3f
else ifeq ($(FFT),fftw3_f03)
  FFTW3_PATH=/usr                                #ubuntu # apt install libfftw3-dev
  #FFTW3_PATH=/usr/lib64                         #fedora # dnf install fftw fftw-devel
  #FFTW3_PATH=/usr/local/Cellar/fftw/3.3.7_1     #macOS  # brew install fftw
  INC=-I$(FFTW3_PATH)/include
  LIBFFT=-L$(FFTW3_PATH)/lib -lfftw3 -lfftw3f
else ifeq ($(FFT),generic)
  INC=
  LIBFFT=
endif

#######OPTIONS settings###########
OPT = -I$(SRCDIR) -I$(DECOMPDIR) $(FFLAGS)
LINKOPT = $(FFLAGS)
#-----------------------------------------------------------------------
# Normally no need to change anything below

all: xcompact3d

xcompact3d : $(NEWDIRS) $(OBJDECOMP) $(OBJ)
	$(FC) -o $@ $(LINKOPT) $(OBJDECOMP) $(OBJ) $(LIBFFT)

$(NEWDIRS) :
	mkdir -p $(NEWDIRS)

$(OBJDECOMP) : $(OBJDIR)%.o : $(DECOMPDIR)%.f90
	$(FC) $(FFLAGS) $(OPT) $(DEFS) $(DEFS2) $(INC) -c $< -o $@ -J $(MODDIR)

$(OBJOBJ) : $(OBJDIR)%.o : $(SRCDIR)%.f90
	$(FC) $(FFLAGS) $(OPT) $(DEFS) $(DEFS2) $(INC) -c $< -o $@ -J $(MODDIR)

## This %.o : %.f90 doesn't appear to be called...
%.o : %.f90
	$(FC) $(FFLAGS) $(DEFS) $(DEFS2) $(INC) -c $<

#todo .phony:post
.PHONY: clean

clean:
	rm -f *.o *.mod xcompact3d post
	rm -f $(MODDIR)/*
	rm -f $(OBJDIR)/*

.PHONY: cleanall

cleanall: clean
	rm -f *~ \#*\# out/* data/* stats/* planes/* *.xdmf *.log *.out nodefile core sauve*
