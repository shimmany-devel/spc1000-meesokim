#
# Makefile - Raspberry Pi 4 Model B Bare-metal SPC-1000 Emulator (AArch32)
#

CIRCLEHOME ?= ../circle
SHARED_DIR = ../baremetal
OBJDIR     = build

RASPPI = 4
AARCH  = 32

USE_VCHIQ_SOUND ?= 1
CFLAGS   += -DUSE_VCHIQ_SOUND=$(USE_VCHIQ_SOUND)
CPPFLAGS += -DUSE_VCHIQ_SOUND=$(USE_VCHIQ_SOUND)

KERNEL_MAX_SIZE = 0x400000
DEFINE += -DKERNEL_MAX_SIZE=$(KERNEL_MAX_SIZE)

# build/ 하위 패턴 규칙을 사용하므로 Rules.mk 자동 .d 생성 비활성화
CHECK_DEPS = 0

OBJS = $(OBJDIR)/main.o \
       $(OBJDIR)/kernel.o \
       $(OBJDIR)/MC6847.o \
       $(OBJDIR)/Z80SPC.o \
       $(OBJDIR)/spcall.o \
       $(OBJDIR)/emu2149.o \
       $(OBJDIR)/tape_loader.o \
       $(OBJDIR)/cassette.o \
       $(OBJDIR)/stub.o \
       $(OBJDIR)/ugui/ugui.o \
       $(OBJDIR)/miniz/miniz.o \
       $(OBJDIR)/miniz/miniz_tdef.o \
       $(OBJDIR)/miniz/miniz_tinfl.o \
       $(OBJDIR)/miniz/miniz_zip.o \
       $(OBJDIR)/bzip2/blocksort.o \
       $(OBJDIR)/bzip2/huffman.o \
       $(OBJDIR)/bzip2/crctable.o \
       $(OBJDIR)/bzip2/randtable.o \
       $(OBJDIR)/bzip2/compress.o \
       $(OBJDIR)/bzip2/decompress.o \
       $(OBJDIR)/bzip2/bzlib.o

LIBS = $(CIRCLEHOME)/addon/vc4/sound/libvchiqsound.a \
       $(CIRCLEHOME)/addon/vc4/vchiq/libvchiq.a \
       $(CIRCLEHOME)/addon/linux/liblinuxemu.a \
       $(CIRCLEHOME)/lib/sched/libsched.a \
       $(CIRCLEHOME)/lib/sound/libsound.a \
       $(CIRCLEHOME)/lib/usb/libusb.a \
       $(CIRCLEHOME)/lib/input/libinput.a \
       $(CIRCLEHOME)/lib/fs/libfs.a \
       $(CIRCLEHOME)/addon/SDCard/libsdcard.a \
       $(CIRCLEHOME)/addon/fatfs/libfatfs.a \
       $(CIRCLEHOME)/lib/libcircle.a

INCLUDE = -I$(CIRCLEHOME)/addon -I$(SHARED_DIR)/miniz -I$(SHARED_DIR)/bzip2 -I$(SHARED_DIR) -I.

include $(CIRCLEHOME)/Rules.mk

$(OBJDIR)/%.o: $(SHARED_DIR)/%.cpp
	@mkdir -p $(dir $@)
	@echo "  CPP   $<"
	@$(CPP) $(CPPFLAGS) -c -o $@ $<

$(OBJDIR)/%.o: $(SHARED_DIR)/%.c
	@mkdir -p $(dir $@)
	@echo "  CC    $<"
	@$(CC) $(CFLAGS) $(C_STANDARD) -c -o $@ $<

.PHONY: dist clean-all

dist: $(TARGET).img
	$(MAKE) -C sdcard CIRCLEHOME="$(abspath $(CIRCLEHOME))"

clean-all: clean
	rm -rf $(OBJDIR) dist
	$(MAKE) -C sdcard clean
