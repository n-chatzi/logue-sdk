# #############################################################################
# Prologue Oscillator Makefile
# #############################################################################

ifeq ($(OS),Windows_NT)
ifeq ($(MSYSTEM), MSYS)
    detected_OS := $(shell uname -s)
else
    detected_OS := Windows
endif
else
    detected_OS := $(shell uname -s)
endif

PROJECT_DIR = .
SDK_DIR ?= .

PLATFORM_DIR = $(SDK_DIR)/platform
TOOLS_DIR = $(SDK_DIR)/tools

TPL_DIR = $(PLATFORM_DIR)/tpl
EXT_DIR = $(PLATFORM_DIR)/ext

CMSIS_DIR = $(EXT_DIR)/CMSIS/CMSIS

# #############################################################################
# configure archive utility
# #############################################################################

ZIP = /usr/bin/zip
ZIP_ARGS = -r -m -q

ifeq ($(OS),Windows_NT)
ifneq ($(MSYSTEM), MSYS)
  ZIP = $(TOOLS_DIR)/zip/bin/zip
endif
endif

# #############################################################################
# configure cross compilation 
# #############################################################################

MCU = cortex-m4

GCC_TARGET = arm-none-eabi-
GCC_BIN_PATH = $(TOOLS_DIR)/gcc/gcc-arm-none-eabi-5_4-2016q3/bin

CROSS_COMPILE = $(GCC_BIN_PATH)/$(GCC_TARGET)

# #############################################################################
# setup commands
# #############################################################################
# Don't display the command when run
Q = @
SAY = $(Q)echo
MKDIR = $(Q)mkdir -p
# CP = $(Q)cp -a

CC   = $(Q)$(CROSS_COMPILE)gcc
CXXC = $(Q)$(CROSS_COMPILE)g++
LD   = $(Q)$(CROSS_COMPILE)gcc
#LD  = $(Q)$(CROSS_COMPILE)g++
CP   = $(Q)$(CROSS_COMPILE)objcopy
AS   = $(Q)$(CROSS_COMPILE)gcc -x assembler-with-cpp
AR   = $(Q)$(CROSS_COMPILE)ar
OD   = $(Q)$(CROSS_COMPILE)objdump
SZ   = $(Q)$(CROSS_COMPILE)size

HEX  = $(Q)$(CP) -O ihex
BIN  = $(Q)$(CP) -O binary
MV = $(Q)mv
RM = $(Q)rm -rf

#########################################
# Architecture specifc section

ifeq ($(TYPE),osc)
DARCH = -DSTM32F401xC
LD_DIR = $(PLATFORM_DIR)/ld/401
SYMBOLS = $(LD_DIR)/osc_api.syms
else
DARCH = -DSTM32F446xE
LD_DIR = $(PLATFORM_DIR)/ld/446
SYMBOLS = $(LD_DIR)/main_api.syms
endif

LDSCRIPT = $(LD_DIR)/user$(TYPE).ld
UNIT = $(TPL_DIR)/_u$(TYPE)_unit.c

# Assembler Defines
DADEFS = $(DARCH) -DCORTEX_USE_FPU=TRUE -DARM_MATH_CM4

# CXX Defines
DDEFS = $(DADEFS) -D__FPU_PRESENT

DLIBS = -lm

#########################################
# Options

COPT = -std=c11 -mstructure-size-boundary=8
CXXOPT = -std=c++11 -fno-rtti -fno-exceptions -fno-non-call-exceptions

LDOPT = -Xlinker --just-symbols=$(SYMBOLS)

CWARN = -W -Wall -Wextra
CXXWARN =

FPU_OPTS = -mfloat-abi=hard -mfpu=fpv4-sp-d16 -fsingle-precision-constant -fcheck-new

OPT = -g -Os -mlittle-endian
OPT += $(FPU_OPTS)
#OPT += -flto

