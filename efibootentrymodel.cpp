/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "efibootentrymodel.h"

#include <QLatin1StringView>
#include <qefi.h>

// Helper function to get OS type and color
QPair<QString, QString> detectOsInfo(const QString &pathLower, const QString &nameLower)
{
    // Recovery environment detection - Highest priority
    if (pathLower.contains(QLatin1StringView("recovery")) || pathLower.contains(QLatin1StringView("winre")) || pathLower.contains(QLatin1StringView("recenv"))
        || pathLower.contains(QLatin1StringView("backup")) || pathLower.contains(QLatin1StringView("restore"))
        || nameLower.contains(QLatin1StringView("recovery")) || nameLower.contains(QLatin1StringView("windows recovery"))
        || nameLower.contains(QLatin1StringView("system recovery")) || nameLower.contains(QLatin1StringView("winre"))
        || pathLower.contains(QLatin1StringView("repair")) || nameLower.contains(QLatin1StringView("repair"))) {
        return {QStringLiteral("tools-repair"), QStringLiteral("#FF5722")};
    }

    // Diagnostic tools detection
    if (pathLower.contains(QLatin1StringView("memtest")) || pathLower.contains(QLatin1StringView("memtest86"))
        || pathLower.contains(QLatin1StringView("diagnostic")) || pathLower.contains(QLatin1StringView("firmware"))
        || pathLower.contains(QLatin1StringView("bios")) || nameLower.contains(QLatin1StringView("memtest"))
        || nameLower.contains(QLatin1StringView("diagnostic")) || nameLower.contains(QLatin1StringView("firmware"))
        || nameLower.contains(QLatin1StringView("bios setup")) || nameLower.contains(QLatin1StringView("setup"))
        || pathLower.contains(QLatin1StringView("test")) || nameLower.contains(QLatin1StringView("test"))) {
        return {QStringLiteral("hwinfo"), QStringLiteral("#607D8B")};
    }

    // Windows detection - Check for specific editions first
    if (pathLower.contains(QLatin1StringView("microsoft")) || pathLower.contains(QLatin1StringView("windows")) || pathLower.contains(QLatin1StringView("win"))
        || pathLower.contains(QLatin1StringView("\\efi\\microsoft\\")) || nameLower.contains(QLatin1StringView("windows"))
        || nameLower.contains(QLatin1StringView("microsoft")) || nameLower.contains(QLatin1StringView("winboot"))
        || nameLower.contains(QLatin1StringView("boot manager")) || nameLower.contains(QLatin1StringView("boot mgr"))) {
        // Detect Windows editions
        if (nameLower.contains(QLatin1StringView("windows 11")) || pathLower.contains(QLatin1StringView("windows11"))
            || nameLower.contains(QLatin1StringView("win11"))) {
            return {QStringLiteral("image-x-ico"), QStringLiteral("#0078D4")};
        }
        if (nameLower.contains(QLatin1StringView("windows 10")) || pathLower.contains(QLatin1StringView("windows10"))
            || nameLower.contains(QLatin1StringView("win10"))) {
            return {QStringLiteral("image-x-ico"), QStringLiteral("#0078D4")};
        }
        if (nameLower.contains(QLatin1StringView("windows 8")) || nameLower.contains(QLatin1StringView("win8"))) {
            return {QStringLiteral("image-x-ico"), QStringLiteral("#00A4EF")};
        }
        if (nameLower.contains(QLatin1StringView("windows 7")) || nameLower.contains(QLatin1StringView("win7"))) {
            return {QStringLiteral("image-x-ico"), QStringLiteral("#00A4EF")};
        }
        if (nameLower.contains(QLatin1StringView("server")) || pathLower.contains(QLatin1StringView("server"))
            || nameLower.contains(QLatin1StringView("server"))) {
            return {QStringLiteral("image-x-ico"), QStringLiteral("#00BCF2")};
        }

        return {QStringLiteral("image-x-ico"), QStringLiteral("#00A4EF")};
    }

    // Linux distribution detection - Priority order (most specific first)
    // Fedora/Red Hat family
    if (pathLower.contains(QLatin1StringView("fedora")) || nameLower.contains(QLatin1StringView("fedora"))) {
        return {QStringLiteral("fedora"), QStringLiteral("#294172")};
    }
    if (pathLower.contains(QLatin1StringView("redhat")) || nameLower.contains(QLatin1StringView("redhat")) || pathLower.contains(QLatin1StringView("rhel"))
        || nameLower.contains(QLatin1StringView("rhel")) || nameLower.contains(QLatin1StringView("red hat"))) {
        return {QStringLiteral("redhat"), QStringLiteral("#EE0000")};
    }
    if (pathLower.contains(QLatin1StringView("centos")) || nameLower.contains(QLatin1StringView("centos"))) {
        return {QStringLiteral("centos"), QStringLiteral("#9CCA1E")};
    }
    if (pathLower.contains(QLatin1StringView("rocky")) || nameLower.contains(QLatin1StringView("rocky"))) {
        return {QStringLiteral("centos"), QStringLiteral("#10B981")};
    }
    if (pathLower.contains(QLatin1StringView("almalinux")) || nameLower.contains(QLatin1StringView("alma"))) {
        return {QStringLiteral("centos"), QStringLiteral("#9CCA1E")};
    }

    // Ubuntu family
    if (pathLower.contains(QLatin1StringView("ubuntu")) || nameLower.contains(QLatin1StringView("ubuntu"))) {
        // Check for Ubuntu flavors
        if (nameLower.contains(QLatin1StringView("kubuntu"))) {
            return {QStringLiteral("kubuntu"), QStringLiteral("#0079C1")};
        }
        if (nameLower.contains(QLatin1StringView("xubuntu"))) {
            return {QStringLiteral("xubuntu"), QStringLiteral("#E95420")};
        }
        if (nameLower.contains(QLatin1StringView("lubuntu"))) {
            return {QStringLiteral("lubuntu"), QStringLiteral("#0D1219")};
        }
        if (nameLower.contains(QLatin1StringView("ubuntu mate")) || nameLower.contains(QLatin1StringView("ubuntumate"))) {
            return {QStringLiteral("ubuntu-mate"), QStringLiteral("#6B9327")};
        }
        if (nameLower.contains(QLatin1StringView("ubuntu studio")) || nameLower.contains(QLatin1StringView("ubuntustudio"))) {
            return {QStringLiteral("ubuntu-studio"), QStringLiteral("#953276")};
        }
        if (nameLower.contains(QLatin1StringView("ubuntu budgie")) || nameLower.contains(QLatin1StringView("ubuntubudgie"))) {
            return {QStringLiteral("ubuntu"), QStringLiteral("#3B1F1A")};
        }
        if (nameLower.contains(QLatin1StringView("ubuntu kylin")) || nameLower.contains(QLatin1StringView("ubuntukylin"))) {
            return {QStringLiteral("ubuntu"), QStringLiteral("#E95420")};
        }
        return {QStringLiteral("ubuntu"), QStringLiteral("#E95420")};
    }

    // Debian family
    if (pathLower.contains(QLatin1StringView("debian")) || nameLower.contains(QLatin1StringView("debian"))) {
        return {QStringLiteral("debian"), QStringLiteral("#D70A53")};
    }

    // Arch family
    if (pathLower.contains(QLatin1StringView("arch")) || nameLower.contains(QLatin1StringView("arch"))) {
        if (nameLower.contains(QLatin1StringView("manjaro")) || pathLower.contains(QLatin1StringView("manjaro"))) {
            return {QStringLiteral("manjaro"), QStringLiteral("#35BF5C")};
        }
        if (nameLower.contains(QLatin1StringView("endeavouros"))) {
            return {QStringLiteral("endeavouros"), QStringLiteral("#7B7B7B")};
        }
        if (nameLower.contains(QLatin1StringView("garuda"))) {
            return {QStringLiteral("arch-linux"), QStringLiteral("#1FD68D")};
        }
        if (nameLower.contains(QLatin1StringView("arco"))) {
            return {QStringLiteral("arch-linux"), QStringLiteral("#4CBF98")};
        }
        return {QStringLiteral("arch-linux"), QStringLiteral("#1793D1")};
    }

    // openSUSE family
    if (pathLower.contains(QLatin1StringView("opensuse")) || nameLower.contains(QLatin1StringView("opensuse")) || pathLower.contains(QLatin1StringView("suse"))
        || nameLower.contains(QLatin1StringView("suse"))) {
        return {QStringLiteral("opensuse"), QStringLiteral("#73BA25")};
    }
    if (pathLower.contains(QLatin1StringView("tumbleweed")) || nameLower.contains(QLatin1StringView("tumbleweed"))) {
        return {QStringLiteral("opensuse"), QStringLiteral("#73BA25")};
    }
    if (pathLower.contains(QLatin1StringView("leap")) || nameLower.contains(QLatin1StringView("leap"))) {
        return {QStringLiteral("opensuse"), QStringLiteral("#73BA25")};
    }

    // Linux Mint
    if (pathLower.contains(QLatin1StringView("mint")) || nameLower.contains(QLatin1StringView("linuxmint"))
        || nameLower.contains(QLatin1StringView("linux mint"))) {
        return {QStringLiteral("linuxmint"), QStringLiteral("#87CF3E")};
    }
    if (nameLower.contains(QLatin1StringView("lmde"))) {
        return {QStringLiteral("linuxmint"), QStringLiteral("#87CF3E")};
    }

    // Gentoo family
    if (pathLower.contains(QLatin1StringView("gentoo")) || nameLower.contains(QLatin1StringView("gentoo"))) {
        return {QStringLiteral("gentoo"), QStringLiteral("#54487A")};
    }
    if (pathLower.contains(QLatin1StringView("funtoo")) || nameLower.contains(QLatin1StringView("funtoo"))) {
        return {QStringLiteral("gentoo"), QStringLiteral("#54487A")};
    }

    // Pop!_OS
    if (pathLower.contains(QLatin1StringView("pop")) || nameLower.contains(QLatin1StringView("pop!_os")) || nameLower.contains(QLatin1StringView("popos"))
        || nameLower.contains(QLatin1StringView("system76"))) {
        return {QStringLiteral("pop-os"), QStringLiteral("#48B9C7")};
    }

    // Kali Linux
    if (pathLower.contains(QLatin1StringView("kali")) || nameLower.contains(QLatin1StringView("kali"))) {
        return {QStringLiteral("kali"), QStringLiteral("#557C94")};
    }

    // Solus
    if (pathLower.contains(QLatin1StringView("solus")) || nameLower.contains(QLatin1StringView("solus"))) {
        return {QStringLiteral("solus"), QStringLiteral("#5294E2")};
    }

    // Elementary OS
    if (pathLower.contains(QLatin1StringView("elementary")) || nameLower.contains(QLatin1StringView("elementary"))
        || nameLower.contains(QLatin1StringView("eos"))) {
        return {QStringLiteral("elementary"), QStringLiteral("#64B5F6")};
    }

    // Zorin OS
    if (pathLower.contains(QLatin1StringView("zorin")) || nameLower.contains(QLatin1StringView("zorin"))) {
        return {QStringLiteral("zorin"), QStringLiteral("#0CC1F3")};
    }

    // Slackware
    if (pathLower.contains(QLatin1StringView("slackware")) || nameLower.contains(QLatin1StringView("slackware"))) {
        return {QStringLiteral("slackware"), QStringLiteral("#5A8F3E")};
    }

    // NixOS
    if (pathLower.contains(QLatin1StringView("nixos")) || nameLower.contains(QLatin1StringView("nixos"))) {
        return {QStringLiteral("nixos"), QStringLiteral("#5277C3")};
    }

    // Alpine Linux
    if (pathLower.contains(QLatin1StringView("alpine")) || nameLower.contains(QLatin1StringView("alpine"))) {
        return {QStringLiteral("alpine"), QStringLiteral("#0D597F")};
    }

    // Void Linux
    if (pathLower.contains(QLatin1StringView("void")) || nameLower.contains(QLatin1StringView("void"))) {
        return {QStringLiteral("void"), QStringLiteral("#AAC058")};
    }

    // MX Linux
    if (nameLower.contains(QLatin1StringView("mx linux")) || nameLower.contains(QLatin1StringView("mx"))) {
        return {QStringLiteral("mx"), QStringLiteral("#B52828")};
    }

    // deepin
    if (pathLower.contains(QLatin1StringView("deepin")) || nameLower.contains(QLatin1StringView("deepin"))) {
        return {QStringLiteral("deepin"), QStringLiteral("#1C6CDC")};
    }

    // Generic Linux detection
    if (pathLower.contains(QLatin1StringView("linux")) || nameLower.contains(QLatin1StringView("linux")) || pathLower.contains(QLatin1StringView("grub"))
        || nameLower.contains(QLatin1StringView("grub")) || pathLower.contains(QLatin1StringView("kernel")) || nameLower.contains(QLatin1StringView("vmlinuz"))
        || pathLower.contains(QLatin1StringView("initrd")) || pathLower.contains(QLatin1StringView("\\EFI\\"))) {
        return {QStringLiteral("preferences-system-linux"), QStringLiteral("#4CAF50")};
    }

    // BSD detection - Check specific BSDs first
    if (pathLower.contains(QLatin1StringView("freebsd")) || nameLower.contains(QLatin1StringView("freebsd"))) {
        return {QStringLiteral("freebsd"), QStringLiteral("#AB2B28")};
    }
    if (pathLower.contains(QLatin1StringView("openbsd")) || nameLower.contains(QLatin1StringView("openbsd"))) {
        return {QStringLiteral("openbsd"), QStringLiteral("#F8E827")};
    }
    if (pathLower.contains(QLatin1StringView("netbsd")) || nameLower.contains(QLatin1StringView("netbsd"))) {
        return {QStringLiteral("netbsd"), QStringLiteral("#FF6600")};
    }
    if (pathLower.contains(QLatin1StringView("bsd"))) {
        return {QStringLiteral("application-x-desktop"), QStringLiteral("#9C27B0")};
    }

    // macOS detection
    if (pathLower.contains(QLatin1StringView("mac")) || nameLower.contains(QLatin1StringView("mac")) || pathLower.contains(QLatin1StringView("osx"))
        || nameLower.contains(QLatin1StringView("osx")) || pathLower.contains(QLatin1StringView("apple")) || nameLower.contains(QLatin1StringView("apple"))) {
        return {QStringLiteral("computer-apple"), QStringLiteral("#666666")};
    }

    // Android detection
    if (pathLower.contains(QLatin1StringView("android")) || nameLower.contains(QLatin1StringView("android"))) {
        return {QStringLiteral("android"), QStringLiteral("#3DDC84")};
    }

    // EFI Shell/Utilities
    if (pathLower.contains(QLatin1StringView("shell")) || nameLower.contains(QLatin1StringView("shell")) || pathLower.contains(QLatin1StringView("efi/shell"))
        || pathLower.contains(QLatin1StringView("efi/boot")) || pathLower.contains(QLatin1StringView("efishe"))) {
        return {QStringLiteral("utilities-terminal"), QStringLiteral("#FF9800")};
    }

    // Fallback - Default computer with neutral color
    return {QStringLiteral("computer"), QStringLiteral("#2196F3")};
}

