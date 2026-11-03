# AtomVM for the Tang Primer 25K LiteX SoC: AtomVM's Zephyr port (src/platforms/zephyr of the
# pinned checkout, plus patches/atomvm) with this board's configuration and AVM pack loader.
cmake_minimum_required(VERSION 3.20)
set(CMAKE_C_STANDARD_REQUIRED YES)
set(CMAKE_C_EXTENSIONS NO)
set_property(GLOBAL PROPERTY CSTD iso9899:2011)

if(NOT DEFINED ATOMVM_DIR)
    set(ATOMVM_DIR $ENV{ATOMVM_DIR})
endif()
set(ATOMVM_ZEPHYR_ROOT ${ATOMVM_DIR}/src/platforms/zephyr)

set(CONF_FILE ${ATOMVM_ZEPHYR_ROOT}/prj.conf ${CMAKE_CURRENT_LIST_DIR}/prj.conf)

# Run precompiled riscv32 code from the packs (patches/atomvm/0004); BEAM-only modules still
# run on the emulator. The riscv32 precompile target uses double-precision floats.
set(AVM_ZEPHYR_PRECOMPILED ON CACHE BOOL "" FORCE)
set(AVM_USE_32BIT_FLOAT OFF CACHE BOOL "" FORCE)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(AtomVM LANGUAGES C)

include(${ATOMVM_ZEPHYR_ROOT}/cmake/AtomVMZephyrApp.cmake)

target_sources(app PRIVATE src/avm_loader.c)

# NIFs added by a repository that extends this one (REGISTER_NIF_COLLECTION in their sources)
if(DEFINED AVM_EXTRA_SOURCES)
    target_sources(app PRIVATE ${AVM_EXTRA_SOURCES})
endif()
