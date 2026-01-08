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
    };
    Q_ENUM(Roles)

    struct Entry {
        quint16 id = 0;
        QString name;
        QString path;
        bool isDefault = false;
        bool isVisible = true;
        QByteArray raw;
        QByteArray optionalData;
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

