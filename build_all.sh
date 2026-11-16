#!/usr/bin/env bash
# build_all.sh - spc1000-miso 전체 서브디렉토리 일괄 빌드 및 결과물 정리 스크립트

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
JOBS="$(nproc 2>/dev/null || echo 4)"
ONLY_GROUPS="all"
DO_CLEAN=1
WITH_LEGACY=0

PASS_LIST=()
FAIL_LIST=()
SKIP_LIST=()

usage() {
    cat <<EOF
사용법: $0 [옵션]

옵션:
  --only <그룹목록>   빌드할 그룹 지정 (쉼표 구분, 기본: all)
                      가능한 값: all, tools, host, win, wasm, bios, rpi1, rpi4, legacy
  --with-legacy       레거시/실험 디렉토리(spc1000_circle, rpibox, mc6847, spcbox) 포함
  --no-clean          사전 clean 생략 (증분 빌드)
  -j, --jobs <N>      병렬 빌드 작업 수 (기본: $JOBS)
  -h, --help          도움말 출력

예시:
  $0                          # 전체 표준 타겟 일괄 빌드
  $0 --only tools,host        # 유틸리티 + PC 호스트 에뮬레이터만 빌드
  $0 --only rpi4              # Raspberry Pi 4 Model B 베어메탈 및 SD 패키지만 빌드
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)
            ONLY_GROUPS="$2"
            shift 2
            ;;
        --with-legacy)
            WITH_LEGACY=1
            shift
            ;;
        --no-clean)
            DO_CLEAN=0
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1" >&2
            usage
            exit 1
            ;;
    esac
done

want_group() {
    local target="$1"
    if [[ "$ONLY_GROUPS" == "all" ]]; then
        return 0
    fi
    [[ ",$ONLY_GROUPS," == *",$target,"* ]]
}

run_step() {
    local name="$1"
    shift
    echo ""
    echo "------------------------------------------------------------"
    echo "[BUILD] $name"
    echo "------------------------------------------------------------"
    if "$@"; then
        PASS_LIST+=("$name")
        echo "[PASS] $name"
        return 0
    else
        FAIL_LIST+=("$name")
        echo "[FAIL] $name" >&2
        return 1
    fi
}

skip_step() {
    local name="$1"
    local reason="$2"
    SKIP_LIST+=("$name ($reason)")
    echo "[SKIP] $name - $reason"
}

# Circle 라이브러리 특정 RASPPI 버전(1 또는 4)으로 빌드
build_circle() {
    local rpi="$1"
    local circle_dir="$ROOT_DIR/circle"

    (
        cd "$circle_dir"
        ./configure -r "$rpi" --kernel-max-size 4 -f
        if [[ "$DO_CLEAN" -eq 1 ]]; then
            ./makeall --nosample clean
        fi
        ./makeall --nosample -j"$JOBS"

        make -C addon/SDCard clean >/dev/null 2>&1 || true
        make -C addon/SDCard -j"$JOBS"

        # FATFS 한글 LFN(UTF-8) 패치 및 빌드
        sed -i 's/#define FF_LFN_UNICODE\s\+[0-9]/#define FF_LFN_UNICODE 2/' addon/fatfs/ffconf.h
        make -C addon/fatfs clean >/dev/null 2>&1 || true
        make -C addon/fatfs -j"$JOBS"

        make -C addon/linux clean >/dev/null 2>&1 || true
        make -C addon/linux -j"$JOBS"

        (
            cd addon/vc4
            if [[ "$DO_CLEAN" -eq 1 ]]; then
                ./makeall --nosample clean
            fi
            ./makeall --nosample -j"$JOBS"
        )
    )
}

mkdir -p "$DIST_DIR"

