# For use with GNU make.
# no builtin implicit rules
MAKEFLAGS = --no-builtin-rules --warn-undefined-variables
#-----------------------------------------------------------------------------

ifndef TASK
  TASK =#
endif

ifndef SYSNAME
  SYSNAME := $(shell uname)
  ifeq ($(SYSNAME),)
    $(error error with shell command uname)
  endif
  ifeq ($(SYSNAME),MINGW32_NT-5.1)
    SYSNAME=win32
  endif
endif

ifndef NODENAME
  NODENAME := $(shell uname -n)
  ifeq ($(NODENAME),)
    $(error error with shell command uname -n)
  endif
endif

ifndef MACHNAME
  MACHNAME := $(shell uname -m)
  ifeq ($(MACHNAME),)
    $(error error with shell command uname -m)
  endif
endif

ifndef DEBUG
  ifndef OPT
    OPT := false
  endif
  ifeq ($(OPT),false)
    DEBUG := true
  else
    DEBUG := false
  endif
endif

# set architecture dependent directories and default options

# defaults
INSTRUCTION=$(MACHNAME)
BIN_ARCH_DIR = $(INSTRUCTION)-$(OPERATING_SYSTEM)
LIB_ARCH_DIR = $(INSTRUCTION)-$(ABI)-$(OPERATING_SYSTEM)

ifeq ($(filter-out IRIX%,$(SYSNAME)),)# SGI
  # Specify what application binary interface (ABI) to use i.e. 32, n32 or 64
  ifndef ABI
    ifdef SGI_ABI
      ABI := $(patsubst -%,%,$(SGI_ABI))
    else
      ABI = n32
    endif
  endif
  # Specify which instruction set to use i.e. -mips#
  ifndef MIPS
    # Using mips3 for most basic version on esu* machines
    # as there are still some Indys around.
    # Although mp versions are unlikely to need mips3 they are made this way
    # because it makes finding library locations easier.
    MIPS = 4
    ifeq ($(filter-out esu%,$(NODENAME)),)
      ifeq ($(ABI),n32)
        ifneq ($(DEBUG),false)
          MIPS=3
        endif
      endif
    endif
  endif
  INSTRUCTION := mips
  OPERATING_SYSTEM := irix
endif
ifeq ($(SYSNAME),Linux)
  OPERATING_SYSTEM := linux
  LIB_ARCH_DIR = $(INSTRUCTION)-$(OPERATING_SYSTEM)# no ABI
  ifeq ($(filter-out i%86,$(MACHNAME)),)
    INSTRUCTION := i686
  endif
  ifndef ABI
    ifeq ($(filter-out i%86,$(MACHNAME)),)
      ABI=32
    endif
    ifneq (,$(filter $(MACHNAME),ia64 x86_64))# ia64 or x86_64
      ABI=64
    endif
  endif
endif
ifeq ($(SYSNAME),win32)
  ABI=32
  INSTRUCTION := i386
  OPERATING_SYSTEM := win32
  LIB_ARCH_DIR = $(INSTRUCTION)-$(OPERATING_SYSTEM)# no ABI
endif
ifeq ($(SYSNAME),SunOS)
  OPERATING_SYSTEM := solaris
endif
ifeq ($(SYSNAME),AIX)
  ifndef ABI
    ifdef OBJECT_MODE
      ifneq ($(OBJECT_MODE),32_64)
        ABI = $(OBJECT_MODE)
      endif
    else
      ABI = 32
    endif
  endif
  INSTRUCTION := rs6000
  OPERATING_SYSTEM := aix
endif
ifeq ($(SYSNAME),Darwin)
  OPERATING_SYSTEM := darwin
  LIB_ARCH_DIR = ppc-32-$(OPERATING_SYSTEM)
  ABI = 32
endif

ifneq ($(DEBUG),false)
  DEBUG_SUFFIX = -debug
else
  DEBUG_SUFFIX =
endif

#This is now the default build version, each libperlinterpreter.so
#that is found in the lib directories is converted into a base64
#c string (.soh) and included into the interpreter and the one that
#matches the machine that it is running on loaded dynamically at runtime.

#If you want this perl_interpreter to be as portable as possible then
#you will want to provide as many different perl versions to compile
#against as you can.

