/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <QAbstractListModel>
#include <QByteArray>

class EfiBootEntryModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        EntryIdRole = Qt::UserRole + 1,
        EntryIdHexRole,
        NameRole,
        PathRole,
        IsDefaultRole,
        IsVisibleRole,
        IsBootNextRole,
        IsCurrentRole,
        IconNameRole,
        OsTypeRole,
        AccentColorRole,
        DeviceIconRole,
    };
    Q_ENUM(Roles)

    enum OsType {
        Unknown,
        Windows,
        Linux,
        LinuxFedora,
        LinuxUbuntu,
        LinuxArch,
        LinuxDebian,
        LinuxOpenSUSE,
        LinuxMint,
        LinuxManjaro,
        LinuxGentoo,
        LinuxPopOS,
        LinuxKali,
        LinuxCentOS,
        LinuxRedHat,
        Bsd,
        MacOS,
        Android,
        EfiShell,
        Recovery,
        Diagnostic,
        Other,
    };
    Q_ENUM(OsType)

    struct Entry {
        quint16 id = 0;
        QString name;
        QString path;
        bool isDefault = false;
        bool isVisible = true; // true if in BootOrder, false if disabled
        bool isBootNext = false; // true if set for one-time boot
        bool isCurrent = false; // true if this is the current booted entry
        QByteArray raw;
        QByteArray optionalData;
        OsType osType = Unknown;
        QString accentColor;
        QString iconName;
        QString deviceIcon;
    };

    explicit EfiBootEntryModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setEntries(std::vector<Entry> entries);
    const Entry *entryForId(quint16 id) const;

private:
    std::vector<Entry> m_entries;
};

