# SPDX-FileCopyrightText: 2026
# SPDX-License-Identifier: GPL-2.0-or-later

# Test suite for the EFI Boot KCM.
#
# The vendored qefivar sources are compiled a second time here with the
# EFIVAR_APP_DATA_DUMMY backend enabled. That backend keeps EFI variables in
# QStandardPaths::AppDataLocation instead of /sys/firmware/efi/efivars, so the
# tests are hermetic: no root, no efivarfs and no UEFI firmware required.
#
# The shipped KCM and helper keep using the real efivarfs backend, they are
# unaffected by this.

set(QEFIVAR_DIR ${CMAKE_SOURCE_DIR}/third_party/qefivar)

# The test sources include a generated "<name>.moc" file, so AUTOMOC has to be
# enabled for this directory.
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Test)

add_library(qefivar_dummy STATIC
    ${QEFIVAR_DIR}/qefi.cpp
    ${QEFIVAR_DIR}/qefidpacpi.cpp
    ${QEFIVAR_DIR}/qefidphw.cpp
    ${QEFIVAR_DIR}/qefidpmedia.cpp
    ${QEFIVAR_DIR}/qefidpmessage.cpp
)
target_include_directories(qefivar_dummy PUBLIC ${QEFIVAR_DIR})
target_link_libraries(qefivar_dummy PUBLIC Qt6::Core)
target_compile_definitions(qefivar_dummy PRIVATE QEFI_LIBRARY EFIVAR_APP_DATA_DUMMY)

# The vendored test suite is built here instead of through the submodule's own
# CMakeLists.txt: its sources use "private slots:" and QString(const char *),
# which the strict Qt settings of the KDE compiler flags do not allow. Relaxing
# those two defines for these targets keeps the submodule itself untouched.
file(GLOB _vendored_test_sources ${QEFIVAR_DIR}/tests/test_*.cc)
foreach(_source IN LISTS _vendored_test_sources)
    get_filename_component(_name ${_source} NAME_WE)
    add_executable(${_name} ${_source})
    target_include_directories(${_name} PRIVATE ${QEFIVAR_DIR} ${QEFIVAR_DIR}/tests)
    target_link_libraries(${_name} PRIVATE qefivar_dummy Qt6::Test)
    target_compile_options(${_name} PRIVATE -UQT_NO_KEYWORDS -UQT_NO_CAST_FROM_ASCII)
    add_test(NAME ${_name} COMMAND ${_name})
endforeach()

# Tests for the KCM itself.
add_executable(test_efibootmanager
    test_efibootmanager.cc
    ${CMAKE_SOURCE_DIR}/efibootmanager.cpp
    ${CMAKE_SOURCE_DIR}/efibootentrymodel.cpp
)
target_include_directories(test_efibootmanager PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${QEFIVAR_DIR}/tests
)
target_link_libraries(test_efibootmanager PRIVATE
    qefivar_dummy
    Qt6::Test
    KF6::AuthCore
    KF6::I18n
)
add_test(NAME test_efibootmanager COMMAND test_efibootmanager)
