# SPDX-FileCopyrightText: 2026
# SPDX-License-Identifier: GPL-2.0-or-later

add_executable(efiboothelper
    efiboothelper.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefi.h
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefi.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidpacpi.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidphw.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidpmedia.cpp
    ${CMAKE_SOURCE_DIR}/third_party/qefivar/qefidpmessage.cpp
)
set_target_properties(efiboothelper PROPERTIES OUTPUT_NAME "org.kde.kcm.efiboot.helper")

target_link_libraries(efiboothelper PRIVATE
    Qt6::Core
    Qt6::DBus
    KF6::AuthCore
)

target_include_directories(efiboothelper PRIVATE
    ${CMAKE_SOURCE_DIR}/third_party/qefivar
)

install(TARGETS efiboothelper DESTINATION libexec/kf6/kauth)

# KAuth action definitions + polkit policy
if (NOT DEFINED KDE_INSTALL_KAUTH_ACTIONS_DIR)
    set(KDE_INSTALL_KAUTH_ACTIONS_DIR "${KDE_INSTALL_DATADIR}/kauth/actions")
endif()

install(FILES ${CMAKE_SOURCE_DIR}/org.kde.kcm.efiboot.actions DESTINATION ${KDE_INSTALL_KAUTH_ACTIONS_DIR})
install(FILES ${CMAKE_SOURCE_DIR}/org.kde.kcm.efiboot.policy DESTINATION ${KDE_INSTALL_DATADIR}/polkit-1/actions/)
install(FILES ${CMAKE_SOURCE_DIR}/helper/org.kde.kcm.efiboot.helper.conf DESTINATION /etc/dbus-1/system.d/)

# Configure and install D-Bus service file
configure_file(org.kde.kcm.efiboot.helper.service.in org.kde.kcm.efiboot.helper.service @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/org.kde.kcm.efiboot.helper.service DESTINATION ${KDE_INSTALL_DATADIR}/dbus-1/system-services/)

