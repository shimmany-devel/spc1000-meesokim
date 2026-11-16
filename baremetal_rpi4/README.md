# SPC-1000 Baremetal Emulator for Raspberry Pi 4 Model B (`baremetal_rpi4`)

Raspberry Pi 4 Model B (BCM2711, ARM Cortex-A72, AArch32 모드 `kernel7l.img`) 전용 SPC-1000 베어메탈 에뮬레이터 빌드 디렉토리입니다.

## 주요 변경 및 설계 사항

1. **공용 코어 소스 공유 및 빌드 격리**:
   - `../baremetal/`의 검증된 에뮬레이터 소스(`kernel.cpp`, `Z80SPC.c`, `MC6847.c`, `cassette.cpp`, `ugui/` 등)를 그대로 참조하되, 오브젝트 파일은 `build/` 하위 디렉토리에 생성해 RPi 1(`baremetal/`) 빌드와 충돌하지 않습니다.
   - `baremetal/kernel.cpp`의 프레임버퍼 2x 확대 루프에서 1366x768 등 특정 모니터 해상도 시 발생할 수 있던 `(u64 *)dst0` 비정렬 접근 위험을 `offX` 8바이트 정렬 및 4바이트/2바이트 안전 헬퍼(`WriteScanline2x`)로 보완했습니다.
2. **RPi 4B 타겟 설정 (`AArch32`)**:
   - `RASPPI = 4`, `AARCH = 32`로 빌드하여 `circle/Rules.mk` 기본 타겟인 **`kernel7l.img`**를 생성합니다. (`KERNEL_MAX_SIZE = 0x400000`)
   - Circle의 `CXHCIDevice`(USB xHCI)와 `CEMMCDevice`(`ARM_EMMC2_BASE`)를 그대로 활용합니다.
3. **RPi 4B 전용 SD 카드 부트 패키지 (`sdcard/` -> `dist/`)**:
   - RPi 1~3용 `bootcode.bin`/`start.elf` 대신 RPi 4B 필수 파일(`start4.elf`, `fixup4.dat`, `bcm2711-rpi-4-b.dtb`, `armstub7-rpi4.bin`, `config.txt` <- `circle/boot/config32.txt`)을 수집해 `dist/`에 완성 패키지를 생성합니다.

## 사전 준비 (Circle RPi 4B 라이브러리 빌드)

루트에서 `./build_all.sh --only rpi4`를 실행하거나, 수동으로 아래 순서대로 진행합니다.

```bash
cd ../circle
./configure -r 4 --kernel-max-size 4 -f
./makeall --nosample
cd addon/SDCard && make
cd ../fatfs && ../../baremetal/patch_circle_fatfs.sh || (sed -i 's/#define FF_LFN_UNICODE\s\+[0-9]/#define FF_LFN_UNICODE 2/' ffconf.h && make clean && make)
cd ../linux && make
cd ../vc4 && ./makeall --nosample
```

## 빌드 및 SD 카드 배포

```bash
cd baremetal_rpi4
make
make dist
```

생성된 `baremetal_rpi4/dist/` 안의 모든 파일(`kernel7l.img`, `start4.elf`, `fixup4.dat`, `bcm2711-rpi-4-b.dtb`, `armstub7-rpi4.bin`, `config.txt`, `spcconfig.ini`, 라이선스 파일)을 FAT32로 포맷한 SD 카드 루트에 복사하고, `tape/taps/` 폴더를 SD 카드의 `taps/` 경로에 복사해 Raspberry Pi 4 Model B에서 부팅하세요.
