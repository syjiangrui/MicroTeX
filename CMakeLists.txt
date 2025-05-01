# Root CMakeLists.txt

cmake_minimum_required(VERSION 3.16)

# Set iOS specific variables *before* project() if cross-compiling
# e.g., when using CMake toolchain file for iOS
# if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
#   set(CMAKE_MACOSX_BUNDLE TRUE) # Might be needed for examples
#   set(CMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum iOS deployment target")
# endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

project(
    microtex
    VERSION 1.0.0
    DESCRIPTION "A micro, fast, cross-platform, and embeddable LaTeX rendering library"
)

# the API (and ABI) is compatible when MICROTEX_API_VERSION is the same
set(MICROTEX_API_VERSION 1)

# Store version info for microtex-cgConfig.cmake.in
set(microtex_VERSION ${PROJECT_VERSION})

if (MSVC) # MSVC Compat
    add_compile_options("/utf-8")
    # make binaries together
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
endif ()

####################
#  compile option  #
####################

# --- Platform Backends ---
option(CAIRO "Build with CAIRO" OFF)
option(GTK "Build with GTK (requires CAIRO)" OFF)
option(QT "Build with Qt" OFF)
option(SKIA "Build with Skia" OFF) # Added SKIA option based on your files
option(GDI "Build with GDI (Windows)" OFF)
option(WASM "Build with WASM" OFF) # Added WASM option based on your files
option(IOS_CG "Build with iOS Core Graphics" OFF) # <-- NEW IOS Option

# --- Examples (should depend on backend options) ---
option(BUILD_EXAMPLE_GTK "Build GTKCairo example (requires GTK)" OFF)
option(BUILD_EXAMPLE_GTKMM "Build GTKMM example (requires CAIRO)" OFF)
option(BUILD_EXAMPLE_QT "Build Qt example (requires QT)" OFF)
option(BUILD_EXAMPLE_QTPNG "Build Qt png example (requires QT)" OFF)
option(BUILD_EXAMPLE_WIN32 "Build Win32 GDI example (requires GDI)" OFF)
option(BUILD_EXAMPLE_MEMCHECK "Build memory check example" OFF)
# option(BUILD_EXAMPLE_IOS_CG "Build iOS CG example (requires IOS_CG)" OFF) # Add if you create an iOS example

# --- Other Build Options ---
option(HAVE_LOG "Enable internal logging" ON)
if (HAVE_LOG)
    add_definitions(-DHAVE_LOG)
endif ()

option(BUILD_SHARED_LIBS "Build shared libraries (.so/.dll/.dylib) instead of static (.a/.lib)" OFF)
option(BUILD_STATIC "Build static libraries (.a/.lib)" OFF) # Alternative way to control static builds

# Logic for BUILD_STATIC overriding BUILD_SHARED_LIBS if both used
if(BUILD_STATIC)
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)
endif()

# --- Installation Helper ---
include(MicroTeXInstall.cmake) # Assumed to exist
include(CMakePackageConfigHelpers) # For config file generation

# --- Core Library ---
add_subdirectory(lib)

# --- Resource Copying (Consider if needed at root level) ---
# file(COPY res DESTINATION .) # Might be better handled by examples or install steps

#####################
# optional features #
#####################
if (CAIRO)
    add_subdirectory(platform/cairo)
    if (BUILD_EXAMPLE_GTKMM)
        add_subdirectory(example/gtkmm)
    endif ()
endif ()

if (GTK)
    if(NOT CAIRO)
        message(FATAL_ERROR "The GTK backend requires CAIRO to be enabled (-DCAIRO=ON)")
    endif()
    add_subdirectory(platform/gtk)
    if (BUILD_EXAMPLE_GTK)
        # Check if example/gtk exists before adding
        if(IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/example/gtk)
            add_subdirectory(example/gtk)
        else()
            message(WARNING "GTK example requested but directory example/gtk not found.")
        endif()
    endif ()
endif ()

if (QT)
    add_subdirectory(platform/qt)
    if (BUILD_EXAMPLE_QT)
        add_subdirectory(example/qt)
    endif ()
    if (BUILD_EXAMPLE_QTPNG)
        add_subdirectory(example/qtpng)
    endif ()
endif ()

if (SKIA)
    add_subdirectory(platform/skia)
    # Add Skia example if applicable
endif ()

if (IOS_CG) # <-- NEW Block for iOS
    add_subdirectory(platform/cg)
    # Add iOS example if you create one
    # if (BUILD_EXAMPLE_IOS_CG)
    #    add_subdirectory(example/ios_cg)
    # endif()
endif()

if (GDI)
    add_subdirectory(platform/gdi_win)
    if (BUILD_EXAMPLE_WIN32)
        add_subdirectory(example/win32)
    endif ()
endif ()

if (WASM)
    add_subdirectory(platform/wasm)
    # Add WASM example if applicable
endif ()

if (BUILD_EXAMPLE_MEMCHECK)
    add_subdirectory(example/memcheck)
endif ()

################
# installation #
################

# install resources
install(DIRECTORY res/ DESTINATION share/microtex)

# install prebuilt scripts (If these are python/shell and useful on iOS?)
# Consider if these should be installed when targeting iOS
install(FILES prebuilt/otf2clm.py DESTINATION bin)
install(PROGRAMS prebuilt/otf2clm.sh DESTINATION bin RENAME otf2clm)

message(STATUS "MicroTeX root configuration finished.")