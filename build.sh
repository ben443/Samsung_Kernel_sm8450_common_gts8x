#!/bin/bash
set -Eeuo pipefail

BUILD_START=$(date +%s)
KERNEL_DIR=$(pwd)
OUT_DIR=${OUT_DIR:-out}
ARCH=${ARCH:-arm64}
SUBARCH=${SUBARCH:-arm64}

BUILD_TARGET=${CI_BUILD_TARGET:-${BUILD_TARGET:-gts8wifi_eur_open}}
DEVICE=${BUILD_TARGET%%_*}
KERNEL_DEFCONFIG=${CI_KERNEL_DEFCONFIG:-${KERNEL_DEFCONFIG:-${DEVICE}-waipio_defconfig}}

ANYKERNEL3_DIR=${ANYKERNEL3_DIR:-${KERNEL_DIR}/AnyKernel3}
AK3_REPO=${AK3_REPO:-https://github.com/akm-04/AnyKernel3.git}

case "${DEVICE}" in
  gts8wifi)
    DEFAULT_AK3_BRANCH="gts8x"
    ;;
  gts8uwifi)
    DEFAULT_AK3_BRANCH="gts8u"
    ;;
  *)
    echo "Unsupported device '${DEVICE}'. Supported: gts8wifi, gts8uwifi" >&2
    exit 1
    ;;
esac
AK3_BRANCH=${CI_AK3_BRANCH:-${AK3_BRANCH:-${DEFAULT_AK3_BRANCH}}}

TOOLCHAIN_DIR=${CI_TOOLCHAIN_DIR:-${TOOLCHAIN_DIR:-$HOME/Git/Clang}}
CLANG_VERSION=${CLANG_VERSION:-clang-r416183c1}
CLANG_DIR=${CLANG_DIR:-${TOOLCHAIN_DIR}/${CLANG_VERSION}}
CLANG_BINARY=${CLANG_BINARY:-${CLANG_DIR}/bin/clang}

KERNEL_NAME=${CI_KERNEL_NAME:-${KERNEL_NAME:-Samsung-Kernel-${DEVICE}}}
EXTRA_KMAKE_TARGETS=${EXTRA_KMAKE_TARGETS:-"Image dtbs"}
DTBO_PAGE_SIZE=${DTBO_PAGE_SIZE:-4096}

MAKE_FLAGS=(
  O=${OUT_DIR}
  ARCH=${ARCH}
  SUBARCH=${SUBARCH}
  CC=clang
  LD=ld.lld
  LLVM=1
  LLVM_IAS=1
)

# NetHunter-friendly defaults: build the kernel only, without KSU/SUKISU/APatch/SUSFS overlays.
ENABLE_KSU_NEXT=${ENABLE_KSU_NEXT:-0}
ENABLE_SUKISU=${ENABLE_SUKISU:-0}
ENABLE_KSU=${ENABLE_KSU:-0}
ENABLE_APATCH=${ENABLE_APATCH:-0}
PATCH_SUSFS=${PATCH_SUSFS:-0}
PATCH_KPM=${PATCH_KPM:-0}

error_handler() {
  local line="$1"
  echo "Build failed at line ${line}" >&2
}
trap 'error_handler $LINENO' ERR

prepare_anykernel() {
  rm -rf "${ANYKERNEL3_DIR}"
  git clone --depth=1 -b "${AK3_BRANCH}" "${AK3_REPO}" "${ANYKERNEL3_DIR}"
  rm -f "${ANYKERNEL3_DIR}"/*.zip
}

setup_toolchain() {
  if [ -x "${CLANG_BINARY}" ]; then
    export PATH="${CLANG_DIR}/bin:${PATH}"
    return
  fi

  echo "Clang not found at ${CLANG_BINARY}; falling back to PATH clang"
  command -v clang >/dev/null
}

build_kernel() {
  make "${MAKE_FLAGS[@]}" "${KERNEL_DEFCONFIG}"
  make "${MAKE_FLAGS[@]}" -j"$(nproc)" ${EXTRA_KMAKE_TARGETS}
}

build_dtbo_image() {
  local dtbo_path="${OUT_DIR}/arch/arm64/boot/dtbo.img"
  local -a dtbo_files=()
  local mkdtboimg_tool

  while IFS= read -r -d '' dtbo_file; do
    dtbo_files+=("${dtbo_file}")
  done < <(find "${OUT_DIR}/arch/arm64/boot/dts" -type f -name "${BUILD_TARGET}_*.dtbo" -print0)

  if [ "${#dtbo_files[@]}" -eq 0 ]; then
    return
  fi

  mkdtboimg_tool=$(command -v mkdtboimg.py || command -v mkdtboimg || true)
  if [ -z "${mkdtboimg_tool}" ]; then
    echo "Unable to create ${dtbo_path}: mkdtboimg.py not found in PATH" >&2
    exit 1
  fi

  "${mkdtboimg_tool}" create "${dtbo_path}" --page_size="${DTBO_PAGE_SIZE}" "${dtbo_files[@]}"
}

package_anykernel() {
  local image_path="${OUT_DIR}/arch/arm64/boot/Image"
  local dtbo_path="${OUT_DIR}/arch/arm64/boot/dtbo.img"
  local dtb_root="${OUT_DIR}/arch/arm64/boot/dts"

  [ -f "${image_path}" ] || { echo "Missing ${image_path}" >&2; exit 1; }

  cp -f "${image_path}" "${ANYKERNEL3_DIR}/Image"

  if [ -f "${dtbo_path}" ]; then
    cp -f "${dtbo_path}" "${ANYKERNEL3_DIR}/dtbo.img"
  fi

  if [ -d "${dtb_root}/samsung" ]; then
    rm -rf "${ANYKERNEL3_DIR}/dtb"
    mkdir -p "${ANYKERNEL3_DIR}/dtb"
    find "${dtb_root}/samsung" -type f \( -name '*.dtb' -o -name '*.dtbo' \) -print0 | \
      xargs -0r -I{} cp -f "{}" "${ANYKERNEL3_DIR}/dtb/" || true
  fi

  local zip_name
  zip_name="${KERNEL_NAME}-${DEVICE}-$(date +%Y%m%d-%H%M%S).zip"
  (
    cd "${ANYKERNEL3_DIR}"
    zip -r9 "${zip_name}" . -x '*.git*' -x '*.zip'
  )

  echo "Flashable zip generated: ${ANYKERNEL3_DIR}/${zip_name}"
}

main() {
  echo "Building ${DEVICE} with ${KERNEL_DEFCONFIG}"
  echo "AnyKernel3 branch: ${AK3_BRANCH}"

  setup_toolchain
  prepare_anykernel
  build_kernel
  build_dtbo_image
  package_anykernel

  local elapsed=$(( $(date +%s) - BUILD_START ))
  echo "Build completed in ${elapsed}s"
}

main "$@"
