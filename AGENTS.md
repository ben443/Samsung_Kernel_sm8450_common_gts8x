# AGENTS.md

## Purpose
This repository is a Samsung SM8450 (Galaxy Tab S8 series) kernel tree. Use this file as the baseline operating guide for coding agents making changes here.

## Scope And Safety
- Make surgical changes only for the requested task.
- Do not modify unrelated drivers/subsystems just to "clean up" code.
- Never commit secrets, tokens, private keys, or local machine paths.
- Do not break existing defconfig-based builds.

## Branch/Target Context
- Common device targets:
  - `gts8wifi` -> `gts8wifi-waipio_defconfig`
  - `gts8uwifi` -> `gts8uwifi-waipio_defconfig`
- Root build script: `build.sh`
- Primary kernel output directory: `out/`

## Environment Expectations
- Linux host with kernel build dependencies (`bc`, `bison`, `flex`, `libssl-dev`, `libelf-dev`, `libncurses-dev`, `pahole/dwarves`, `clang`, `lld`, `zip`, etc.).
- Clang toolchain available either:
  - At `TOOLCHAIN_DIR/CLANG_VERSION` (see `build.sh` defaults), or
  - In `PATH` (the script falls back to system `clang`).

## Preferred Build Paths
Use the smallest valid build for the files you touched.

1. Quick sanity build with project script:
```bash
./build.sh
```

2. Manual kernel build (matches CI style, useful for debugging):
```bash
make O=out ARCH=arm64 gki_defconfig
make O=out ARCH=arm64 olddefconfig
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
  Image modules dtbs
```

3. Device-specific config build example:
```bash
make O=out ARCH=arm64 gts8wifi-waipio_defconfig
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang Image dtbs
```

## Validation Expectations
- Run at least one relevant build path for changed code.
- For patch style checks, use:
```bash
scripts/checkpatch.pl --strict -f <changed_file>
```
- If you modify config/defconfig or build scripts, prefer a full `./build.sh` validation.

## Patch And Commit Conventions
Follow the Android common kernel conventions captured in `README.md`:
- Subject tags when applicable: `UPSTREAM:`, `BACKPORT:`, `FROMGIT:`, `FROMLIST:`, `ANDROID:`.
- Include required metadata where applicable (`Change-Id:`, `Signed-off-by:`, `Bug:`, `Fixes:`, `Link:`).
- Keep commit messages explicit about why the patch is needed.

## File-Specific Guidance
- Defconfigs live under `arch/arm64/configs/`.
- Device trees are under `arch/arm64/boot/dts/`.
- Packaging output for flashable zips is handled through `AnyKernel3/` by `build.sh`.
- Do not enable conflicting root integration toggles simultaneously (`ENABLE_KSU_NEXT`, `ENABLE_SUKISU`, `ENABLE_KSU`) unless the task explicitly requires it.

## Practical Agent Workflow
1. Read `README.md` and `build.sh` before editing.
2. Change only required files.
3. Build/test the smallest relevant target.
4. Re-check diffs for accidental edits.
5. Ensure no secrets are introduced.