#If you want to build an old non dynamic loader version you will 
#need to override this to false and you must have the corresponding
#static libperl.a
ifndef USE_DYNAMIC_LOADER
  ifeq ($(SYSNAME),AIX)
    #AIX distributions have a static perl and even if I build
    #a shared "libperl.a" I cannot seem to dlopen it.
    USE_DYNAMIC_LOADER = false
  else
    ifeq ($(OPERATING_SYSTEM),win32)
      #I have not tried to make a dynamic perl interpreter in win32,
      #I have not even been including a dynaloader at all so far.
      USE_DYNAMIC_LOADER = false
    else
      USE_DYNAMIC_LOADER = maybe# if shared libraries are found
    endif
  endif
endif

#This routine is recursivly called for each possible dynamic version
#with SHARED_OBJECT set to true.  That builds the corresponding 
#libperlinterpereter.so
ifndef SHARED_OBJECT
  SHARED_OBJECT = false
endif

# ABI string for environment variables
# (for location of perl librarys in execuatable)
ABI_ENV = $(ABI)
ifeq ($(ABI),n32)
  ABI_ENV = N32
endif

# Location of perl.
# Try to determine from environment.
# gmake doesn't do what I want with this:
# ifdef CMISS$(ABI_ENV)_PERL
ifneq ($(origin CMISS$(ABI_ENV)_PERL),undefined)
  PERL := $(CMISS$(ABI_ENV)_PERL)
else
  ifdef CMISS_PERL
    PERL := $(CMISS_PERL)
  else
    # defaults first
    PERL = perl# first perl in path
    ifeq ($(ABI),64)
      # Need a perl of the same ABI
      ifeq (,$(filter $(MACHNAME),ia64 x86_64))# not ia64 or x86_64
        PERL = perl64
      endif
    endif
    # Specify the perl on some platforms so that everyone builds with the same.
    ifeq ($(filter-out IRIX%,$(SYSNAME)),)# SGI
      ifeq ($(filter-out esu%,$(NODENAME)),)
        ifeq ($(ABI),n32)
          PERL = ${CMISS_ROOT}/bin/mips-irix/perl
        else
          PERL = ${CMISS_ROOT}/bin/mips-irix/perl64
        endif
      endif
      ifeq ($(NODENAME),hpc2)
        ifeq ($(ABI),n32)
          PERL = ${CMISS_ROOT}/bin/perl
        else
          PERL = ${CMISS_ROOT}/bin/perl64
        endif
      endif
      # What to oxford NODENAMEs look like?
      CMISS_LOCALE ?=
      ifeq (${CMISS_LOCALE},OXFORD)
        ifeq ($(ABI),n32)
          PERL = /usr/paterson/local/bin/perl
        else
          PERL = /usr/paterson/local64/bin/perl
        endif
      endif
    endif
    ifeq ($(SYSNAME),SunOS)
        ifeq ($(ABI),32)
          PERL = ${CMISS_ROOT}/bin/perl
        else
          PERL = ${CMISS_ROOT}/bin/$(ABI)/perl
        endif
    endif
    ifeq ($(SYSNAME),AIX)
        ifeq ($(ABI),32)
          PERL = ${CMISS_ROOT}/bin/perl
        else
          PERL = ${CMISS_ROOT}/bin/perl64
        endif
    endif
    ifeq ($(filter-out esp56%,$(NODENAME)),)
      PERL = ${CMISS_ROOT}/bin/i686-linux/perl
    endif
    ifeq ($(SYSNAME),win32)
      PERL = c:/perl/5.6.1/bin/MSWin32-x86/perl.exe
# eg for a MinGW system
#      PERL = /usr/lib/perl5/5.9.1/bin/MSWin32-x86-multi-thread/perl.exe
    endif
  endif
endif

#Make architecture directory names and lib name
PERL_ARCHNAME := $(shell $(PERL) -MConfig -e 'print "$$Config{archname}\n"')
ifeq ($(PERL_ARCHNAME),)
  $(error problem with $(PERL))
endif
ifeq ($(SYSNAME),win32)
  PERL_ARCHLIB := $(subst \,/,$(shell $(PERL) -MConfig -e 'print "$$Config{archlibexp}\n"'))
else
  PERL_ARCHLIB := $(subst \,/,$(shell $(PERL) -MConfig -e 'print "$$Config{archlibexp}\n"'))
endif
ifeq ($(PERL_ARCHLIB),)
  $(error problem with $(PERL))
endif
PERL_VERSION := $(shell $(PERL) -MConfig -e 'print "$$Config{version}\n"')
ifeq ($(PERL_VERSION),)
  $(error problem with $(PERL))
endif
PERL_CFLAGS := $(shell $(PERL) -MConfig -e 'print "$$Config{ccflags}\n"')
ifeq ($(PERL_CFLAGS),)
  $(error problem with $(CFLAGS))