TOPT = -mthumb -mno-thumb-interwork -DTHUMB_NO_INTERWORKING -DTHUMB_PRESENT

# #############################################################################
# set targets and directories
# #############################################################################

PKG_PRLG = $(PROJECT).prlgunit
PKG_MNLG = $(PROJECT).mnlgxdunit
MANIFEST = manifest.json
PAYLOAD = payload.bin

BUILD_DIR = $(PROJECT_DIR)/build
OBJ_DIR = $(BUILD_DIR)/obj
LST_DIR = $(BUILD_DIR)/lst

ASMSRC = $(UASMSRC)

ASMXSRC = $(UASMXSRC)

CSRC = $(UNIT) $(UCSRC)

CXXSRC = $(UCXXSRC)

vpath %.s $(sort $(dir $(ASMSRC)))
vpath %.S $(sort $(dir $(ASMXSRC)))
vpath %.c $(sort $(dir $(CSRC)))
vpath %.cpp $(sort $(dir $(CXXSRC)))

ASMOBJS := $(addprefix $(OBJ_DIR)/, $(notdir $(ASMSRC:.s=.o)))
ASMXOBJS := $(addprefix $(OBJ_DIR)/, $(notdir $(ASMXSRC:.S=.o)))
COBJS := $(addprefix $(OBJ_DIR)/, $(notdir $(CSRC:.c=.o)))
CXXOBJS := $(addprefix $(OBJ_DIR)/, $(notdir $(CXXSRC:.cpp=.o)))

OBJS := $(ASMXOBJS) $(ASMOBJS) $(COBJS) $(CXXOBJS)

DINC_DIR = $(PLATFORM_DIR)/inc 			\
	       $(PLATFORM_DIR)/inc/api 		\
	       $(PLATFORM_DIR)/inc/dsp 		\
	       $(PLATFORM_DIR)/inc/utils 	\
           $(CMSIS_DIR)/Include

INC_DIR := $(patsubst %,-I%,$(DINC_DIR) $(UINC_DIR))

DEFS := $(DDEFS) $(UDEFS)
ADEFS := $(DADEFS) $(UADEFS)

LIBS := $(DLIBS) $(ULIBS)

LIB_DIR := $(patsubst %,-I%,$(DLIB_DIR) $(ULIB_DIR))


# #############################################################################
# compiler flags
# #############################################################################

MCFLAGS   := -mcpu=$(MCU)
ODFLAGS	  = -x --syms
ASFLAGS   = $(MCFLAGS) -g $(TOPT) -Wa,-alms=$(LST_DIR)/$(notdir $(<:.s=.lst)) $(ADEFS)
ASXFLAGS  = $(MCFLAGS) -g $(TOPT) -Wa,-alms=$(LST_DIR)/$(notdir $(<:.S=.lst)) $(ADEFS)
CFLAGS    = $(MCFLAGS) $(TOPT) $(OPT) $(COPT) $(CWARN) -Wa,-alms=$(LST_DIR)/$(notdir $(<:.c=.lst)) $(DEFS)
CXXFLAGS  = $(MCFLAGS) $(TOPT) $(OPT) $(CXXOPT) $(CXXWARN) -Wa,-alms=$(LST_DIR)/$(notdir $(<:.cpp=.lst)) $(DEFS)
LDFLAGS   = $(MCFLAGS) $(TOPT) $(OPT) -nostartfiles $(LIB_DIR) -Wl,-Map=$(BUILD_DIR)/$(PROJECT).map,--cref,--no-warn-mismatch,--library-path=$(LD_DIR),--script=$(LDSCRIPT) $(LDOPT)

OUTFILES := $(BUILD_DIR)/$(PROJECT).elf \
	        $(BUILD_DIR)/$(PROJECT).hex \
	        $(BUILD_DIR)/$(PROJECT).bin \
	        $(BUILD_DIR)/$(PROJECT).dmp \
	        $(BUILD_DIR)/$(PROJECT).list

