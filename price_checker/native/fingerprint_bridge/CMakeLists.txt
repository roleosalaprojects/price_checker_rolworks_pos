cmake_minimum_required(VERSION 3.16)
project(fingerprint_bridge LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Backend selection. Leave both OFF for the mock build (works everywhere,
# incl. macOS, no hardware/SDK needed).
option(HAVE_DIGITALPERSONA "Build the Windows DigitalPersona U.are.U backend" OFF)
option(HAVE_LIBFPRINT "Build the Linux libfprint backend" OFF)

if(HAVE_DIGITALPERSONA AND HAVE_LIBFPRINT)
  message(FATAL_ERROR "Enable only one hardware backend at a time.")
endif()

# Mock + protocol are always compiled.
set(SOURCES src/main.cpp src/mock_device.cpp)

add_executable(fingerprint_bridge ${SOURCES})
target_include_directories(fingerprint_bridge PRIVATE include src)

if(HAVE_DIGITALPERSONA)
  target_sources(fingerprint_bridge PRIVATE src/digitalpersona_device.cpp)
  target_compile_definitions(fingerprint_bridge PRIVATE HAVE_DIGITALPERSONA)
  # Point these at your U.are.U SDK install.
  set(DP_SDK_DIR "" CACHE PATH "DigitalPersona U.are.U SDK root")
  if(DP_SDK_DIR)
    target_include_directories(fingerprint_bridge PRIVATE "${DP_SDK_DIR}/include")
    target_link_directories(fingerprint_bridge PRIVATE "${DP_SDK_DIR}/lib")
  endif()
  target_link_libraries(fingerprint_bridge PRIVATE dpfpdd dpfj)
endif()

if(HAVE_LIBFPRINT)
  target_sources(fingerprint_bridge PRIVATE src/libfprint_device.cpp)
  target_compile_definitions(fingerprint_bridge PRIVATE HAVE_LIBFPRINT)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(FPRINT REQUIRED libfprint-2 glib-2.0)
  target_include_directories(fingerprint_bridge PRIVATE ${FPRINT_INCLUDE_DIRS})
  target_link_libraries(fingerprint_bridge PRIVATE ${FPRINT_LIBRARIES})
endif()
