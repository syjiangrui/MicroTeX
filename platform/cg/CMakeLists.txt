# platform/cg/CMakeLists.txt

message(STATUS "Setting up iOS Core Graphics backend")

option(MICROTEX_BUILD_IOS_FRAMEWORK "Build microtex-cg as an iOS Framework" OFF)

# --- Library Definition ---
if(MICROTEX_BUILD_IOS_FRAMEWORK)
    # Frameworks are typically dynamic, but can be static now too.
    # Let BUILD_SHARED_LIBS control dynamic/static for the framework binary.
    add_library(microtex-cg graphic_cg.mm)
    set(_is_framework TRUE)
    message(STATUS "Building microtex-cg as a Framework")
else()
    # Default to static library if not building a framework
    # Type (STATIC/SHARED) controlled by global BUILD_SHARED_LIBS or BUILD_STATIC
    add_library(microtex-cg graphic_cg.mm)
    set(_is_framework FALSE)
    message(STATUS "Building microtex-cg as a Library (Type determined by BUILD_SHARED_LIBS/BUILD_STATIC)")
endif()

# --- Target Properties ---
# Use PROJECT_VERSION from root CMakeLists.txt
# Use MICROTEX_API_VERSION from root CMakeLists.txt
set_target_properties(
    microtex-cg PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${MICROTEX_API_VERSION} # Used for SONAME on Unix-like, good practice
    OUTPUT_NAME "MicroTeX_CG"          # Set a nice output name (e.g., libMicroTeX_CG.a)
    DEFINE_SYMBOL "MICROTEX_CG_BUILD" # Internal build definition if needed
    # Visibility presets help reduce library size, especially for shared libs/frameworks
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
    # Ensure ObjC++ compilation for .mm file if CMake needs hint
    XCODE_ATTRIBUTE_GCC_COMPILE_SOURCES_AS "Objective-C++"
)

if(_is_framework)
   set_target_properties(microtex-cg PROPERTIES FRAMEWORK TRUE)
   # Public headers for the framework (only the interface header)
    set_target_properties(microtex-cg PROPERTIES
        PUBLIC_HEADER "graphic_cg.h"
        # Set framework-specific paths (adjust if needed)
        FRAMEWORK_INSTALL_PREFIX "Library/Frameworks"
        XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_LIBRARY_DIR)/Frameworks"
        XCODE_ATTRIBUTE_DEFINES_MODULE YES # If you plan Swift interop
    )
endif()

# --- System Check ---
# if(NOT CMAKE_SYSTEM_NAME MATCHES "iOS")
#    message(WARNING "Building microtex-cg backend, but the target system is not iOS (${CMAKE_SYSTEM_NAME}). This may not link correctly.")
#    # Consider FATAL_ERROR if strictly iOS-only
# endif()

# --- Find iOS Framework Dependencies ---
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
find_library(CORETEXT_FRAMEWORK CoreText REQUIRED)
find_library(UIKIT_FRAMEWORK UIKit REQUIRED) # Needed for UIFont, maybe colorspace

message(STATUS "Found Foundation: ${FOUNDATION_FRAMEWORK}")
message(STATUS "Found CoreGraphics: ${COREGRAPHICS_FRAMEWORK}")
message(STATUS "Found CoreText: ${CORETEXT_FRAMEWORK}")
message(STATUS "Found UIKit: ${UIKIT_FRAMEWORK}")

# --- Linking ---
target_link_libraries(microtex-cg
    PUBLIC # Headers expose CG/CT types, so dependencies must be PUBLIC
        "${FOUNDATION_FRAMEWORK}"
        "${COREGRAPHICS_FRAMEWORK}"
        "${CORETEXT_FRAMEWORK}"
        "${UIKIT_FRAMEWORK}"
    PRIVATE
        microtex # Link against the core microtex library
)

# --- Include Directories ---
target_include_directories(
    microtex-cg PUBLIC
    # For projects using this target via add_subdirectory: Export current source dir path
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    # For installed package: Export path relative to install prefix
    $<INSTALL_INTERFACE:include/microtex-cg> # path relative to CMAKE_INSTALL_PREFIX
)

# --- Compile Definitions for Export ---
# If building a shared library/framework AND using MICROTEX_EXPORT macros in graphic_cg.h
if(BUILD_SHARED_LIBS OR _is_framework)
    target_compile_definitions(microtex-cg PRIVATE -DMICROTEX_LIBRARY)
endif()
# Add definition specific to this backend for conditional compilation in .mm file
target_compile_definitions(microtex-cg PRIVATE -DBUILD_IOS_CG)

# --- Installation ---
# Use helper functions from root MicroTeXInstall.cmake (assumed)
# Install the library/framework target itself
microtex_install_target(microtex-cg)

# Install the public header file
# If building a framework, this header is usually bundled within the framework structure automatically
# But we might still want to install it to a standard include dir for non-framework usage
# The FRAMEWORK TRUE property handles bundling, this installs to include/microtex-cg
microtex_install_headers(microtex-cg HEADERS graphic_cg.h)

# Install the CMake config files for find_package()
# This generates microtex-cgConfig.cmake and microtex-cgTargets.cmake
install(EXPORT microtex-cgTargets
    FILE microtex-cgTargets.cmake
    NAMESPACE microtex:: # Use a namespace for targets (e.g., microtex::microtex-cg)
    DESTINATION lib/cmake/microtex-cg
)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/microtex-cgConfig.cmake"
    DESTINATION lib/cmake/microtex-cg
)

# Generate the config file from the template
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/microtex-cgConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/microtex-cgConfig.cmake"
    @ONLY # Replace only @VAR@ variables
)