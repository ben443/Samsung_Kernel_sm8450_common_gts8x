#!/bin/bash
set -Eeuo pipefail

# Static constants
BUILD_START=$(date +"%s")
blue='\033[1;94m'
yellow='\033[1;33m'
nocol='\033[0m'
green='\033[1;32m'
red='\033[1;31m'
KERNELDIR=$PWD
trap 'error_handler $LINENO' ERR

echo -e " $yellow #####|                 Kernel Build Script                  |########$nocol "
echo -e " $yellow #####|     Choose Correct options as required when asked    |##########$nocol "
echo -e " $yellow #####| To use specific AOSP clang version, edit this script |######$nocol "
echo -e " $yellow #####|   and specify correct clang version and install dir  |#####$nocol "
echo -e " $yellow #####|   Configure PATCH_SUSFS, ENABLE_KSU[_NEXT], etc. at  |########$nocol "
echo -e " $yellow #####|       top of the script to enable KernelSU patches   |######### $nocol"
echo  # Blank line
echo  # Blank line

# -------------------------------- | Dependencies |--------------------------------------------------------------#
# Uncomment Next 4 lines to install all necessary dependencies for kernel Compiling.

#sudo apt-get update && sudo apt-get install -y \
#  build-essential libncurses-dev bison flex libssl-dev libelf-dev bc \
#  dwarves fakeroot git clang llvm lld lldb \
#  gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi patch

# ---------------------------------------------------------------------------------------------------------------- #
# ---------------------------| EXPORTS and Directory Setup |------------------------------------------------------ #
BUILD_TARGET=gts8wifi_eur_open
KERNEL_DEFCONFIG=${BUILD_TARGET%%_*}-waipio_defconfig  # Looks for defconfig in arch/<exported_arch>/configs/
ANYKERNEL3_DIR=$PWD/AnyKernel3/ # Required by the function zip_kernel
AK3_REPO="https://github.com/akm-04/AnyKernel3.git"
AK3_BRANCH="gts8u"
MODULES_NAME="Kernel_Modules-Magisk"


# Setup the main directory where build tools are located / will be cloned
# Directory structure under $TOOLCHAIN_DIR:
#
# $TOOLCHAIN_DIR/
# ├── clang-<version>/       # e.g. clang-r547379
# │   └── bin/
# │       └── clang
# ├── gas/
# │   └── linux-x86/          # prebuilt GNU assembler
# └── build-tools/
#     └── path/
#         └── linux-x86/      # Android SDK build-tools
#
TOOLCHAIN_DIR="$HOME/Git/Clang"

# Clang version Setup
CLANG_VERSION=clang-r416183c1
CLANG_DIR="$TOOLCHAIN_DIR/$CLANG_VERSION"
CLANG_BINARY="$CLANG_DIR/bin/clang"

# An array that stores all make command, edit it as required. These options will be used throughout the script
MAKE_FLAGS=( \
  O=out \
  CC=clang \
  LD=ld.lld \
  LLVM=1 \
  LLVM_IAS=1 \
)
