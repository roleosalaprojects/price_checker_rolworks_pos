# apex_fingerprint: the fingerprint reader program (libfprint + NIST bozorth3).
# Built from linux/CMakeLists.txt when libfprint-2-dev and libjson-glib-dev are
# installed, and installed next to apex_pos in the bundle. Also builds alone:
#   cmake -S native/apex_fingerprint -B build/apex_fingerprint && cmake --build build/apex_fingerprint
cmake_minimum_required(VERSION 3.13)
project(apex_fingerprint LANGUAGES C)

find_package(PkgConfig REQUIRED)
pkg_check_modules(APEX_FP_DEPS REQUIRED IMPORTED_TARGET libfprint-2 json-glib-1.0 glib-2.0 gio-2.0)

# NIST NBIS bozorth3 (public domain), as libfprint vendors it.
add_library(apex_bozorth3 STATIC
  third_party/nbis/bozorth3/bozorth3.c
  third_party/nbis/bozorth3/bz_alloc.c
  third_party/nbis/bozorth3/bz_drvrs.c
  third_party/nbis/bozorth3/bz_gbls.c
  third_party/nbis/bozorth3/bz_io.c
  third_party/nbis/bozorth3/bz_sort.c)
target_include_directories(apex_bozorth3 PUBLIC third_party/nbis/include)
target_compile_options(apex_bozorth3 PRIVATE -w)
target_link_libraries(apex_bozorth3 PUBLIC m)

add_executable(apex_fingerprint src/main.c src/prints.c)
target_compile_options(apex_fingerprint PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_compile_definitions(apex_fingerprint PRIVATE G_LOG_DOMAIN="apex_fingerprint")
target_link_libraries(apex_fingerprint PRIVATE apex_bozorth3 PkgConfig::APEX_FP_DEPS)