endif
DYNALOADER_LIB = $(PERL_ARCHLIB)/auto/DynaLoader/DynaLoader.a
#Mangle the callback name so that we don't pick up the wrong version even when it is accidently visible
ifeq ($(SHARED_OBJECT), true)
   CMISS_PERL_CALLBACK_SUFFIX_A := $(PERL_VERSION)/$(PERL_ARCHNAME)
   CMISS_PERL_CALLBACK_SUFFIX_B := $(subst .,_,$(CMISS_PERL_CALLBACK_SUFFIX_A))
   CMISS_PERL_CALLBACK_SUFFIX_C := $(subst /,_,$(CMISS_PERL_CALLBACK_SUFFIX_B))
   CMISS_PERL_CALLBACK_SUFFIX := $(subst -,_,$(CMISS_PERL_CALLBACK_SUFFIX_C))
else
   CMISS_PERL_CALLBACK_SUFFIX := static
endif
CMISS_PERL_CALLBACK=cmiss_perl_callback_$(CMISS_PERL_CALLBACK_SUFFIX)
PERL_WORKING_DIR = Perl_cmiss/generated/$(PERL_VERSION)/$(PERL_ARCHNAME)-$(CMISS_PERL_CALLBACK_SUFFIX)
PERL_CMISS_MAKEFILE = $(PERL_WORKING_DIR)/Makefile
PERL_CMISS_LIB = $(PERL_WORKING_DIR)/auto/Perl_cmiss/Perl_cmiss.a
ifeq ($(TASK),)
  ifneq ($(USE_DYNAMIC_LOADER),false) #true or maybe
    SHARED_PERL_EXECUTABLES =
    ifneq ($(wildcard ${CMISS_ROOT}/perl),)
      ifeq ($(SYSNAME),Linux)
        ifeq ($(filter-out i%86,$(MACHNAME)),)
          SHARED_PERL_EXECUTABLES += $(wildcard ${CMISS_ROOT}/perl/bin-5.?.?-i386-linux*/perl)
          SHARED_PERL_EXECUTABLES += $(wildcard ${CMISS_ROOT}/perl/bin-5.?.?-i686-linux*/perl)
        else
	  SHARED_PERL_EXECUTABLES += $(wildcard ${CMISS_ROOT}/perl/bin-5.?.?-$(MACHNAME)-linux*/perl)
        endif
      endif
      ifeq ($(SYSNAME),AIX)
         SHARED_PERL_EXECUTABLES += $(wildcard ${CMISS_ROOT}/perl/bin-5.?.?-rs6000-${ABI}*/perl)
      endif
      ifeq ($(filter-out IRIX%,$(SYSNAME)),)# SGI
         SHARED_PERL_EXECUTABLES += $(wildcard ${CMISS_ROOT}/perl/bin-5.?.?-irix-${ABI}*/perl)
      endif
    endif
    ifeq ($(filter-out ${PERL},${SHARED_PERL_EXECUTABLES}),)
      ifneq ($(wildcard $(PERL_ARCHLIB)/CORE/libperl.so),)
        SHARED_PERL_EXECUTABLES += ${PERL}
      endif
    endif
    ifeq ($(USE_DYNAMIC_LOADER),maybe)
      ifeq ($(SHARED_PERL_EXECUTABLES),)
        USE_DYNAMIC_LOADER = false
      else
        USE_DYNAMIC_LOADER = true
      endif
    endif
  endif
endif
ifneq ($(SHARED_OBJECT), true)
   STATIC_PERL_LIB = $(firstword $(wildcard $(PERL_ARCHLIB)/CORE/libperl.a) $(wildcard $(PERL_ARCHLIB)/CORE/libperl56.a))
   ifneq ($(USE_DYNAMIC_LOADER), true)
      ifeq ($(STATIC_PERL_LIB),)
         $(error 'Static $(PERL_ARCHLIB)/CORE/libperl.a not found for ${PERL} which is required for a non dynamic loading perl interpreter.')
      endif
   endif
else
   STATIC_PERL_LIB = 
endif
PERL_EXP = $(wildcard $(PERL_ARCHLIB)/CORE/perl.exp)

SOURCE_DIR = source
ifneq ($(USE_DYNAMIC_LOADER), true)
   ifneq ($(SHARED_OBJECT), true)
      SHARED_SUFFIX = 
   else
      SHARED_SUFFIX = -shared
   endif
   SHARED_LIB_SUFFIX =
else
   SHARED_SUFFIX = -dynamic
   SHARED_LIB_SUFFIX = -dynamic
endif

