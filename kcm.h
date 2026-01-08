/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <KQuickConfigModule>

class EfiBootManager;

class EfiBootKCM : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(EfiBootManager *manager READ manager CONSTANT)

public:
    explicit EfiBootKCM(QObject *parent, const KPluginMetaData &data, const QVariantList &args);

    EfiBootManager *manager() const;

public Q_SLOTS:
    void load() override;

private:
    EfiBootManager *const m_manager;
};

