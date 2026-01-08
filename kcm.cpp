/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "kcm.h"

#include "efibootentrymodel.h"
#include "efibootmanager.h"

#include <KPluginFactory>

#include <QQmlEngine>

K_PLUGIN_CLASS_WITH_JSON(EfiBootKCM, "kcm_efiboot.json")

EfiBootKCM::EfiBootKCM(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : KQuickConfigModule(parent, data)
    , m_manager(new EfiBootManager(this))
{
    Q_UNUSED(args)

    constexpr const char *uri = "org.kde.plasma.kcm.efiboot";
    qmlRegisterUncreatableType<EfiBootEntryModel>(uri, 1, 0, "EfiBootEntryModel", QStringLiteral("Provided by the KCM"));
    qmlRegisterUncreatableType<EfiBootManager>(uri, 1, 0, "EfiBootManager", QStringLiteral("Provided by the KCM"));

    connect(this, &KQuickConfigModule::mainUiReady, this, &EfiBootKCM::load, Qt::SingleShotConnection);
}

EfiBootManager *EfiBootKCM::manager() const
{
    return m_manager;
}

void EfiBootKCM::load()
{
    m_manager->refresh();
}

#include "kcm.moc"

