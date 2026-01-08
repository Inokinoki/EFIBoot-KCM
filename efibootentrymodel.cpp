/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "efibootentrymodel.h"

#include <QLatin1StringView>

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

