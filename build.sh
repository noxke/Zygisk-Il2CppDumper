#!/bin/bash

# ===== 基础配置 =====
ANDROID_NDK=$ANDROID_NDK
BUILD_TYPE="Debug"
ABI_LIST=("arm64-v8a")
MIN_SDK=24
MODULE_NAME="Il2CppDumper"
MODULE_VERSION="v1.2.0"

# ===== 目录配置 =====
PROJECT_ROOT=$(pwd)
BUILD_DIR="$PROJECT_ROOT/build"
OUT_DIR="$PROJECT_ROOT/out"
MAGISK_TEMPLATE="$PROJECT_ROOT/template/magisk_module"
GAME_PACKAGE_NAME="com.example.game"

# ===== 清理历史构建 =====
rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# ===== 编译函数 =====
compile_for_abi() {
    local abi=$1
    local build_dir="$BUILD_DIR/$abi"
    
    echo "编译 $abi 架构..."
    mkdir -p "$build_dir"
    
    # CMake 配置
    cmake module/src/main/cpp \
        -B "$build_dir" \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$abi" \
        -DANDROID_PLATFORM="android-$MIN_SDK" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DMODULE_NAME="$MODULE_NAME" \
        -DGAME_NAME_PACKAGE="$GAME_PACKAGE_NAME"
    
    # 编译
    cmake --build "$build_dir" -j$(nproc)
    
    # 复制生成的库文件
    local lib_file=$(find "$build_dir" -name "lib$MODULE_NAME.so")
    [ -f "$lib_file" ] && cp "$lib_file" "$OUT_DIR/libs/$abi.so"
}

# ===== 编译所有 ABI =====
mkdir -p "$OUT_DIR/libs"
for abi in "${ABI_LIST[@]}"; do
    compile_for_abi "$abi"
done

# ===== 准备 Magisk 模块 =====
prepare_magisk_module() {
    local magisk_dir="$OUT_DIR/magisk_module"
    mkdir -p "$magisk_dir"
    
    # 复制模板文件
    cp -r "$MAGISK_TEMPLATE/." "$magisk_dir/"
    rm -f "$magisk_dir/module.prop"
    
    # 生成 module.prop
    cat > "$magisk_dir/module.prop" <<EOF
id=zygisk_il2cppdumper
name=$MODULE_NAME
version=$MODULE_VERSION
versionCode=1
author=YourName
author=Perfare
description=($GAME_PACKAGE_NAME) Il2CppDumper Zygisk version.
EOF
    
    # 处理库文件
    mkdir -p "$magisk_dir/zygisk"
    for abi in "${ABI_LIST[@]}"; do
        local src_lib="$OUT_DIR/libs/$abi.so"
        [ -f "$src_lib" ] && cp "$src_lib" "$magisk_dir/zygisk/"
    done
}

# ===== 打包模块 =====
prepare_magisk_module
ZIP_NAME="${MODULE_NAME}-${GAME_PACKAGE_NAME}.zip"
(cd "$OUT_DIR/magisk_module" && zip -r "../$ZIP_NAME" .)

echo "======================================"
echo "编译完成! Magisk 模块已输出到: $OUT_DIR/$ZIP_NAME"
echo "支持的 ABI: ${ABI_LIST[@]}"
