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

CC   = $(CROSS_COMPILE)gcc
CXXC = $(CROSS_COMPILE)g++
LD   = $(CROSS_COMPILE)gcc
#LD  = $(CROSS_COMPILE)g++
CP   = $(CROSS_COMPILE)objcopy
AS   = $(CROSS_COMPILE)gcc -x assembler-with-cpp
AR   = $(CROSS_COMPILE)ar
OD   = $(CROSS_COMPILE)objdump
SZ   = $(CROSS_COMPILE)size

HEX  = $(CP) -O ihex
BIN  = $(CP) -O binary

RM = rm -rf

#########################################
# Architecture specifc section

DARCH = -DSTM32F446xE
LD_DIR = $(PLATFORM_DIR)/ld/446
SYMBOLS = $(LD_DIR)/main_api.syms

ifeq ($(TYPE),osc)
DARCH = -DSTM32F401xC
LD_DIR = $(PLATFORM_DIR)/ld/401
SYMBOLS = $(LD_DIR)/osc_api.syms
endif

LDSCRIPT = $(LD_DIR)/user$(TYPE).ld
UNIT = $(TPL_DIR)/_u$(TYPE)_unit.c

RULESPATH = $(LD_DIR)

DADEFS = $(DARCH) -DCORTEX_USE_FPU=TRUE -DARM_MATH_CM4
DDEFS = $(DARCH) -DCORTEX_USE_FPU=TRUE -DARM_MATH_CM4 -D__FPU_PRESENT

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

PKG_TEMP_DIR = $(OUTPUT_DIR)/temp

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
LDFLAGS   = $(MCFLAGS) $(TOPT) $(OPT) -nostartfiles $(LIB_DIR) -Wl,-Map=$(BUILD_DIR)/$(PROJECT).map,--cref,--no-warn-mismatch,--library-path=$(RULESPATH),--script=$(LDSCRIPT) $(LDOPT)

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
	@echo Compiler Options
	@echo $(CC) -c $(CFLAGS) -I. $(INC_DIR)
	@echo
	@mkdir -p $(BUILD_DIR)

$(OBJ_DIR):
	@mkdir -p $(OBJ_DIR)

$(LST_DIR):
	@mkdir -p $(LST_DIR)

$(ASMOBJS) : $(OBJ_DIR)/%.o : %.s Makefile
	@echo Assembling $(<F)
	@$(AS) -c $(ASFLAGS) -I. $(INC_DIR) $< -o $@

$(ASMXOBJS) : $(OBJ_DIR)/%.o : %.S Makefile
	@echo Assembling $(<F)
	@$(CC) -c $(ASXFLAGS) -I. $(INC_DIR) $< -o $@

$(COBJS) : $(OBJ_DIR)/%.o : %.c Makefile
	@echo Compiling $(<F)
	@$(CC) -c $(CFLAGS) -I. $(INC_DIR) $< -o $@

$(CXXOBJS) : $(OBJ_DIR)/%.o : %.cpp Makefile
	@echo Compiling $(<F)
	@$(CXXC) -c $(CXXFLAGS) -I. $(INC_DIR) $< -o $@

$(BUILD_DIR)/%.elf: $(OBJS) $(LDSCRIPT)
	@echo Linking $@
	@$(LD) $(OBJS) $(LDFLAGS) $(LIBS) -o $@

%.hex: %.elf
	@echo Creating $@
	@$(HEX) $< $@

%.bin: %.elf
	@echo Creating $@
	@$(BIN) $< $@

%.dmp: %.elf
	@echo Creating $@
	@$(OD) $(ODFLAGS) $< > $@
	@echo
	@$(SZ) $<
	@echo

%.list: %.elf
	@echo Creating $@
	@$(OD) -S $< > $@

clean:
	@echo Cleaning $(PROJECT)
	$(RM) .dep $(BUILD_DIR) 
	$(RM) $(OUTPUT_DIR)/$(PKG_PRLG) 
	$(RM) $(OUTPUT_DIR)/$(PKG_MNLG)
	@echo Done
	@echo

package_prlg:
	@echo Packaging: $(PKG_PRLG)
	@echo In: $(OUTPUT_DIR)
	@mkdir -p $(PKG_TEMP_DIR)
	@cp -a $(MANIFEST) $(PKG_TEMP_DIR)
	@cp -a $(BUILD_DIR)/$(PROJECT).bin $(PKG_TEMP_DIR)/$(PAYLOAD)
	@$(ZIP) $(ZIP_ARGS) $(PKG_TEMP_DIR)/$(PROJECT).zip $(PKG_TEMP_DIR)
	@mkdir -p $(OUTPUT_DIR)
	@mv $(PKG_TEMP_DIR)/$(PROJECT).zip $(OUTPUT_DIR)/$(PKG_PRLG)
	@$(RM) $(PKG_TEMP_DIR)
	@echo Done
	@echo

package_mnlg:
	@echo Packaging: $(PKG_PRLG)
	@echo In: $(OUTPUT_DIR)
	@mkdir -p $(PKG_TEMP_DIR)
	@cp -a $(MANIFEST) $(PKG_TEMP_DIR)
	@cp -a $(BUILD_DIR)/$(PROJECT).bin $(PKG_TEMP_DIR)/$(PAYLOAD)
	@$(ZIP) $(ZIP_ARGS) $(PKG_TEMP_DIR)/$(PROJECT).zip $(PKG_TEMP_DIR)
	@mkdir -p $(OUTPUT_DIR)
	@mv $(PKG_TEMP_DIR)/$(PROJECT).zip $(OUTPUT_DIR)/$(PKG_MNLG)
	@$(RM) $(PKG_TEMP_DIR)
	@echo Done
	@echo