WORKING_DIR := generated/$(PERL_VERSION)/$(PERL_ARCHNAME)$(DEBUG_SUFFIX)$(SHARED_SUFFIX)
C_INCLUDE_DIRS = $(PERL_ARCHLIB)/CORE $(WORKING_DIR)

LIBRARY_ROOT_DIR := lib/$(LIB_ARCH_DIR)
LIBRARY_VERSION := $(PERL_VERSION)/$(PERL_ARCHNAME)$(SHARED_LIB_SUFFIX)
LIBRARY_DIR := $(LIBRARY_ROOT_DIR)/$(LIBRARY_VERSION)
ifneq ($(SHARED_OBJECT), true)
   LIBRARY_SUFFIX = .a
else
   LIBRARY_SUFFIX = .so
endif
LIBRARY_NAME := libperlinterpreter$(DEBUG_SUFFIX)$(LIBRARY_SUFFIX)
LIBRARY := $(LIBRARY_DIR)/$(LIBRARY_NAME)
LIBRARY_LINK := $(LIBRARY_ROOT_DIR)/libperlinterpreter$(DEBUG_SUFFIX)$(LIBRARY_SUFFIX)
LIB_EXP := $(patsubst %$(LIBRARY_SUFFIX), %.exp, $(LIBRARY_LINK))

