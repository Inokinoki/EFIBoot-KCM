/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <QPair>
#include <QString>
#include <QUuid>

/**
 * Returns the global EFI variable GUID
 *
 * This GUID is used for accessing global EFI variables like
 * BootOrder, BootNext, BootCurrent, etc.
 *
 * GUID: 8be4df61-93ca-11d2-aa0d-00e098032b8c
 *
 * @return QUuid The EFI global variable GUID
 */
inline QUuid efiGlobalGuid()
{
    return QUuid(QStringLiteral("8be4df61-93ca-11d2-aa0d-00e098032b8c"));
}

/**
 * Detect OS type and return appropriate icon and accent color
 *
 * This function analyzes the EFI path and name to determine the operating
 * system type and returns the corresponding icon name and accent color.
 *
 * Detection priority:
 * 1. Recovery environments and diagnostic tools
 * 2. Windows (with edition detection)
 * 3. Linux distributions (distribution-specific)
 * 4. BSD variants
 * 5. macOS
 * 6. Android
 * 7. EFI Shell
 * 8. Generic fallback
 *
 * @param pathLower Lowercase EFI path string
 * @param nameLower Lowercase entry name string
 * @return QPair<QString, QString> Icon name and accent color (hex)
 */
QPair<QString, QString> detectOsInfo(const QString &pathLower, const QString &nameLower);

/**
 * Get device icon based on device path type
 *
 * Parses the EFI load option to determine the type of device
 * (hard disk, optical, USB, network, etc.) and returns an
 * appropriate icon name.
 *
 * @param rawData Raw EFI load option data
 * @return QString Icon name for the device type
 */
QString iconForDevicePath(const QByteArray &rawData);

/**
 * Validate and provide fallback icon if needed
 *
 * Ensures that an icon name is valid and provides a fallback
 * if the icon name is empty. For distro-specific icons,
 * the name is trusted as-is since the QML side will handle
 * visual fallback if the icon doesn't exist.
 *
 * @param iconName Icon name to validate
 * @return QString Valid icon name (or fallback)
 */
QString validateIconName(const QString &iconName);
