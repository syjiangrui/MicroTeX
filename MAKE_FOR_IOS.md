# iOS Build 指南

本文描述了如何为 iOS 平台编译 MicroTeX 工程。

---

## 环境准备

### 1. 获取 iOS CMake Toolchain

前往 [leetal/ios-cmake](https://github.com/leetal/ios-cmake) 下载 `ios.toolchain.cmake` 工具链，并解压保存到指定目录。  
建议同步 clone 下来以便后续跟踪最新支持。

### 2. 环境变量配置

提前设置以下环境变量，方便命令调用（可写入 `~/.bash_profile` 或 `~/.zshrc` 等）。

```bash
export BUILD_DIR=/path/to/ios-cmake/build/microtex-ios
export TOOLCHAIN_FILE=/path/to/ios-cmake/ios.toolchain.cmake
export IOS_PLATFORM="OS64"               # 参考：https://github.com/leetal/ios-cmake#user-content-platform-choices
export SOURCE_DIR=/path/to/MicroTeX
```

**说明**  
- `BUILD_DIR`：自行定义构建目录
- `TOOLCHAIN_FILE`：`ios-cmake` 的 toolchain 路径
- `IOS_PLATFORM`：常用参数有 OS64 (真机), SIMULATOR64 (模拟器) 等
- `SOURCE_DIR`：源码目录
- `INSTALL_DIR`：安装输出路径

---

## CMake 构建流程

### 1. 生成 Xcode 工程

切换到 `$BUILD_DIR`，执行：

```bash
mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}"

cmake \
    -S "${SOURCE_DIR}" \
    -B . \
    -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    -DPLATFORM=${IOS_PLATFORM} \
    -DIOS_CG=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC=ON \
    -DMICROTEX_BUILD_IOS_FRAMEWORK=OFF \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET="12.0"
```

**参数说明**

- `-G Xcode` 指定生成 Xcode 工程，Mac/iOS 常用
- `IOS_CG=ON` 开启 CoreGraphics 支持
- `BUILD_SHARED_LIBS=OFF` 禁用动态库生成
- `BUILD_STATIC=ON` 启用静态库构建
- `MICROTEX_BUILD_IOS_FRAMEWORK=OFF` 不生成 iOS framework，如有需求可改为 ON
- `CMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET` 设定最低支持 iOS 版本

### 2. 编译项目

生成工程后编译 Release 版本：

```bash
cmake --build . --config Release
```

---

## 常见问题

- **xcodebuild 找不到头文件**  
  检查 `TOOLCHAIN_FILE`, `SOURCE_DIR` 路径设置无误，以及 iOS 版本选择（OS64, SIMULATOR64）。
- **如何同时编译真机与模拟器？**  
  可分别设置 `IOS_PLATFORM`（OS64、SIMULATOR64），构建多套输出后，结合 `lipo`/`xcodebuild -create-xcframework` 生成 xcframework。

---

## 参考文档

- [ios-cmake Github](https://github.com/leetal/ios-cmake)
- [CMake 官方文档](https://cmake.org/documentation/)
- [Xcode 官方帮助](https://developer.apple.com/xcode/)

---

**Tips**  
所有路径建议用绝对路径，避免找不到路径问题。  
如需定制参数，请参考相关工程 CMakeLists.txt 内注释。

---

如需进一步完善或添加平台适配说明，请补充相关内容。

---