###############################################################################
# targets
###############################################################################

all: PRE_ALL $(OBJS) $(OUTFILES) POST_ALL

PRE_ALL:

POST_ALL: package_prlg package_mnlg

$(OBJS): | $(BUILD_DIR) $(OBJ_DIR) $(LST_DIR)

$(BUILD_DIR):
	$(SAY) Compiler Options
	$(SAY) $(CC) -c $(CFLAGS) -I. $(INC_DIR)
	$(SAY)
	$(MKDIR) $(BUILD_DIR)

$(OBJ_DIR):
	$(MKDIR) $(OBJ_DIR)

$(LST_DIR):
	$(MKDIR) $(LST_DIR)

$(ASMOBJS) : $(OBJ_DIR)/%.o : %.s Makefile
	$(SAY) Assembling $(<F)
	$(AS) -c $(ASFLAGS) -I. $(INC_DIR) $< -o $@

$(ASMXOBJS) : $(OBJ_DIR)/%.o : %.S Makefile
	$(SAY) Assembling $(<F)
	$(CC) -c $(ASXFLAGS) -I. $(INC_DIR) $< -o $@

$(COBJS) : $(OBJ_DIR)/%.o : %.c Makefile
	$(SAY) Compiling $(<F)
	$(CC) -c $(CFLAGS) -I. $(INC_DIR) $< -o $@

$(CXXOBJS) : $(OBJ_DIR)/%.o : %.cpp Makefile
	$(SAY) Compiling $(<F)
	$(CXXC) -c $(CXXFLAGS) -I. $(INC_DIR) $< -o $@

$(BUILD_DIR)/%.elf: $(OBJS) $(LDSCRIPT)
	$(SAY) Linking $@
	$(LD) $(OBJS) $(LDFLAGS) $(LIBS) -o $@

%.hex: %.elf
	$(SAY) Creating $@
	$(HEX) $< $@

%.bin: %.elf
	$(SAY) Creating $@
	$(BIN) $< $@

%.dmp: %.elf
	$(SAY) Creating $@
	$(OD) $(ODFLAGS) $< > $@
	$(SAY)
	$(SZ) $<
	$(SAY)

%.list: %.elf
	$(SAY) Creating $@
	$(OD) -S $< > $@

clean:
	$(SAY) Cleaning $(PROJECT)
	$(RM) .dep $(BUILD_DIR) 
	$(RM) $(OUTPUT_DIR)/$(PKG_PRLG) 
	$(RM) $(OUTPUT_DIR)/$(PKG_MNLG)
	$(SAY) Done
	$(SAY)

package_prlg:
	$(SAY) Packaging: $(PKG_PRLG)
	$(SAY) In: $(OUTPUT_DIR)
	$(MKDIR) $(PROJECT)
	@cp -a $(MANIFEST) $(PROJECT)/
	@cp -a $(BUILD_DIR)/$(PROJECT).bin $(PROJECT)/$(PAYLOAD)
	$(ZIP) $(ZIP_ARGS) $(PROJECT).zip $(PROJECT)
	$(MKDIR) $(OUTPUT_DIR)
	$(MV) $(PROJECT).zip $(OUTPUT_DIR)/$(PKG_PRLG)
	$(SAY) Done
	$(SAY)

package_mnlg:
	$(SAY) Packaging: $(PKG_MNLG)
	$(SAY) In: $(OUTPUT_DIR)
	$(MKDIR) $(PROJECT)
	@cp -a $(MANIFEST) $(PROJECT)/
	@cp -a $(BUILD_DIR)/$(PROJECT).bin $(PROJECT)/$(PAYLOAD)
	$(ZIP) $(ZIP_ARGS) $(PROJECT).zip $(PROJECT)
	$(MKDIR) $(OUTPUT_DIR)
	$(MV) $(PROJECT).zip $(OUTPUT_DIR)/$(PKG_MNLG)
	$(SAY) Done
	$(SAY)