# ============================================================
# 1. 유틸리티 및 서브모듈 도구 (tools)
# ============================================================
if want_group "tools"; then
    mkdir -p "$DIST_DIR/tools"

    run_step "txt2bas" bash -c "
        cd '$ROOT_DIR/txt2bas'
        [[ '$DO_CLEAN' -eq 1 ]] && make clean
        make -j'$JOBS'
        cp -f txt2bas bin2tap bas2tap tapinfo tap2cas cas2tap wav2tap '$DIST_DIR/tools/'
    "

    run_step "tape-utils" bash -c "
        cd '$ROOT_DIR/tape'
        [[ '$DO_CLEAN' -eq 1 ]] && make clean
        make -j'$JOBS'
        cp -f wav2tap1 tapinfo apple1basic-decode mmzx81 '$DIST_DIR/tools/'
    "

    run_step "spcbios/vfman22" bash -c "
        cd '$ROOT_DIR/spcbios/vfman22'
        [[ '$DO_CLEAN' -eq 1 ]] && make clean
        make -j'$JOBS'
        cp -f vfread vfwrite vformat vferase vfd2d88 putspc1000 '$DIST_DIR/tools/'
    "

    run_step "z80/z80asm" bash -c "
        cd '$ROOT_DIR/z80/z80asm'
        [[ '$DO_CLEAN' -eq 1 ]] && make clean
        make -j'$JOBS'
        cp -f z80asm '$DIST_DIR/tools/'
    "

    run_step "z80/z80sim" bash -c "
        cd '$ROOT_DIR/z80/z80sim'
        [[ '$DO_CLEAN' -eq 1 ]] && make clean
        make -j'$JOBS'
        cp -f z80sim '$DIST_DIR/tools/'
    "

    run_step "jgz80" bash -c "
        cd '$ROOT_DIR/jgz80'
        [[ '$DO_CLEAN' -eq 1 ]] && make clean
        make -j'$JOBS'
        cp -f z80_tests '$DIST_DIR/tools/'
    "

    run_step "emu2149" bash -c "
        [[ '$DO_CLEAN' -eq 1 ]] && rm -rf '$ROOT_DIR/emu2149/build'
        cmake -S '$ROOT_DIR/emu2149' -B '$ROOT_DIR/emu2149/build'
        cmake --build '$ROOT_DIR/emu2149/build' -j'$JOBS'
    "

    run_step "samdisk" bash -c "
        [[ '$DO_CLEAN' -eq 1 ]] && rm -rf '$ROOT_DIR/samdisk/build'
        cmake -S '$ROOT_DIR/samdisk' -B '$ROOT_DIR/samdisk/build'
        cmake --build '$ROOT_DIR/samdisk/build' -j'$JOBS'
        [[ -f '$ROOT_DIR/samdisk/build/samdisk' ]] && cp -f '$ROOT_DIR/samdisk/build/samdisk' '$DIST_DIR/tools/' || true
    "
fi

# ============================================================
# 2. PC 네이티브 에뮬레이터 (host)
# ============================================================
if want_group "host"; then
    mkdir -p "$DIST_DIR/host"

    run_step "baremetal-host" bash -c "
        cd '$ROOT_DIR/baremetal'
        [[ '$DO_CLEAN' -eq 1 ]] && make -f Makefile.host clean
        make -f Makefile.host -j'$JOBS'
        cp -f spc1000.host '$DIST_DIR/host/'
    "

    run_step "sdl2-bin" bash -c "
        cd '$ROOT_DIR/sdl2'
        [[ '$DO_CLEAN' -eq 1 ]] && make clean
        make bin -j'$JOBS'
        cp -f main '$DIST_DIR/host/sdl2_main'
    "

    if [[ -f /usr/include/SDL2/SDL_ttf.h ]] && [[ -f /usr/include/SDL2/SDL_image.h ]]; then
        run_step "sdl-wasm-bin" bash -c "
            cd '$ROOT_DIR/sdl-wasm'
            [[ '$DO_CLEAN' -eq 1 ]] && rm -f main
            make bin
            cp -f main '$DIST_DIR/host/sdl-wasm_main'
        "
    else
        skip_step "sdl-wasm-bin" "libsdl2-ttf-dev / libsdl2-image-dev 미설치"
    fi

    if [[ -f /usr/include/SDL/SDL.h ]] && [[ -f /usr/include/guichan.hpp ]]; then
        run_step "spcemul" bash -c "
            cd '$ROOT_DIR/spcemul'
            [[ '$DO_CLEAN' -eq 1 ]] && make clean
            make -j'$JOBS'
            cp -f spcemul '$DIST_DIR/host/'
        "
    else
        skip_step "spcemul" "SDL1.2 / libguichan-dev 미설치"
    fi
