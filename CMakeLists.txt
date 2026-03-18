# SPDX-FileCopyrightText: 2026
# SPDX-License-Identifier: GPL-2.0-or-later

cmake_minimum_required(VERSION 3.16)

project(efibootkcm VERSION 0.0.1 LANGUAGES CXX)

set(QT_MIN_VERSION "6.9.0")
set(KF6_MIN_VERSION "6.18.0")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DTRANSLATION_DOMAIN="kcm_efiboot")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(KDEClangFormat)
include(KDEGitCommitHooks)
include(FeatureSummary)
include(ECMDeprecationSettings)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    DBus
    Gui
    Quick
    Svg
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    CoreAddons
    I18n
    KCMUtils
    Auth
)

ecm_set_disabled_deprecation_versions(QT 6.9.0
    KF 6.18.0
)


kcmutils_add_qml_kcm(kcm_efiboot SOURCES
    kcm.cpp
    kcm.h
)

target_sources(kcm_efiboot PRIVATE
    efibootentrymodel.cpp
    efibootentrymodel.h
    efibootmanager.cpp
    efibootmanager.h
    efivarcommon.h
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefi.h
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefi.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidpacpi.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidphw.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidpmedia.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidpmessage.cpp
)

target_link_libraries(kcm_efiboot PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    KF6::CoreAddons
    KF6::I18n
    KF6::KCMUtilsQuick
    KF6::AuthCore
)

target_include_directories(kcm_efiboot PRIVATE
    ${CMAKE_SOURCE_DIR}/third_party/qefivar
)

add_subdirectory(helper)

file(GLOB_RECURSE ALL_CLANG_FORMAT_SOURCE_FILES *.cpp *.h)
kde_clang_format(${ALL_CLANG_FORMAT_SOURCE_FILES})
kde_configure_git_pre_commit_hook(CHECKS CLANG_FORMAT)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)

