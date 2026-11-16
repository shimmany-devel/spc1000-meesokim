#!/usr/bin/env bash
# install_deps.sh - 클린 WSL / Ubuntu / Debian 환경에서 spc1000-miso 전체 빌드 도구를 설치하는 스크립트
# 기설치 도구(gcc, cmake, git, libsdl2-dev 등)를 포함하여 멱등적으로 설치합니다.

set -euo pipefail

APT_ONLY=0
SKIP_EMSDK=0
SKIP_MINGW_SDL2=0
SDL2_MINGW_VER="${SDL2_MINGW_VER:-2.30.11}"
EMSDK_DIR="${EMSDK_DIR:-$HOME/emsdk}"

usage() {
    cat <<EOF
사용법: $0 [옵션]

옵션:
  --apt-only         apt 시스템 패키지만 설치 (MinGW SDL2, emsdk 제외)
  --skip-emsdk       Emscripten SDK(~/emsdk) 설치 건너뛰기
  --skip-mingw-sdl2  MinGW32 SDL2 개발 라이브러리 설치 건너뛰기
  -h, --help         도움말 출력
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apt-only)
            APT_ONLY=1
            SKIP_EMSDK=1
            SKIP_MINGW_SDL2=1
            shift
            ;;
        --skip-emsdk)
            SKIP_EMSDK=1
            shift
            ;;
        --skip-mingw-sdl2)
            SKIP_MINGW_SDL2=1
            shift
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

if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "오류: 이 스크립트는 Ubuntu/Debian(apt-get) 계열 리눅스 및 WSL 전용입니다." >&2
    exit 1
fi

echo "============================================================"
echo "[1/3] apt 시스템 패키지 및 크로스 툴체인 설치 (기설치 항목 포함)"
echo "============================================================"

APT_PACKAGES=(
    # 기본 빌드 도구 및 유틸리티
    build-essential
    cmake
    pkg-config
    git
    wget
    curl
    unzip
    ca-certificates
    python3
    python3-pip
    python3-venv

    # 시스템 개발 라이브러리
    libbz2-dev
    zlib1g-dev
    libncurses-dev
    libfreetype-dev
    libusb-1.0-0-dev
    libboost-all-dev

    # SDL2 & 애드온 (sdl2, baremetal host, sdl-wasm)
    libsdl2-dev
    libsdl2-ttf-dev
    libsdl2-image-dev
    libsdl2-mixer-dev

    # SDL1.2 & Guichan (spcemul)
    libsdl1.2-dev
    libsdl-image1.2-dev
    libsdl-ttf2.0-dev
    libguichan-dev

    # Raspberry Pi Bare-metal ARM 툴체인 (circle, baremetal, baremetal_rpi4, spcbox_bm 등)
    gcc-arm-none-eabi
    binutils-arm-none-eabi
    libnewlib-arm-none-eabi

    # Windows 크로스 컴파일러 (baremetal/Makefile.windows, spcemul)
    mingw-w64

    # Z80 / BIOS / CP/M / 부팅 에뮬레이션 / OCR 보조 도구
    sdcc
    cpmtools
    qemu-system-x86
    tesseract-ocr
)

$SUDO apt-get update
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"

if [[ "$SKIP_MINGW_SDL2" -eq 0 ]]; then
    echo "============================================================"
    echo "[2/3] MinGW32용 SDL2 개발 라이브러리 설치 (/usr/i686-w64-mingw32)"
    echo "============================================================"
    if [[ -f /usr/i686-w64-mingw32/include/SDL2/SDL.h ]] && [[ -f /usr/i686-w64-mingw32/lib/libSDL2.a ]]; then
        echo "이미 설치됨: /usr/i686-w64-mingw32/include/SDL2/SDL.h"
    else
        TMP_DIR="$(mktemp -d)"
        trap 'rm -rf "$TMP_DIR"' EXIT
        SDL2_MINGW_URL="https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_MINGW_VER}/SDL2-devel-${SDL2_MINGW_VER}-mingw.tar.gz"
        echo "다운로드 중: $SDL2_MINGW_URL"
        curl -fSL "$SDL2_MINGW_URL" -o "$TMP_DIR/sdl2-mingw.tar.gz"
        tar -xzf "$TMP_DIR/sdl2-mingw.tar.gz" -C "$TMP_DIR"
        MINGW_SRC="$TMP_DIR/SDL2-${SDL2_MINGW_VER}/i686-w64-mingw32"
        if [[ ! -d "$MINGW_SRC" ]]; then
            echo "오류: 압축 해제된 경로에서 $MINGW_SRC 를 찾을 수 없습니다." >&2
            exit 1
        fi
        $SUDO mkdir -p /usr/i686-w64-mingw32/include /usr/i686-w64-mingw32/lib /usr/i686-w64-mingw32/bin
        $SUDO cp -r "$MINGW_SRC/include/SDL2" /usr/i686-w64-mingw32/include/
        $SUDO cp -r "$MINGW_SRC/lib/"* /usr/i686-w64-mingw32/lib/
        $SUDO cp -r "$MINGW_SRC/bin/"* /usr/i686-w64-mingw32/bin/
        rm -rf "$TMP_DIR"
        trap - EXIT
        echo "설치 완료: /usr/i686-w64-mingw32"
    fi
else
    echo "[2/3] MinGW32용 SDL2 설치 건너뜀 (--skip-mingw-sdl2)"
fi

if [[ "$SKIP_EMSDK" -eq 0 ]]; then
    echo "============================================================"
    echo "[3/3] Emscripten SDK 설치 ($EMSDK_DIR)"
    echo "============================================================"
    if [[ -f "$EMSDK_DIR/emsdk_env.sh" ]]; then
        echo "이미 설치됨: $EMSDK_DIR"
    else
        git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
        (
            cd "$EMSDK_DIR"
            ./emsdk install latest
            ./emsdk activate latest
        )
    fi
else
    echo "[3/3] Emscripten SDK 설치 건너뜀 (--skip-emsdk)"
fi

echo "============================================================"
echo "도구 설치 완료! 설치 요약:"
echo "============================================================"
for cmd in gcc g++ cmake make pkg-config sdl2-config sdl-config arm-none-eabi-gcc i686-w64-mingw32-g++ sdcc mkfs.cpm qemu-system-x86_64 tesseract; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "  [OK] %-24s -> %s\n" "$cmd" "$(command -v "$cmd")"
    else
        printf "  [NO] %-24s\n" "$cmd"
    fi
done
if [[ -f "$EMSDK_DIR/emsdk_env.sh" ]]; then
    echo "  [OK] emsdk                    -> $EMSDK_DIR"
fi
echo ""
echo "다음 단계: ./build_all.sh 를 실행하여 전체 또는 원하는 타겟을 직접 빌드하세요."