// Helper function to validate and provide fallback icon if needed
QString validateIconName(const QString &iconName)
{
    // List of known valid icon names that should always work
    static const QStringList validFallbackIcons = {QStringLiteral("computer"),
                                                   QStringLiteral("drive-harddisk"),
                                                   QStringLiteral("preferences-system-linux"),
                                                   QStringLiteral("image-x-ico"),
                                                   QStringLiteral("utilities-terminal"),
                                                   QStringLiteral("tools-repair"),
                                                   QStringLiteral("hwinfo"),
                                                   QStringLiteral("application-x-desktop")};

    // If the icon name is empty, return the default
    if (iconName.isEmpty()) {
        return QStringLiteral("computer");
    }

    // For known distro-specific icons, we trust them (they may or may not exist
    // on the system, but it's better to try them than to fall back immediately)
    // The QML side will handle the fallback visually if the icon fails to load

    return iconName;
}

// Helper function to get icon name based on first device path type
QString iconForDevicePath(const QByteArray &rawData)
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
        return QStringLiteral("preferences-system-startup");
    case DP_BIOSBoot:
        return QStringLiteral("preferences-system-startup");
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
    case IsCurrentRole:
        return entry.isCurrent;
    case IconNameRole:
        return entry.iconName.isEmpty() ? QStringLiteral("computer") : entry.iconName;
    case OsTypeRole:
        return static_cast<int>(entry.osType);
    case AccentColorRole:
        return entry.accentColor;
    case DeviceIconRole:
        return entry.deviceIcon.isEmpty() ? QStringLiteral("drive-harddisk") : entry.deviceIcon;
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
        {IsCurrentRole, "isCurrent"},
        {IconNameRole, "iconName"},
        {OsTypeRole, "osType"},
        {AccentColorRole, "accentColor"},
        {DeviceIconRole, "deviceIcon"},
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