SOURCE_FILES := $(notdir $(wildcard $(SOURCE_DIR)/*.*) )
PMH_FILES := $(patsubst %.pm, %.pmh, $(filter %.pm, $(SOURCE_FILES)))
C_SOURCES := perl_interpreter.c
ifeq ($(USE_DYNAMIC_LOADER), true)
   C_SOURCES += perl_interpreter_dynamic.c
endif
C_UNITS := $(basename $(C_SOURCES) )
DEPEND_FILES := $(foreach unit, $(C_UNITS), $(WORKING_DIR)/$(unit).d )

C_OBJ := $(WORKING_DIR)/libperlinterpreter.o


#-----------------------------------------------------------------------------
# compiling commands

CC = cc
LD_RELOCATABLE = ld -r $(CFL_FLGS) $(L_FLGS)
LD_SHARED = ld -shared $(CFL_FLGS) $(L_FLGS)
SHARED_LINK_LIBRARIES = 
AR = ar
# Option lists
# (suboption lists become more specific so that later ones overrule previous)
CFLAGS = $(strip $(CFL_FLGS) $(CFE_FLGS) $(CF_FLGS)) '-DCMISS_PERL_CALLBACK=$(CMISS_PERL_CALLBACK)'
CPPFLAGS := $(addprefix -I, $(C_INCLUDE_DIRS) ) '-DABI_ENV="$(ABI_ENV)"'
ARFLAGS = -cr
ifneq ($(DEBUG),false)
  CFLAGS += $(strip $(DBGCF_FLGS) $(DBGC_FLGS))
else
  CFLAGS += $(strip $(OPTCFE_FLGS) $(OPTCF_FLGS) $(OPTC_FLGS))
endif
# suboption lists
CFL_FLGS =#	flags for C fortran and linking
L_FLGS =#	flags for linking only
CFE_FLGS =#	flags for C fortran and linking executables only
CF_FLGS = -c#	flags for C and fortran only
DBGCF_FLGS = -g#OPT=false flags for C and fortran
DBGC_FLGS =#	OPT=false flags for C only
OPTCFE_FLGS =#	OPT=true flags for C and fortran and linking executables
OPTCF_FLGS = -O#OPT=true flags for C and fortran only
OPTC_FLGS =#	OPT=true flags for C only

ifeq ($(filter-out IRIX%,$(SYSNAME)),)# SGI
  # The following warning means that the execution of the program is seriously
  # different from that intended:
  # cc-1999 cc: WARNING File = zle_tricky.c, Line = 2145
  # "jumping out of a block containing VLAs" is not currently implemented
  CFLAGS += -DEBUG:error=1999
  CF_FLGS += -use_readonly_const -fullwarn
  DBGCF_FLGS += -DEBUG:trap_uninitialized:subscript_check:verbose_runtime
  # warning 158 : Expecting MIPS3 objects: ... MIPS4.
  L_FLGS += -rdata_shared -DEBUG:error=158
  CFL_FLGS = -$(ABI) -mips$(MIPS)
  OPTCF_FLGS = -O3 -OPT:Olimit=8000
  ifeq ($(ABI),n32)
    LD_SHARED += -check_registry /usr/lib32/so_locations
  else
    LD_SHARED += -check_registry /usr/lib64/so_locations
  endif
endif
ifeq ($(SYSNAME),Linux)
  ifeq ($(MACHNAME),ia64)
    # Intel compilers
    CC = ecc
    CFLAGS += -w2# -Wall
# This doesn't seem to do anything
#     ifeq ($(ABI),64)
#       CF_FLGS += -size_lp64
#     endif
  else
    # gcc
    CPPFLAGS += -Dbool=char -DHAS_BOOL
#    CFE_FLGS += -m$(ABI)
    # Position independent code is only required for shared objects.
    ifeq ($(SHARED_OBJECT),true)
      CFE_FLGS += -fPIC
      # gcc 3.3.3 documentation recommends using the same code generation
      # flags when linking shared libraries as when compiling.
      # Linker option -Bsymbolic binds references to global symbols to those
      # within the shared library, if any.  This avoids picking up the symbols
      # like boot_Perl_cmiss from the static interpreter.
      LD_SHARED = $(CC) -shared -Wl,-Bsymbolic $(CFE_FLGS)
    endif
  endif
#   DBGCF_FLGS = -g3
  OPTCF_FLGS = -O2
  # Don't include a dependency on libperl.so in the shared link libraries as
  # the perl_interpreter does not say where to find libperl.so when loading the
  # shared link libraries.
  SHARED_LINK_LIBRARIES += -lcrypt -ldl
endif
ifeq ($(SYSNAME),win32)
  CC = gcc -fnative-struct
endif
ifeq ($(SYSNAME),SunOS)
  # need -xarch=native after -fast
  OPTCFE_FLGS += -fast $(CFE_FLGS)
  ifeq ($(ABI),64)
    CFE_FLGS += -xarch=native64
  endif
endif
ifeq ($(SYSNAME),AIX)
  CC = xlc
  # no -qinfo=gen because perl redefines many symbols
  CFLAGS += -qinfo=ini:por:pro:trd:tru:use
  ARFLAGS += -X$(ABI)
  # may want -qsrcmsg
  CF_FLGS += -qfullpath
  CFE_FLGS += -q$(ABI) -qarch=auto -qhalt=e
  L_FLGS += -b$(ABI)
  ifeq ($(ABI),64)
    # 1506-743 (I) 64-bit portability: possible change of result through conversion ...
    # These don't seem to serious.  Truncations are reported separately.
    # FD_SET in sys/time.h does this
    CF_FLGS += -qwarn64 -qsuppress=1506-743
  endif
  # lapack's dlamch performs an underflow so we don't check that.
  DBGCF_FLGS += -qfullpath -C -qflttrap=inv:en
  # -qinitauto for C is bytewise: 7F gives large integers.
  DBGC_FLGS += -qinitauto=7F
  OPTCF_FLGS = -O3 -qmaxmem=12000 -qtune=auto
  OPTC_FLGS += -qnoignerrno
endif
ifeq ($(SHARED_OBJECT), true)
  CPPFLAGS += -DSHARED_OBJECT
endif
ifeq ($(USE_DYNAMIC_LOADER), true)
  CPPFLAGS += -DUSE_DYNAMIC_LOADER
endif
SHARED_LINK_LIBRARIES += -lc
CFLAGS += $(PERL_CFLAGS)
.PHONY : main

vpath $(PERL) $(subst :, ,$(PATH))

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

ifeq ($(TASK),)
#-----------------------------------------------------------------------------

ifeq ($(OPERATING_SYSTEM),win32)
  $(warning *******************************)
  $(warning This still does not compile win32 out of the box)
  $(warning The generated Perl_cmiss Makefile ends up with many \ where there need to be / which seems to work with dmake but the command called from this makefile fails with a -c error but works fine when executed in a shell)
  $(warning The library built does not have the perl or Perl_cmiss in it, these only seem to work when linked in the final link)
  $(warning *******************************)
  $(warning)
endif

  .NOTPARALLEL:

  TMP_FILES := $(notdir $(wildcard $(WORKING_DIR)/*.* ) )
  OLD_FILES := $(filter-out $(PMH_FILES) $(foreach unit,$(C_UNITS),$(unit).%), \
    $(TMP_FILES))

  .PHONY : tidy clean allclean \
	all debug opt debug64 opt64

  define VERSION_MESSAGE
    @echo '     Version $(shell ${perl_executable} -MConfig -e 'print "$$Config{version} $$Config{archname}"') ${perl_executable}'

  endef
  ifeq ($(USE_DYNAMIC_LOADER),true)
   #Dynamic loading perl interpreter
   #Note that the blank line in the define is useful.
   define SHARED_BUILD_RULE
      $(MAKE) --no-print-directory USE_DYNAMIC_LOADER=false SHARED_OBJECT=true CMISS$(subst n,N,${ABI})_PERL=$(perl_executable)

   endef
   SHARED_INTERPRETER_BUILDS = $(foreach perl_executable, $(SHARED_PERL_EXECUTABLES), $(SHARED_BUILD_RULE))
   SHARED_VERSION_STRINGS = $(foreach perl_executable, $(SHARED_PERL_EXECUTABLES), $(shell ${perl_executable} -MConfig -e 'print "$$Config{version}/$$Config{archname}"'))
   SHARED_LIBRARIES = $(foreach version_string, $(SHARED_VERSION_STRINGS), $(LIBRARY_ROOT_DIR)/$(version_string)/libperlinterpreter$(DEBUG_SUFFIX).so)
   ifneq ($(STATIC_PERL_LIB),)
      define SUB_WRITE_BUILD_MESSAGE
         @echo 'The static fallback perl built into the interpreter is:'
         $(foreach perl_executable, $(PERL), $(VERSION_MESSAGE))
      endef
   else
      define SUB_WRITE_BUILD_MESSAGE
         @echo
         @echo '  YOU HAVE NOT INCLUDED A STATIC FALLBACK PERL SO ANY'
         @echo '  EXECUTABLE BUILT WITH THIS PERL INTERPRETER WILL NOT'
         @echo '  RUN AT ALL UNLESS ONE OF THE ABOVE VERSIONS OF PERL'
         @echo '  IS FIRST IN YOUR PATH.'
      endef
   endif
   define WRITE_BUILD_MESSAGE
	   @echo
	   @echo '======================================================'
	   @echo 'Congratulations, you have built a dynamic perl interpreter.'
	   @echo '     $(LIBRARY_LINK)'
      @echo 'It will work dynamically with the following versions of perl:'
      $(foreach perl_executable, $(SHARED_PERL_EXECUTABLES), $(VERSION_MESSAGE))
      ${SUB_WRITE_BUILD_MESSAGE}
   endef
  else
   SHARED_INTERPRETER_BUILDS =
   SHARED_LIBRARIES =
   ifeq ($(SHARED_OBJECT),true)
      #This is an intermediate step and so doesn't write a message
      WRITE_BUILD_MESSAGE =
   else
      #Old style static perl interpreter
      define WRITE_BUILD_MESSAGE
	      @echo
	      @echo '======================================================'
	      @echo 'You have built a non dynamic loading perl interpreter.'
	      @echo '     $(LIBRARY_LINK)'
	      @echo 'It will always run on any machine but will only'
	      @echo 'be able to load binary perl modules if they are the correct '
	      @echo 'version.  The version you have built with is:'
         $(foreach perl_executable, $(PERL), $(VERSION_MESSAGE))
      endef
   endif
  endif

  main : $(PERL_CMISS_MAKEFILE) $(PERL_WORKING_DIR) $(WORKING_DIR) $(LIBRARY_DIR)
ifeq ($(USE_DYNAMIC_LOADER),true)
	$(SHARED_INTERPRETER_BUILDS)
endif
	@echo
	@echo 'Building library ${LIBRARY}'
	@echo
ifneq ($(OPERATING_SYSTEM),win32)
	$(MAKE) --directory=$(PERL_WORKING_DIR) static
else
   #Use dmake as it supports back slashes for paths
	cd $(PERL_WORKING_DIR) ; unset SHELL ; dmake static
endif
	$(MAKE) --no-print-directory USE_DYNAMIC_LOADER=$(USE_DYNAMIC_LOADER) \
	  SHARED_LIBRARIES='$(SHARED_LIBRARIES)' TASK=source
	$(MAKE) --no-print-directory USE_DYNAMIC_LOADER=$(USE_DYNAMIC_LOADER) \
	  TASK=library
	$(WRITE_BUILD_MESSAGE)

  tidy :
  ifneq ($(OLD_FILES),)
	rm $(foreach file,$(OLD_FILES), $(WORKING_DIR)/$(file) )
  endif

  $(PERL_CMISS_MAKEFILE) : $(PERL) Perl_cmiss/Makefile.PL
	cd Perl_cmiss ; export CMISS_PERL_CALLBACK=$(CMISS_PERL_CALLBACK) CMISS_PERL_CALLBACK_SUFFIX=$(CMISS_PERL_CALLBACK_SUFFIX) ; $(PERL) Makefile.PL

  $(PERL_WORKING_DIR) :
	mkdir -p $@

  $(WORKING_DIR) :
	mkdir -p $@

  $(LIBRARY_DIR) :
	mkdir -p $@

clean:
	@echo "Cleaning some of house ..."
	-rm -rf $(PERL_WORKING_DIR) $(WORKING_DIR) $(LIBRARY) $(LIB_EXP)

allclean:
	@echo "Cleaning house ..."
	-rm -rf Perl_cmiss/generated/* generated/* lib/*

debug opt debug64 opt64:
	$(MAKE) --no-print-directory DEBUG=$(DEBUG) ABI=$(ABI)

  debug debug64: DEBUG=true
  opt opt64: DEBUG=false
  ifneq (,$(filter $(MACHNAME),ia64 x86_64))# ia64 or x86_64
    debug opt: ABI=64
  else
  ifeq ($(filter-out IRIX%,$(SYSNAME)),) #SGI
    debug opt: ABI=n32
  else
    debug opt: ABI=32
  endif
  endif
  debug64 opt64: ABI=64

all : debug opt
  ifneq ($(SYSNAME),Linux)
    all: debug64 opt64
  endif

update :
	cmissmake perl_interpreter

#-----------------------------------------------------------------------------
endif

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

ifeq ($(TASK),source)
#-----------------------------------------------------------------------------

  main : $(DEPEND_FILES) \
    $(foreach file,$(PMH_FILES), $(WORKING_DIR)/$(file) )

  # include the depend file dependencies
  ifneq ($(DEPEND_FILES),)
    sinclude $(DEPEND_FILES)
  endif

  # implicit rules for making the dependency files

  # KAT I think Solaris needed nawk rather than awk, but nawk is not usually
  # avaiable on Mandrake.  I don't have a Sun to try this out so I'll get it
  # working with awk on the machines I have.
  $(WORKING_DIR)/%.d : $(SOURCE_DIR)/%.c
	makedepend $(CPPFLAGS) -f- -Y $< 2> $@.tmp | sed -e 's%^source\([^ ]*\).o%$$(WORKING_DIR)\1.o $$(WORKING_DIR)\1.d%' > $@
# See if there is a dependency on perl
	@if grep /perl\\.h $@ > /dev/null; then set -x; echo '$$(WORKING_DIR)/perl_interpreter.o $$(WORKING_DIR)/perl_interpreter.d: $$(PERL)' >> $@; fi
	(grep pmh $@.tmp | grep makedepend | awk -F "[ ,]" '{printf("%s.%s:",substr($$4, 1, length($$4) - 2),"o"); for(i = 1 ; i <= NF ; i++)  { if (match($$i,"pmh")) printf(" source/%s", substr($$i, 2, length($$i) -2)) } printf("\n");}' | sed -e 's%^$(SOURCE_DIR)\([^ ]*\).o%$$(WORKING_DIR)\1.o $$(WORKING_DIR)\1.d%' | sed -e 's%$(SOURCE_DIR)\([^ ]*\).pmh%$$(WORKING_DIR)\1.pmh%' >> $@)

$(WORKING_DIR)/%.pmh : $(SOURCE_DIR)/%.pm
	utilities/pm2pmh $< > $@

#Dynamic loader code for putting shared objects into the interpreter
ifeq ($(USE_DYNAMIC_LOADER),true)
   ifeq ($(SHARED_LIBRARIES),)
      $(error Missing list of SHARED_LIBRARIES in source stage)
   endif
   SHARED_LIBRARY_HEADERS = $(patsubst %.so, %.soh, $(SHARED_LIBRARIES))

   UID2UIDH = $(CMISS_ROOT)/utilities/bin/$(BIN_ARCH_DIR)/bin2base64h

  .SUFFIXES : .so .soh

  # implicit rules for making the objects
  %.soh : %.so
	$(UID2UIDH) $< $@

  #Always regenerate the versions files as they have recorded for
  #us the versions that are built into this executable
  STATIC_HEADER := $(WORKING_DIR)/static_version.h
  DYNAMIC_VERSIONS_HEADER := $(WORKING_DIR)/dynamic_versions.h
  VERSION_HEADERS := $(DYNAMIC_VERSIONS_HEADER) $(STATIC_HEADER)
  $(DYNAMIC_VERSIONS_HEADER) : $(SHARED_LIBRARY_HEADERS)
	{ \
	$(foreach header, $(SHARED_LIBRARY_HEADERS), \
      echo 'static char libperlinterpreter$(word 3, $(subst /,' ',$(subst .,_,$(header))))$(word 4, $(subst /,' ',$(subst -,_,$(header))))[] = ' && \
      echo '#include "../../../$(header)"' && \
      echo ';' && ) \
	echo 'static struct Interpreter_library_strings interpreter_strings[] = {' && \
	$(foreach header, $(SHARED_LIBRARY_HEADERS), \
      echo '{"$(word 3, $(subst /,' ',$(header)))","$(word 4, $(subst /,' ',$(header)))", libperlinterpreter$(word 3, $(subst /,' ',$(subst .,_,$(header))))$(word 4, $(subst /,' ',$(subst -,_,$(header)))) },' && ) \
	echo '};'; \
	} > $@.new;
	@set -xe && \
	if [ ! -f $@ ] || ! diff $@ $@.new > /dev/null ; then \
		mv $@.new $@ ; \
	else \
		rm $@.new; \
	fi

  $(STATIC_HEADER):
  ifeq ($(STATIC_PERL_LIB),)
	echo '#define NO_STATIC_FALLBACK' > $@.new;
  else
	echo '/* undef NO_STATIC_FALLBACK */' > $@.new;
  endif
	@set -xe && \
	if [ ! -f $@ ] || ! diff $@ $@.new > /dev/null; then \
		mv $@.new $@; \
	else \
		rm $@.new; \
	fi

#Always build the .new and see if they should be updated.
#    .PHONY: version_headers
    $(VERSION_HEADERS): force
    .PHONY: force
    force: ;

    # version headers must exist for makedepend
    $(DEPEND_FILES): $(DYNAMIC_VERSIONS_HEADER) $(STATIC_HEADER)
endif
#-----------------------------------------------------------------------------
endif

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

ifeq ($(TASK),library)
#-----------------------------------------------------------------------------

  main : $(LIBRARY)
   #Always update the link for the .a libraries.
ifneq ($(SHARED_OBJECT), true)
	if [ -L $(LIBRARY_LINK) ] || [ -e $(LIBRARY_LINK) ] ; then \
		rm $(LIBRARY_LINK) ; \
	fi
	ln -s $(LIBRARY_VERSION)/$(LIBRARY_NAME) $(LIBRARY_LINK)
endif

  # explicit rule for making the library
  ifneq ($(SHARED_OBJECT), true)
    ifeq ($(USE_DYNAMIC_LOADER),true)
      $(LIBRARY) : $(WORKING_DIR)/perl_interpreter_dynamic.o
    endif

    $(LIBRARY):
	[ ! -f $@ ] || rm $@
	$(AR) $(ARFLAGS) $@ $^

    ifneq (,$(STATIC_PERL_LIB)) # have a static perl
      # Including all necessary objects from archives into output archive.
      # This is done by producing a relocatable object first.
      # Is there a better way?

      $(LIBRARY) : $(C_OBJ)
      # don't retain these relocatable objects
      .INTERMEDIATE : $(C_OBJ)

      #I have not got Win32 to work with building the libararies into the
      #perl_interpreter lib, instead I link them all together at the final link
      ifneq ($(OPERATING_SYSTEM),win32)
        LIBRARY_LIBS = $(DYNALOADER_LIB) $(PERL_CMISS_LIB) $(STATIC_PERL_LIB)
      else
        LIBRARY_LIBS = 
      endif
      $(C_OBJ) : $(WORKING_DIR)/perl_interpreter.o $(LIBRARY_LIBS)
		$(LD_RELOCATABLE) -o $@ $^

      # If there is an export file for libperl.a then use it for this library.
      ifneq ($(PERL_EXP),)
        main : $(LIB_EXP)

        $(LIB_EXP) : $(PERL_EXP)
			cp -f $^ $@
      endif

    endif

  else
    $(LIBRARY) : $(foreach unit, $(C_UNITS), $(WORKING_DIR)/$(unit).o ) \
         $(DYNALOADER_LIB) $(PERL_CMISS_LIB) $(STATIC_PERL_LIB)
		$(LD_SHARED) -o $@ $^ $(SHARED_LINK_LIBRARIES)
  endif

  # include the object dependencies
  ifneq ($(DEPEND_FILES),)
    include $(DEPEND_FILES)
  endif

  # implicit rules for making the objects
  $(WORKING_DIR)/%.o : $(SOURCE_DIR)/%.c
	$(CC) -o $@ $(CPPFLAGS) $(CFLAGS) $<
# Useful when using the debugger to find out which subroutine of the same name.
# 	[ -L $(@D)/$*.c ] || ln -s $(CURDIR)/$< $(@D)/$*.c
# 	$(CC) -o $@ -I$(<D) $(CPPFLAGS) $(CFLAGS) $(@D)/$*.c

#-----------------------------------------------------------------------------
endif

#-----------------------------------------------------------------------------

