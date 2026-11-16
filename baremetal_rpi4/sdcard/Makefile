#
# baremetal_rpi4/sdcard/Makefile
# Raspberry Pi 4 Model B 부팅용 SD 카드 파일 패키지 생성
#

CIRCLEHOME ?= ../../circle
BOOTDIR     = $(CIRCLEHOME)/boot
DISTDIR     = ../dist
FIRMWARE   ?= 0641c5bf25d185d5bf25d8dcafd1da6dc8fdbf68
BASEURL     = https://github.com/raspberrypi/firmware/raw/$(FIRMWARE)/boot

FW_FILES = LICENCE.broadcom COPYING.linux \
           start4.elf fixup4.dat bcm2711-rpi-4-b.dtb

.PHONY: all clean

all: $(FW_FILES) armstub7-rpi4.bin config.txt spcconfig.ini ../kernel7l.img
	@mkdir -p $(DISTDIR)
	cp $(FW_FILES) armstub7-rpi4.bin config.txt spcconfig.ini ../kernel7l.img $(DISTDIR)/
	@echo ""
	@echo "============================================================"
	@echo "RPi 4B 부팅 패키지 생성 완료: $(abspath $(DISTDIR))"
	@echo "FAT32 포맷된 SD 카드 루트에 위 파일들과 taps/ 폴더를 복사하세요."
	@echo "============================================================"

$(FW_FILES):
	@if [ -f "$(BOOTDIR)/$@" ]; then \
		echo "Copying $@ from $(BOOTDIR)/..."; \
		cp "$(BOOTDIR)/$@" $@; \
	else \
		echo "Downloading $@..."; \
		wget -q -O $@ "$(BASEURL)/$@"; \
	fi

armstub7-rpi4.bin:
	@if [ ! -f "$(BOOTDIR)/armstub7-rpi4.bin" ]; then \
		echo "Building armstub7-rpi4.bin in $(BOOTDIR)..."; \
		$(MAKE) -C "$(BOOTDIR)" armstub; \
	fi
	cp "$(BOOTDIR)/armstub7-rpi4.bin" $@

config.txt: $(BOOTDIR)/config32.txt
	cp $< $@

spcconfig.ini: ../../baremetal/sdcard/spcconfig.ini
	cp $< $@

clean:
	rm -f $(FW_FILES) armstub7-rpi4.bin config.txt spcconfig.ini