fi

# ============================================================
# 3. Windows MinGW32 크로스 빌드 (win)
# ============================================================
if want_group "win"; then
    if command -v i686-w64-mingw32-g++ >/dev/null 2>&1 && [[ -f /usr/i686-w64-mingw32/include/SDL2/SDL.h ]]; then
        mkdir -p "$DIST_DIR/windows"
        run_step "baremetal-windows" bash -c "
            cd '$ROOT_DIR/baremetal'
            [[ '$DO_CLEAN' -eq 1 ]] && make -f Makefile.windows clean
            make -f Makefile.windows -j'$JOBS'
            cp -f spc1000.windows.exe '$DIST_DIR/windows/'
        "
    else
        skip_step "baremetal-windows" "i686-w64-mingw32-g++ 또는 MinGW32 SDL2 미설치"
    fi
fi

# ============================================================
# 4. WebAssembly 빌드 (wasm)
# ============================================================
if want_group "wasm"; then
    if command -v emcc >/dev/null 2>&1 || [[ -f "$HOME/emsdk/emsdk_env.sh" ]]; then
        mkdir -p "$DIST_DIR/wasm/sdl2" "$DIST_DIR/wasm/sdl-wasm"
        if ! command -v emcc >/dev/null 2>&1; then
            # shellcheck source=/dev/null
            source "$HOME/emsdk/emsdk_env.sh" >/dev/null 2>&1
        fi

        run_step "sdl2-wasm" bash -c "
            cd '$ROOT_DIR/sdl2'
            [[ '$DO_CLEAN' -eq 1 ]] && rm -f *.wasm.o miniz/*.o index.js index.wasm index.data
            make wasm -j'$JOBS'
            cp -f index.html keyboard.html index.js index.wasm index.data '$DIST_DIR/wasm/sdl2/'
        "

        run_step "sdl-wasm-web" bash -c "
            cd '$ROOT_DIR/sdl-wasm'
            make wasm
            cp -f index.html index.js index.wasm index.data '$DIST_DIR/wasm/sdl-wasm/'
        "
    else
        skip_step "wasm" "Emscripten SDK(emsdk) 미설치"
    fi
fi

# ============================================================
# 5. BIOS / CP/M (bios)
# ============================================================
if want_group "bios"; then
    if command -v sdcc >/dev/null 2>&1 && command -v sdasz80 >/dev/null 2>&1; then
        if command -v hex2bin >/dev/null 2>&1; then
            run_step "spcbios" bash -c "
                cd '$ROOT_DIR/spcbios'
                [[ '$DO_CLEAN' -eq 1 ]] && make clean
                make
            "
        else
            skip_step "spcbios" "hex2bin 미설치 (sdcc IHEX->BIN 변환 도구 필요)"
        fi
    else
        skip_step "spcbios" "sdcc / sdasz80 미설치"
    fi

    if command -v mkfs.cpm >/dev/null 2>&1 && command -v cpmcp >/dev/null 2>&1; then
        run_step "cpm" bash -c "
            cd '$ROOT_DIR/cpm'
            Z80ASM_BIN='$ROOT_DIR/z80/z80asm/z80asm'
            [[ -x \"\$Z80ASM_BIN\" ]] || Z80ASM_BIN='$ROOT_DIR/baremetal/bin/z80asm'
            make ASM=\"\$Z80ASM_BIN\" cpm.bin boot.bin bios.bin
        "
    else
        skip_step "cpm" "cpmtools(mkfs.cpm, cpmcp) 미설치"
    fi
fi

# ============================================================
# 6. Raspberry Pi 1 / Zero Bare-metal (rpi1)
# ============================================================
if want_group "rpi1"; then
    if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
        mkdir -p "$DIST_DIR/rpi1"

        run_step "circle-rpi1" build_circle 1

        run_step "baremetal-rpi1" bash -c "
            cd '$ROOT_DIR/baremetal'
            [[ '$DO_CLEAN' -eq 1 ]] && make CIRCLEHOME='$ROOT_DIR/circle' clean
            make CIRCLEHOME='$ROOT_DIR/circle' RASPPI=1 -j'$JOBS'
            cp -f kernel.img '$DIST_DIR/rpi1/baremetal_kernel.img'
        "

        run_step "spcbox_bm-rpi1" bash -c "
            cd '$ROOT_DIR/spcbox_bm'
            [[ '$DO_CLEAN' -eq 1 ]] && make clean
            make -j'$JOBS'
            cp -f kernel.img '$DIST_DIR/rpi1/spcbox_bm_kernel.img'
        "

        if [[ "$WITH_LEGACY" -eq 1 ]]; then
            run_step "spc1000_circle-rpi1" bash -c "
                cd '$ROOT_DIR/spc1000_circle'
                [[ '$DO_CLEAN' -eq 1 ]] && make clean
                make -j'$JOBS'
            " || true
            run_step "rpibox-rpi1" bash -c "
                cd '$ROOT_DIR/rpibox'
                [[ '$DO_CLEAN' -eq 1 ]] && make clean
                make -j'$JOBS'
            " || true
        fi
    else
        skip_step "rpi1" "arm-none-eabi-gcc 미설치"
    fi
fi

# ============================================================
# 7. Raspberry Pi 4 Model B Bare-metal (rpi4)
# ============================================================
if want_group "rpi4"; then
    if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
        mkdir -p "$DIST_DIR/rpi4"

        run_step "circle-rpi4" build_circle 4

        run_step "baremetal_rpi4" bash -c "
            cd '$ROOT_DIR/baremetal_rpi4'
            [[ '$DO_CLEAN' -eq 1 ]] && make clean-all
            make CIRCLEHOME='$ROOT_DIR/circle' -j'$JOBS'
            make CIRCLEHOME='$ROOT_DIR/circle' dist
            cp -rf dist/* '$DIST_DIR/rpi4/'
        "
    else
        skip_step "rpi4" "arm-none-eabi-gcc 미설치"
    fi
fi

# ============================================================
# 8. 빌드 결과 요약
# ============================================================
echo ""
echo "============================================================"
echo "일괄 빌드 요약"
echo "============================================================"
echo "성공 (${#PASS_LIST[@]}):"
for item in "${PASS_LIST[@]}"; do
    echo "  [PASS] $item"
done

if [[ "${#SKIP_LIST[@]}" -gt 0 ]]; then
    echo "건너뜀 (${#SKIP_LIST[@]}):"
    for item in "${SKIP_LIST[@]}"; do
        echo "  [SKIP] $item"
    done
fi

if [[ "${#FAIL_LIST[@]}" -gt 0 ]]; then
    echo "실패 (${#FAIL_LIST[@]}):"
    for item in "${FAIL_LIST[@]}"; do
        echo "  [FAIL] $item"
    done
    echo ""
    echo "결과물 위치: $DIST_DIR"
    exit 1
fi

echo ""
echo "모든 선택된 빌드가 완료되었습니다. 결과물 요약: $DIST_DIR"
find "$DIST_DIR" -maxdepth 2 -type f | sort | xargs -r ls -lh
