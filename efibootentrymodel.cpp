/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "efibootentrymodel.h"

#include <QLatin1StringView>
#include <qefi.h>

// Helper function to get icon name based on first device path type
static QString iconForDevicePath(const QByteArray &rawData)
{
    // Parse the load option to get device path list
    QEFILoadOption loadOption(rawData);
    if (!loadOption.isValidated()) {
        return QStringLiteral("computer");
    }

    const QList<QSharedPointer<QEFIDevicePath>> devicePaths = loadOption.devicePathList();
    if (devicePaths.isEmpty()) {
        return QStringLiteral("computer");
    }

    const QEFIDevicePath *firstDP = devicePaths.first().data();
    const QEFIDevicePathType dpType = firstDP->type();
    const quint8 dpSubType = firstDP->subType();

    // Map device path types to icon names
    switch (dpType) {
    case DP_Media:
        switch (dpSubType) {
        case QEFIDevicePathMediaSubType::MEDIA_HD:
            return QStringLiteral("drive-harddisk");
        case QEFIDevicePathMediaSubType::MEDIA_CDROM:
            return QStringLiteral("drive-optical");
        case QEFIDevicePathMediaSubType::MEDIA_File:
            return QStringLiteral("drive-partition");
        default:
            return QStringLiteral("drive-harddisk");
        }
    case DP_Message:
        switch (dpSubType) {
        case QEFIDevicePathMessageSubType::MSG_SATA:
        case QEFIDevicePathMessageSubType::MSG_NVME:
        case QEFIDevicePathMessageSubType::MSG_SCSI:
        case QEFIDevicePathMessageSubType::MSG_ISCSI:
        case QEFIDevicePathMessageSubType::MSG_SASEX:
        case QEFIDevicePathMessageSubType::MSG_UFS:
        case QEFIDevicePathMessageSubType::MSG_SD:
        case QEFIDevicePathMessageSubType::MSG_EMMC:
            return QStringLiteral("drive-harddisk");
        case QEFIDevicePathMessageSubType::MSG_ATAPI:
            return QStringLiteral("drive-optical");
        case QEFIDevicePathMessageSubType::MSG_USB:
        case QEFIDevicePathMessageSubType::MSG_USBClass:
            return QStringLiteral("drive-removable-media");
        case QEFIDevicePathMessageSubType::MSG_MACAddr:
        case QEFIDevicePathMessageSubType::MSG_IPv4:
        case QEFIDevicePathMessageSubType::MSG_IPv6:
        case QEFIDevicePathMessageSubType::MSG_WiFi:
        case QEFIDevicePathMessageSubType::MSG_BT:
        case QEFIDevicePathMessageSubType::MSG_BTLE:
            return QStringLiteral("network-wired");
        default:
            return QStringLiteral("drive-harddisk");
        }
    case DP_Hardware:
        switch (dpSubType) {
        case QEFIDevicePathHardwareSubType::HW_PCI:
            return QStringLiteral("cpu");
        default:
            return QStringLiteral("computer");
        }
    case DP_ACPI:
        return QStringLiteral("computer");
    case DP_BIOSBoot:
        return QStringLiteral("computer");
    default:
        return QStringLiteral("computer");
    }
}

EfiBootEntryModel::EfiBootEntryModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int EfiBootEntryModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return static_cast<int>(m_entries.size());
}

QVariant EfiBootEntryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= rowCount()) {
        return {};
    }

    const auto &entry = m_entries.at(static_cast<size_t>(index.row()));
    switch (role) {
    case EntryIdRole:
        return entry.id;
    case EntryIdHexRole:
        return QStringLiteral("%1").arg(entry.id, 4, 16, QLatin1Char('0')).toUpper();
    case NameRole:
        return entry.name;
    case PathRole:
        return entry.path;
    case IsDefaultRole:
        return entry.isDefault;
    case IsVisibleRole:
        return entry.isVisible;
    case IsBootNextRole:
        return entry.isBootNext;
    case IconNameRole: {
        // First prioritize OS type detection based on path and name
        const QString pathLower = entry.path.toLower();
        const QString nameLower = entry.name.toLower();

        if (pathLower.contains(QStringLiteral("microsoft")) || nameLower.contains(QStringLiteral("windows"))) {
            return QStringLiteral("os-windows");
        }
        if (pathLower.contains(QStringLiteral("linux")) || nameLower.contains(QStringLiteral("linux")) ||
            pathLower.contains(QStringLiteral("grub")) || nameLower.contains(QStringLiteral("grub")) ||
            pathLower.contains(QStringLiteral("fedora")) || nameLower.contains(QStringLiteral("fedora")) ||
            pathLower.contains(QStringLiteral("ubuntu")) || nameLower.contains(QStringLiteral("ubuntu")) ||
            pathLower.contains(QStringLiteral("arch")) || nameLower.contains(QStringLiteral("arch"))) {
            return QStringLiteral("os-linux");
        }
        if (pathLower.contains(QStringLiteral("freebsd")) || nameLower.contains(QStringLiteral("freebsd")) ||
            pathLower.contains(QStringLiteral("bsd")) || nameLower.contains(QStringLiteral("bsd"))) {
            return QStringLiteral("os-freebsd");
        }

        // Fallback: Detect icon from device path type
        QString deviceIcon = iconForDevicePath(entry.raw);
        if (!deviceIcon.isEmpty()) {
            return deviceIcon;
        }

        return QStringLiteral("computer");
    }
    default:
        return {};
    }
}

QHash<int, QByteArray> EfiBootEntryModel::roleNames() const
{
    return {
        {EntryIdRole, "entryId"},
        {EntryIdHexRole, "entryIdHex"},
        {NameRole, "name"},
        {PathRole, "path"},
        {IsDefaultRole, "isDefault"},
        {IsVisibleRole, "isVisible"},
        {IsBootNextRole, "isBootNext"},
        {IconNameRole, "iconName"},
    };
}

void EfiBootEntryModel::setEntries(std::vector<Entry> entries)
{
    beginResetModel();
    m_entries = std::move(entries);
    endResetModel();
}

const EfiBootEntryModel::Entry *EfiBootEntryModel::entryForId(quint16 id) const
{
    for (const auto &entry : m_entries) {
        if (entry.id == id) {
            return &entry;
        }
    }
    return nullptr;
}

